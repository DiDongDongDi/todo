# 发布体系实施记录（脱敏）

> 操作手册见 [RELEASE.md](RELEASE.md) · 签名原理见 [ANDROID-SIGNING.md](ANDROID-SIGNING.md) · FCM 简介见 [FCM.md](FCM.md)

本文记录 **2026-07 前后** 为仓库搭建 GitHub 发布流水线时的实施过程与当前状态。文中**不含**任何密钥、密码、Token 或项目专属 URL，仅保留可复用的步骤与文件清单。

---

## 目标

| 产物 | 方案 | 触发方式 |
|------|------|----------|
| Android APK | GitHub Releases | 推送 `v*` 标签 |
| Web 静态站 | Cloudflare Pages（项目名 `todo-app`） | 推送到 `master` |

构建均在 GitHub Actions 中完成；Supabase 配置通过 Secrets 在 CI 里生成 `supabase_config.dart`，不提交 git。

---

## 新增与修改的文件

### CI / 脚本

| 路径 | 用途 |
|------|------|
| [`.github/workflows/release-apk.yml`](../.github/workflows/release-apk.yml) | 标签触发 → release 签名 APK → 上传 Release |
| [`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml) | `master` 推送 → 构建 Web → 部署 Cloudflare Pages |
| [`scripts/write_supabase_config.sh`](../scripts/write_supabase_config.sh) | 从环境变量生成 Supabase 配置（Linux CI） |
| [`scripts/write_supabase_config.ps1`](../scripts/write_supabase_config.ps1) | 同上（Windows 本地） |
| [`scripts/generate_android_keystore.sh`](../scripts/generate_android_keystore.sh) | 一次性生成 release keystore |
| [`scripts/generate_android_keystore.ps1`](../scripts/generate_android_keystore.ps1) | 同上（Windows） |

### Android / Web 配置

| 路径 | 变更 |
|------|------|
| [`app/android/app/build.gradle.kts`](../app/android/app/build.gradle.kts) | 通过环境变量读取 release keystore；未配置时回退 debug |
| [`app/android/settings.gradle.kts`](../app/android/settings.gradle.kts) | AGP 8.9.1；`CI=true` 时跳过阿里云 Maven 镜像 |
| [`app/android/build.gradle.kts`](../app/android/build.gradle.kts) | 同上，子项目仓库源 |
| [`app/android/gradle/wrapper/gradle-wrapper.properties`](../app/android/gradle/wrapper/gradle-wrapper.properties) | Gradle 8.11.1 |
| [`app/web/_redirects`](../app/web/_redirects) | Cloudflare SPA 回退：`/* → /index.html 200` |
| [`.gitignore`](../.gitignore) | 排除 `*.keystore`、`todo-release.keystore`、`.keystore-password.txt` |

### 文档

| 路径 | 内容 |
|------|------|
| [RELEASE.md](RELEASE.md) | 发版操作手册 |
| [ANDROID-SIGNING.md](ANDROID-SIGNING.md) | APK 签名是什么、为何需要、如何保管 |
| [FCM.md](FCM.md) | Firebase 云推送简介（未来可选） |
| [README.md](../README.md) | 增加下载 / 在线体验链接与文档索引 |

### 代码兼容修复

| 路径 | 原因 |
|------|------|
| [`app/lib/shared/theme/app_theme.dart`](../app/lib/shared/theme/app_theme.dart) | CI 使用 Flutter 3.44，`CardTheme` 需改为 `CardThemeData` |

---

## 已完成的配置（脱敏）

### GitHub Secrets（仓库 Settings → Actions）

以下 Secret **名称** 已写入仓库（值为占位说明，真实值仅存 GitHub / 本机，勿写入文档或 git）：

| Secret | 来源 / 说明 |
|--------|-------------|
| `SUPABASE_URL` | 自本机 `supabase_config.dart` 读取后写入 |
| `SUPABASE_ANON_KEY` | 同上（anon public，非 service_role） |
| `ANDROID_KEYSTORE_BASE64` | 本地 keystore 文件 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 生成时设定 |
| `ANDROID_KEY_ALIAS` | `todo-release` |
| `ANDROID_KEY_PASSWORD` | 与 keystore 密码相同 |
| `CLOUDFLARE_API_TOKEN` | Cloudflare 控制台创建（Pages Edit 权限） |
| `CLOUDFLARE_ACCOUNT_ID` | Dashboard 右侧 Account ID |

### Cloudflare Pages（Web）

- 项目名：`todo-app`（与 workflow 一致）
- 创建方式：控制台 **Workers & Pages → Create application → Pages → Direct Upload**；或 `wrangler pages project create todo-app`
- **不必**在 Cloudflare 连接 GitHub；构建与上传由 GitHub Actions 完成
- 线上 URL：Cloudflare 自动分配，格式为 `https://todo-app-<后缀>.pages.dev`，在控制台 **Visit site** 查看
- 首次部署：写入 `CLOUDFLARE_*` Secrets 后，手动运行 Deploy workflow 或推 `master`
- 状态：**Web 部署 workflow 已成功**（2026-07-08）

**Supabase 待配置：** 将 Authentication → URL Configuration 中的 Site URL / Redirect URLs 设为 Cloudflare 控制台显示的实际 `*.pages.dev` 地址。

### Release 密钥库（本机）

- 生成位置：`app/android/app/todo-release.keystore`（已在 `.gitignore`）
- 别名：`todo-release`
- 密码备份：`app/android/app/.keystore-password.txt`（已在 `.gitignore`，**勿提交**）
- 建议：将 keystore 文件 + 密码另行存入密码管理器或离线备份

### 首次发版

- 版本：`app/pubspec.yaml` 中为 `0.1.0+1`
- 标签：`v0.1.0` 已推送并触发 Actions
- 结果：**Release 构建成功**，APK 已上传至 [GitHub Releases（latest）](https://github.com/DiDongDongDi/todo/releases/latest)
- 本地验证：`flutter build apk --release` 亦已通过（约 58.7MB）

---

## Cloudflare Pages 创建步骤（脱敏）

详细操作见 [RELEASE.md 第三节](RELEASE.md#三配置-cloudflare-pages)。摘要如下：

### 控制台路径（2025–2026 新版 UI）

```
登录 dash.cloudflare.com
  → 确认在 Account Home（非域名 DNS 页）
  → 左侧 Workers & Pages
  → Create application
  → Pages 标签
  → Direct Upload（非 Connect to Git）
  → 项目名 todo-app
  → 上传占位 index.html
```

### 与 GitHub Actions 的分工

| 环节 | 负责方 |
|------|--------|
| `flutter build web` | GitHub Actions |
| 上传 `app/build/web` | `cloudflare/pages-action` |
| 创建 Pages 项目 | Cloudflare 控制台或 Wrangler（一次性） |
| Supabase 线上 URL | 人工在 Supabase Dashboard 配置 |

### Token 与 Secrets

1. Cloudflare：**My Profile → API Tokens** → 创建，权限含 **Pages Edit**
2. 复制 **Account ID**（Dashboard 右侧）
3. GitHub：`gh secret set CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN`
4. **勿**将 Token 写入文档、git 或聊天；泄露后 Revoke 并轮换

### 部署与验证

```bash
# 手动触发
gh workflow run "Deploy Web to Cloudflare Pages" --ref master

# 或推送 master 自动触发
git push origin master
```

成功后于 **Workers & Pages → todo-app → Visit site** 打开站点；将该 URL 填入 Supabase。

**Production vs Preview：** 若部署显示 Preview，检查 Cloudflare 项目 Production branch 是否为 `master`（与仓库默认分支一致）。详见 [RELEASE.md](RELEASE.md#production-与-preview)。

---

首次推送 `v0.1.0` 时连续失败，按日志逐项修复：

| 次序 | 现象 | 处理 |
|------|------|------|
| 1 | 阿里云 Maven 镜像返回 502 | `CI=true` 时仅用 `google()` / `mavenCentral()` |
| 2 | androidx 依赖要求 AGP ≥ 8.9.1 | `settings.gradle.kts` 中 AGP 8.7.0 → 8.9.1 |
| 3 | AGP 8.9.1 要求 Gradle ≥ 8.11.1 | `gradle-wrapper.properties` 8.10.2 → 8.11.1 |
| 4 | CI 使用官方 Gradle 分发 | workflow 中 `sed` 替换腾讯云镜像 URL |
| 5 | `CardTheme` 与 Flutter 3.44 不兼容 | 改为 `CardThemeData` |

修复相关 commit（节选）：

```
fix: use official Maven repos in CI for Android builds
fix: bump Android Gradle Plugin to 8.9.1 for CI release builds
fix: bump Gradle wrapper to 8.11.1 for AGP 8.9.1
fix: use CardThemeData for Flutter 3.44 theme API
```

---

## 分工：已自动化 vs 仍需人工

### 已由脚本 / CI 完成

- [x] 发布相关代码、workflow、文档入库
- [x] Supabase + Android 签名 Secrets 写入 GitHub
- [x] 生成 release keystore 并写入 Android Secrets
- [x] 打标签 `v0.1.0`，APK 发布成功
- [x] 本地 release APK 构建验证
- [x] Cloudflare Pages 项目 `todo-app` 与 `CLOUDFLARE_*` Secrets
- [x] Web 部署 workflow 首次成功

### 仍需在网页控制台完成

- [ ] **Supabase**：Authentication → URL Configuration 添加 Cloudflare 实际 `*.pages.dev` 地址（及 `http://localhost:*`）

---

## 日常发版速查

### 发新 APK

1. 更新 `app/pubspec.yaml` 的 `version`
2. `git tag v0.2.0 && git push origin v0.2.0`
3. 在 Actions / Releases 页确认 `app-release.apk`

### 更新 Web

1. 确认 Cloudflare Secrets 已配置
2. `git push origin master` 或手动运行 Deploy workflow
3. 在 Cloudflare 控制台 **Visit site** 打开实际 URL 验证

---

## 安装与使用提示

| 场景 | 说明 |
|------|------|
| 从 Release 安装 APK | 推荐方式；MIUI 等设备可避免 USB 安装限制 |
| 曾装过 debug 包 | 需先卸载再装 release 包（签名不同） |
| keystore 丢失 | 无法向已安装用户无缝升级；需重新生成并换包名或让用户卸载重装 |
| Web 登录失败 | 检查 Supabase Site URL 是否含线上域名 |

---

## 相关链接

- [发版操作手册](RELEASE.md)
- [Android 签名说明](ANDROID-SIGNING.md)
- [FCM 推送简介](FCM.md)
- [真机安装笔记](ANDROID-PHONE-INSTALL-NOTES.md)
- [GitHub Releases](https://github.com/DiDongDongDi/todo/releases)
