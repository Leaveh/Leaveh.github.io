# Leaveh 每日新闻

一个纯 HTML + CSS 的静态新闻站点，参考 MINEBBS 论坛新闻资讯风格设计。

## 文件结构
- `index.html` — 站点主页面
- `style.css` — 样式文件
- `.nojekyll` — 关闭 GitHub Pages 的 Jekyll 处理（纯静态站适用）
- `.gitignore` — 忽略本地私有文件

## 本地预览
直接用浏览器打开 `index.html` 即可，无需任何构建步骤。

## 部署到 GitHub Pages（两种方式）

### 方式 A：直接分支托管（最简单，推荐纯静态站）
1. 在 GitHub 新建仓库（如 `leaveh-news`）
2. 把本目录所有文件 push 到 `main` 分支
3. 仓库 **Settings → Pages → Source** 选择 `Deploy from a branch`
4. Branch 选 `main`，目录选 `/ (root)`
5. 保存后等待约 1 分钟，访问 `https://<用户名>.github.io/<仓库名>/`

### 方式 B：GitHub Actions 自动部署
适合后续需要自动化发布的场景，在仓库 `.github/workflows/` 放一个 static.yml 即可。

## 自定义内容
直接编辑 `index.html` 中的新闻卡片：
- `.card-title` — 新闻标题
- `.card-summary` — 新闻摘要
- `.tag-*` — 标签颜色（danger/warning/success/info/primary/purple）
- `.card-meta` — 作者、时间、回复数、查看数
- `.card-avatar` — 左侧图标（emoji）
