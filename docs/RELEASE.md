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

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. **Workers & Pages → Create → Pages → Connect to Git**（可选，我们主要用 Actions 部署）
3. 先创建一个空项目，名称 **`todo-app`**（与 workflow 中 `projectName` 一致）
4. 创建 API Token：**My Profile → API Tokens → Create Token**
   - 模板选 **Edit Cloudflare Workers** 或自定义，勾选 **Account → Cloudflare Pages → Edit**
5. 记下 **Account ID**，写入 GitHub Secret

首次 `master` 推送或手动运行 **Deploy Web to Cloudflare Pages** workflow 后，站点 URL 形如：

```
https://todo-app.pages.dev
```

可在 Cloudflare 绑定自定义域名。

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
| **Site URL** | `https://todo-app.pages.dev`（或你的自定义域名） |
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
- [ ] Cloudflare 项目 `todo-app` 已创建，`CLOUDFLARE_*` Secrets 已配置
- [ ] Supabase Site URL / Redirect URLs 含线上域名
- [ ] `pubspec.yaml` 版本号已更新
- [ ] 推送 `v*` 标签后 Release 有 APK
- [ ] `master` 推送后 Web 可访问且登录正常

---

## 八、常见问题

| 问题 | 处理 |
|------|------|
| Release 构建失败：keystore | 检查 Base64 是否完整、密码与 alias 是否正确 |
| 新 APK 装不上，提示签名冲突 | 卸载手机上旧 debug 包后再装 release 包 |
| Web 登录失败 | 检查 Supabase URL 配置是否含 `todo-app.pages.dev` |
| Cloudflare 部署 403 | API Token 权限不足或 `accountId` 错误 |
| MIUI `INSTALL_FAILED_USER_RESTRICTED` | USB 安装限制；从 Release 下载 APK 手动安装通常可绕过 |

---

## 相关文档

- [Android 签名说明](ANDROID-SIGNING.md)
- [FCM 推送简介](FCM.md)（未来可选能力）
- [真机安装笔记](ANDROID-PHONE-INSTALL-NOTES.md)
