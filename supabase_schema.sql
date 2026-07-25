-- ============================================================
--  Leaveh 每日新闻 - Supabase 数据库 Schema
--  在 Supabase Dashboard → SQL Editor 中执行此脚本
-- ============================================================

-- 1. profiles 表（扩展 auth.users）
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar TEXT NOT NULL DEFAULT '',
    title TEXT DEFAULT '',
    level INTEGER NOT NULL DEFAULT 1,
    exp INTEGER NOT NULL DEFAULT 0,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    banned BOOLEAN NOT NULL DEFAULT FALSE,
    muted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. posts 表
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    author_username TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('公告','服务器','活动','技术','其他')),
    tag TEXT CHECK (tag IN ('hot','urgent','new','top','')),
    summary TEXT NOT NULL,
    content TEXT DEFAULT '',
    views INTEGER NOT NULL DEFAULT 0,
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. comments 表（含回复：parent_id 指向父评论）
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id),
    author_username TEXT NOT NULL,
    content TEXT NOT NULL,
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. likes 表（统一点赞：帖子/评论/回复）
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('post','comment')),
    target_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, target_type, target_id)
);

-- 5. daily_exp 表（每日经验记录，防重复领取）
CREATE TABLE IF NOT EXISTS daily_exp (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exp_date DATE NOT NULL,
    exp_type TEXT NOT NULL CHECK (exp_type IN ('comment','post')),
    amount INTEGER NOT NULL,
    granted BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, exp_date, exp_type)
);

-- 6. redeem_codes 表（兑换码）
CREATE TABLE IF NOT EXISTS redeem_codes (
    code TEXT PRIMARY KEY,
    reward_type TEXT NOT NULL DEFAULT 'level',
    reward_value INTEGER NOT NULL DEFAULT 99,
    max_uses INTEGER NOT NULL DEFAULT 1,
    use_count INTEGER NOT NULL DEFAULT 0,
    used_by UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 索引优化
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_target ON likes(user_id, target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_daily_exp_user_date ON daily_exp(user_id, exp_date);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- ============================================================
-- 自动更新 updated_at 触发器
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_t ON profiles;
CREATE TRIGGER update_profiles_updated_t BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_posts_updated_t ON posts;
CREATE TRIGGER update_posts_updated_t BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 注册时自动创建 profile 的触发器
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, avatar, created_at)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email,'@',1)), UPPER(LEFT(COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email,'@',1)), 1)));
    -- 如果用户名是 chenjunlongsb1，自动设为管理员
    IF NEW.raw_user_meta_data->>'username' = 'chenjunlongsb1' THEN
        UPDATE profiles SET is_admin = TRUE, title = '民间Wiki', level = 99, exp = 9800 WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 预置兑换码（直升99级，仅可用一次）
-- ============================================================
INSERT INTO redeem_codes (code, reward_type, reward_value, max_uses)
VALUES ('LEAVEH-99VIP-7H3X9M', 'level', 99, 1)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- RLS 行级安全策略
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_exp ENABLE ROW LEVEL SECURITY;
ALTER TABLE redeem_codes ENABLE ROW LEVEL SECURITY;

-- profiles: 所有人可读，自己可改，管理员可改所有人
DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));

-- posts: 所有人可读，登录用户可发帖，作者或管理员可删/改
DROP POLICY IF EXISTS "posts_select" ON posts;
CREATE POLICY "posts_select" ON posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "posts_insert" ON posts;
CREATE POLICY "posts_insert" ON posts FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND NOT EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND banned=TRUE));
DROP POLICY IF EXISTS "posts_update" ON posts;
CREATE POLICY "posts_update" ON posts FOR UPDATE USING (author_id=auth.uid() OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));
DROP POLICY IF EXISTS "posts_delete" ON posts;
CREATE POLICY "posts_delete" ON posts FOR DELETE USING (author_id=auth.uid() OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));

-- comments: 所有人可读，未封禁登录用户可评论
DROP POLICY IF EXISTS "comments_select" ON comments;
CREATE POLICY "comments_select" ON comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "comments_insert" ON comments;
CREATE POLICY "comments_insert" ON comments FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND NOT EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND (banned=TRUE OR muted=TRUE))
);
DROP POLICY IF EXISTS "comments_update" ON comments;
CREATE POLICY "comments_update" ON comments FOR UPDATE USING (author_id=auth.uid() OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));
DROP POLICY IF EXISTS "comments_delete" ON comments;
CREATE POLICY "comments_delete" ON comments FOR DELETE USING (author_id=auth.uid() OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));

-- likes: 登录用户可点赞/取消
DROP POLICY IF EXISTS "likes_select" ON likes;
CREATE POLICY "likes_select" ON likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "likes_insert" ON likes;
CREATE POLICY "likes_insert" ON likes FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id=auth.uid());
DROP POLICY IF EXISTS "likes_delete" ON likes;
CREATE POLICY "likes_delete" ON likes FOR DELETE USING (user_id=auth.uid());

-- daily_exp: 用户可读自己的，系统插入
DROP POLICY IF EXISTS "daily_exp_select" ON daily_exp;
CREATE POLICY "daily_exp_select" ON daily_exp FOR SELECT USING (auth.uid() = user_id OR EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));
DROP POLICY IF EXISTS "daily_exp_insert" ON daily_exp;
CREATE POLICY "daily_exp_insert" ON daily_exp FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- redeem_codes: 所有人可读（用于验证），管理员管理
DROP POLICY IF EXISTS "redeem_codes_select" ON redeem_codes;
CREATE POLICY "redeem_codes_select" ON redeem_codes FOR SELECT USING (true);
DROP POLICY IF EXISTS "redeem_codes_update" ON redeem_codes;
CREATE POLICY "redeem_codes_update" ON redeem_codes FOR UPDATE USING (EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=TRUE));

-- ============================================================
-- 帖子删除级联清理点赞的函数
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM likes WHERE target_type='post' AND target_id=OLD.id;
    DELETE FROM comments WHERE post_id=OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cleanup_on_post_delete ON posts;
CREATE TRIGGER cleanup_on_post_delete AFTER DELETE ON posts FOR EACH ROW EXECUTE FUNCTION cleanup_post_likes();

-- 评论删除级联清理点赞
CREATE OR REPLACE FUNCTION cleanup_comment_likes()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM likes WHERE target_type='comment' AND target_id=OLD.id;
    -- 删除子评论的点赞
    DELETE FROM likes WHERE target_type='comment' AND target_id IN (SELECT id FROM comments WHERE parent_id=OLD.id);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cleanup_on_comment_delete ON comments;
CREATE TRIGGER cleanup_on_comment_delete AFTER DELETE ON comments FOR EACH ROW EXECUTE FUNCTION cleanup_comment_likes();

-- 评论数自增函数（发评论时调用）
CREATE OR REPLACE FUNCTION increment_comments_count(post_id_input UUID)
RETURNS void AS $$
BEGIN
    UPDATE posts SET comments_count = comments_count + 1, updated_at = now() WHERE id = post_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 完成！
-- ============================================================
-- 验证
SELECT '✅ Schema 创建完成！' AS status,
       (SELECT count(*) FROM profiles) AS profiles_count,
       (SELECT count(*) FROM posts) AS posts_count,
       (SELECT count(*) FROM redeem_codes) AS codes_count;
