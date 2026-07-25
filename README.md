# Leaveh 每日新闻

一个带后端的新闻社区站点（Supabase + GitHub Pages），参考 MINEBBS 论坛风格设计。

## 功能特性
- ✅ **注册/登录系统** — Supabase Auth 邮箱密码认证，跨设备持久登录
- ✅ **用户发帖** — 标题 / 分类(5类) / 标签(4种) / 摘要 / 正文
- ✅ **评论 + 回复** — 嵌套一层回复，支持点赞
- ✅ **点赞系统** — 帖子、评论、回复均可点赞（防重复）
- ✅ **用户资料** — 头像 / 称号 / 等级 / 经验进度条 / 发帖数 / 评论数
- ✅ **等级经验系统** — 满级 100，每级 100 经验；每日首评+10、首发帖+20
- ✅ **兑换码** — 预置直升 99 级兑换码 `LEAVEH-99VIP-7H3X9M`（一次性）
- ✅ **超级管理员** — `chenjunlongsb1` 自动获管理员权限（称号「民间Wiki」），可删任意帖、封禁/解封、禁言/解除禁言
- ✅ **实时同步** — Supabase Realtime 支持（数据全局共享，不再依赖 localStorage）
- ✅ **响应式适配** — 手机 / 平板 / 桌面端

## 文件结构
```
├── index.html            # 主页面（含 Supabase SDK）
├── style.css             # 样式文件
├── supabase_schema.sql   # 数据库建表脚本（在 Supabase SQL Editor 执行）
├── .nojekyll             # 关闭 Jekyll 处理
└── .gitignore            # Git 忽略规则
```

## 部署指南（3 步上线）

### 第 1 步：创建 Supabase 项目（免费）
1. 打开 [supabase.com](https://supabase.com) → 注册/登录
2. 点击 **New Project** → 选免费套餐 → 创建
3. 进入项目后，左侧菜单点 **Settings → API**
4. 复制以下两个值：
   - **Project URL**（格式：`https://xxxx.supabase.co`）
   - **anon public key**（格式：`eyJ...` 很长的一串）

### 第 2 步：建数据库表
1. 在 Supabase 左侧菜单点 **SQL Editor**
2. 点 **New Query**，把 `supabase_schema.sql` 的内容全部粘贴进去
3. 点 **Run** 执行（看到 ✅ Schema 创建完成！即成功）

### 第 3 步：配置前端连接
编辑 `index.html`，找到顶部的这两行：
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```
替换为你的真实值：
```javascript
const SUPABASE_URL = 'https://xxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxx';
```

### 第 4 步：部署到 GitHub Pages
```bash
git add -A && git commit -m "feat: 接入 Supabase 后端" && git push origin master
```
等待 1~2 分钟，访问 **https://Leaveh.github.io/** 即可。

## 数据库表结构
| 表名 | 用途 | 关键字段 |
|------|------|----------|
| profiles | 用户资料 | username, level, exp, is_admin, banned, muted, title |
| posts | 帖子 | title, category, tag, summary, content, likes_count, comments_count |
| comments | 评论/回复 | post_id, parent_id(回复), content, likes_count |
| likes | 点赞记录 | user_id, target_type(post/comment), target_id |
| daily_exp | 每日经验 | user_id, exp_date, exp_type(comment/post), amount |
| redeem_codes | 兑换码 | code, reward_value, max_uses, use_count, used_by |

## 管理员账号
- 用户名注册为 `chenjunlongsb1` 时自动获得管理员权限
- 称号：「民间Wiki」
- 权限：删除任意帖子、封禁/解封账号、禁言/解除禁言

## 本地预览
⚠️ 配好 Supabase 后才能正常使用。未配置时会显示引导页面。
