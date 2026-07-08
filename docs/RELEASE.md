# 发版与线上部署

> APK 签名原理：[ANDROID-SIGNING.md](ANDROID-SIGNING.md) · Web 局限：[WEB-LIMITATIONS.md](WEB-LIMITATIONS.md)

本文说明如何把 **Android APK** 发布到 GitHub Releases，以及如何把 **Web** 部署到 Cloudflare Pages。

---

## 概览

| 产物 | 触发方式 | 托管位置 |
|------|----------|----------|
| `app-release.apk` | 推送 `v*` 标签（如 `v0.1.0`） | GitHub Releases |
| Web 静态站 | 推送到 `master` 分支 | Cloudflare Pages（项目名 `todo-app`） |

两套流水线均在 GitHub Actions 中构建，并从 Secrets 注入 Supabase 配置。

---

## 一、首次准备：GitHub Secrets

打开仓库 **Settings → Secrets and variables → Actions → New repository secret**，添加：

### Supabase（APK + Web 共用）

| Secret | 说明 |
|--------|------|
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_ANON_KEY` | anon public key（**不是** service_role） |

### Android Release 签名

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | keystore 文件的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名，默认 `todo-release` |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

### Cloudflare Pages

| Secret | 说明 |
|--------|------|
| `CLOUDFLARE_API_TOKEN` | 具备 **Cloudflare Pages: Edit** 权限的 API Token |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare 账户 ID（Dashboard 右侧栏可见） |

---

## 二、生成 Release 密钥库（仅一次）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/generate_android_keystore.ps1
```

生成文件：`app/android/app/todo-release.keystore`（已在 `.gitignore` 中，**勿提交 git**）。

### 转为 Base64 存入 GitHub

PowerShell：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app\android\app\todo-release.keystore")) | Set-Clipboard
```

将剪贴板内容粘贴为 Secret `ANDROID_KEYSTORE_BASE64`。

签名用途详见 [ANDROID-SIGNING.md](ANDROID-SIGNING.md)。

---

## 三、配置 Cloudflare Pages

本项目 Web **不由 Cloudflare 连 Git 构建**，而是由 GitHub Actions 执行 `flutter build web` 后上传静态文件。Cloudflare 侧只需：**创建 Pages 项目**、**拿到 Account ID / API Token**、**写入 GitHub Secrets**。

### 3.1 在控制台创建 Pages 项目

Cloudflare 近年将 Pages 并入 **Workers & Pages**，入口与旧文档不同。

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. **左上角**确认处于 **Account Home（账户首页）**，而非某个域名的 DNS 页
3. 左侧边栏打开 **Workers & Pages**
   - 若找不到，可尝试直接访问：`https://dash.cloudflare.com/?to=/:account/workers-and-pages`
4. 点击 **Create application（创建应用）**
5. 切换到 **Pages** 标签页
6. 选择 **Direct Upload（直接上传）**（**不要**选 Connect to Git，构建在 GitHub Actions 完成）
7. 项目名填 **`todo-app`**（必须与 [`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml) 中 `projectName` 一致）
8. 上传任意占位文件（如一个 `index.html`）完成首次创建

> 若提示「项目名已存在」，说明之前已创建过，可跳过此步。

**找不到 Create application？** 常见原因：停在域名 DNS 页、子账户权限不足、或界面语言不同。可改用下方命令行创建。

### 3.2 命令行创建（可选）

已安装 Node.js 时：

```powershell
npm install -g wrangler
wrangler login
wrangler pages project create todo-app
```

### 3.3 获取 Account ID 与 API Token

| 项 | 获取位置 |
|----|----------|
| **Account ID** | Dashboard 右侧 **Account ID** 栏；或 **Workers & Pages** 页面 URL 中 |
| **API Token** | [My Profile → API Tokens → Create Token](https://dash.cloudflare.com/profile/api-tokens) |

创建 Token 时：

- 权限勾选 **Account → Cloudflare Pages → Edit**
- 或使用 **Edit Cloudflare Workers** 模板（含 Pages 权限）

**安全：** Token 只写入 GitHub Secrets 或密码管理器，**不要**提交 git、不要贴在聊天或文档里。若曾泄露，立即在 Cloudflare 控制台 **Revoke** 并重新生成。

### 3.4 写入 GitHub Secrets

仓库 **Settings → Secrets and variables → Actions**，或使用 CLI（将占位符换成真实值）：

```powershell
gh secret set CLOUDFLARE_ACCOUNT_ID
gh secret set CLOUDFLARE_API_TOKEN
```

### 3.5 首次部署 Web

Secrets 就绪后任选其一：

```bash
git push origin master
```

或在 GitHub **Actions → Deploy Web to Cloudflare Pages → Run workflow** 手动触发。

### 3.6 查看线上 URL

Cloudflare 分配的 `*.pages.dev` 域名**不一定**是 `todo-app.pages.dev`，常见格式为：

```
https://todo-app-<随机后缀>.pages.dev
```

在 **Workers & Pages → 选择 todo-app → Visit site** 或项目 **Domains** 页查看实际地址。将该 URL 用于 Supabase 配置（见下一节）和 README 链接。

可在 Cloudflare 绑定自定义域名。

### Production 与 Preview

Cloudflare 根据**分支名**判断环境：

| 部署分支 | Cloudflare 项目 Production branch | 结果 |
|----------|-----------------------------------|------|
| 与 Production branch **相同** | 如 `master` | **Production**（主域名 `todo-app-xxxxx.pages.dev`） |
| 与 Production branch **不同** | 默认常为 `main` | **Preview**（仅 `master.todo-app-xxxxx.pages.dev` 等别名） |

本仓库默认分支为 **`master`**。若控制台 Production branch 仍为 `main`（Direct Upload 创建时的默认值），GitHub Actions 部署会落到 Preview。

**处理：**

1. 控制台：**Workers & Pages → todo-app → Settings → Builds & deployments → Production branch** 改为 `master`
2. 或依赖 workflow 中的自动 PATCH（见 [deploy-web.yml](../.github/workflows/deploy-web.yml)）
3. workflow 已显式设置 `branch: master`

重新部署后，在 **Deployments** 列表中应看到 **Production** 环境；主域名即为 README 中的线上地址。

### SPA 路由

[`app/web/_redirects`](../app/web/_redirects) 已配置：

```
/*    /index.html   200
```

深链（如 `/task/xxx`）刷新时不会 404。

---

## 四、配置 Supabase 线上 URL

在 **Supabase Dashboard → Authentication → URL Configuration**：

| 项 | 建议值 |
|----|--------|
| **Site URL** | Cloudflare 控制台中 **todo-app** 项目的实际 `*.pages.dev` 地址（见 [RELEASE.md 第三节](RELEASE.md#36-查看线上-url)） |
| **Redirect URLs** | 同上；开发用另加 `http://localhost:*` |

本项目登录使用**邮箱 OTP 验证码**（见 [README Supabase 章节](../README.md)），不依赖魔法链接回调，配置相对简单。

邮件模板仍需按 README 改为仅含 `{{ .Token }}`。

---

## 五、发布 Android APK

### 1. 确认版本号

编辑 [`app/pubspec.yaml`](../app/pubspec.yaml) 中的 `version`，例如 `0.1.0+1`（`+1` 为 Android `versionCode`）。

### 2. 打标签并推送

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 3. 等待 Actions

Workflow：[`.github/workflows/release-apk.yml`](../.github/workflows/release-apk.yml)

完成后在 **Releases** 页面下载 `app-release.apk`。

### 本地手动构建（可选）

```powershell
$env:SUPABASE_URL = "https://xxxx.supabase.co"
$env:SUPABASE_ANON_KEY = "eyJ..."
.\scripts\write_supabase_config.ps1

$env:ANDROID_KEYSTORE_PATH = "$PWD\app\android\app\todo-release.keystore"
$env:ANDROID_KEYSTORE_PASSWORD = "你的密码"
$env:ANDROID_KEY_ALIAS = "todo-release"
$env:ANDROID_KEY_PASSWORD = "你的密码"

cd app
flutter build apk --release
```

---

## 六、发布 Web

推送到 `master` 即自动部署：

```bash
git push origin master
```

或：**Actions → Deploy Web to Cloudflare Pages → Run workflow**

Workflow：[`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml)

---

## 七、发版检查清单

- [ ] `SUPABASE_*` Secrets 已配置
- [ ] Release keystore 已生成并备份
- [ ] `ANDROID_*` Secrets 已配置
- [ ] Cloudflare 项目 `todo-app` 已创建（Direct Upload 或 Wrangler），`CLOUDFLARE_*` Secrets 已配置
- [ ] Supabase Site URL / Redirect URLs 含 Cloudflare 实际 `*.pages.dev` 域名
- [ ] `pubspec.yaml` 版本号已更新
- [ ] 推送 `v*` 标签后 Release 有 APK
- [ ] `master` 推送后 Web 可访问且登录正常

---

## 八、常见问题

| 问题 | 处理 |
|------|------|
| Release 构建失败：keystore | 检查 Base64 是否完整、密码与 alias 是否正确 |
| 新 APK 装不上，提示签名冲突 | 卸载手机上旧 debug 包后再装 release 包 |
| Web 登录失败 | 检查 Supabase Site URL 是否与 Cloudflare 控制台显示的 `*.pages.dev` 一致 |
| Cloudflare 部署只在 Preview | Production branch 默认为 `main`，仓库为 `master`；改控制台或用 workflow 同步 |
| MIUI `INSTALL_FAILED_USER_RESTRICTED` | USB 安装限制；从 Release 下载 APK 手动安装通常可绕过 |

---

## 相关文档

- [发布体系实施记录（脱敏）](RELEASE-SETUP-NOTES.md)
- [Android 签名说明](ANDROID-SIGNING.md)
- [FCM 推送简介](FCM.md)（未来可选能力）
- [真机安装笔记](ANDROID-PHONE-INSTALL-NOTES.md)
