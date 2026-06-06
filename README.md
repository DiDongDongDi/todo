# 上瘾式跨平台 Todo

打开即写、划一下即收进收集箱 — 手势优先的跨平台待办应用。

## 平台

Android · iOS · macOS · Windows · Web

## 功能概览

- **收集** — 空白大卡片快速录入（文字 / 语音 / 图片 / 录音），上划保存
- **处理** — 大卡片逐条分拣：左滑放弃、右滑归档、上下切换
- **同步** — 离线优先，Supabase 多设备同步

## 文档

- [产品文档](docs/PRODUCT.md)
- [交互与手势](docs/UX-GESTURES.md)
- [架构设计](docs/ARCHITECTURE.md)
- [路线图](docs/ROADMAP.md)
- [Web 调试分工清单](docs/WEB-SETUP-CHECKLIST.md) — Chrome 日常开发，几乎即开即用
- [Web 局限说明](docs/WEB-LIMITATIONS.md)
- [Android 真机分工清单](docs/ANDROID-SETUP-CHECKLIST.md) — 手势 / 动效打磨
- [Android 真机分工清单](docs/ANDROID-SETUP-CHECKLIST.md) — Agent / 用户各自事项，逐项攻克
- [Android Studio 版本命名说明](docs/ANDROID-STUDIO-VERSION-NAMES.md) — Panda / Panda 4 等代号含义

## 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.16
- Dart >= 3.2

安装 Flutter 后确认环境正常：

```bash
flutter doctor
```

---

## 本地运行

### 1. 克隆仓库

```bash
git clone git@github.com:DiDongDongDi/todo.git
cd todo
```

### 2. 生成多平台目录（首次必须）

本仓库的 `app/` 包含 Flutter 源码，但 Android / iOS / Windows 等平台目录需在本机生成一次：

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts/init_platforms.ps1
```

```bash
# macOS / Linux（在 app 目录下执行）
cd app
flutter create . --org com.todo.app --project-name todo_app
```

### 3. 安装依赖并运行

```bash
cd app
flutter pub get
flutter run
```

### 4. 指定设备运行（速查）

详细步骤见下方 **[开发与调试](#开发与调试推荐)**。

```bash
cd app
flutter devices

# 日常开发（推荐）
flutter run -d chrome

# 手势 / 动效（Android 真机）
flutter run -d android
```

### 5. 运行单元测试

```bash
cd app
flutter test
```

### 不配置 Supabase 也能用

未配置 Supabase 时，应用以**纯本地模式**运行：收集、处理、归档、回收站等功能均可离线使用，数据保存在本机（SharedPreferences）。

---

## 开发与调试（推荐）

本应用以**手势与动效**为核心，日常开发和真机体验分工如下：

| 场景 | 推荐平台 | 说明 |
|------|----------|------|
| 日常开发（约 80%） | **Chrome（Web）** | 启动快、热重载方便；清单见 [WEB-SETUP-CHECKLIST.md](docs/WEB-SETUP-CHECKLIST.md) |
| 手势 / 动效打磨 | **Android 真机** | 清单见 [ANDROID-SETUP-CHECKLIST.md](docs/ANDROID-SETUP-CHECKLIST.md) |

```
日常改代码 → Chrome 热重载
手感 / 动画 / 语音 → Android 真机联调
```

---

### Web 调试（Chrome，日常首选）

> 完整分工与差距说明：[WEB-SETUP-CHECKLIST.md](docs/WEB-SETUP-CHECKLIST.md) · 局限：[WEB-LIMITATIONS.md](docs/WEB-LIMITATIONS.md)

**适合：** 布局与主题、收集 / 处理 Tab 逻辑、本地存储、Riverpod 状态、路由。

**局限：** 滑动手势与手机不完全一致；语音、触觉反馈在 Web 上较弱或不可用。

#### 前置条件

- 已安装 Flutter，`flutter doctor` 中 **Chrome** 为 ✓（一般安装 Chrome 浏览器即可）
- 运行 `scripts/check_web_env.ps1` 可一键检查

#### 运行

```powershell
cd app
flutter pub get
flutter devices          # 应能看到 Chrome
flutter run -d chrome
```

#### 常用操作

| 操作 | 说明 |
|------|------|
| 热重载 | 终端按 `r` |
| 热重启 | 终端按 `R` |
| 退出 | 终端按 `q` |
| 查看日志 | 运行终端直接输出；也可 `flutter logs` |

#### 调试技巧

- 使用 Chrome **开发者工具**（F12）查看布局与控制台
- 改 `lib/` 下代码后按 `r`，多数 UI 变更可秒级生效
- 测试键盘快捷键：处理 Tab 支持 `←` `→` `↑` `↓`（见 [UX-GESTURES.md](docs/UX-GESTURES.md)）

---

### Android 真机调试（手势 / 动效）

**适合：** 上划保存、左右滑归档 / 回收站、卡片切换动画、触觉反馈（haptic）、语音输入、贴图等**真实触控体验**。

> **Agent 侧已完成：** 权限、Gradle 国内镜像、应用名「Todo」、环境检查脚本。详见 [分工清单](docs/ANDROID-SETUP-CHECKLIST.md)（A1–A5 已勾选）。**仍需你完成 U1–U7** 才能真机运行。

#### 前置条件（用户清单 U1–U3）

1. 安装 [Android Studio](https://developer.android.com/studio)
2. 打开 Android Studio → **SDK Manager**，安装：
   - Android SDK Platform（建议 API 34+）
   - **Android SDK Command-line Tools**
   - Android SDK Build-Tools
3. 接受许可：

```powershell
flutter doctor --android-licenses
```

4. 确认工具链：

```powershell
flutter doctor
```

`Android toolchain` 应为 ✓。若提示缺少 `cmdline-tools`，在 SDK Manager 中勾选 **Android SDK Command-line Tools (latest)** 后重试。

完成 U1–U3 后运行环境检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_android_env.ps1
```

#### 手机端设置

1. **设置 → 关于手机**，连续点击「版本号」7 次，开启开发者模式
2. **设置 → 开发者选项**，开启 **USB 调试**
3. 用数据线连接电脑；手机上弹出「允许 USB 调试」时点 **允许**

#### 运行

```powershell
cd app
flutter devices
# 应出现你的手机型号，例如：sdk gphone64 arm64 / Pixel xxx

flutter run -d <设备ID>
# 仅一台 Android 设备时可简写：
flutter run -d android
```

#### 常用操作

| 操作 | 说明 |
|------|------|
| 热重载 | 终端按 `r` |
| 热重启 | 终端按 `R` |
| 查看设备日志 | `flutter logs` 或 Android Studio Logcat |
| 无线调试（可选） | Android 11+：开发者选项中「无线调试」，配对后 `flutter devices` 可见 |

#### 调试技巧

- **收集 Tab**：验证空白拦截、有内容上划保存、保存后 Toast
- **处理 Tab**：验证左滑回收站、右滑归档、上下切卡、撤销 Snackbar
- 动效不满意时，在 `lib/shared/widgets/`（如 `swipeable_card.dart`）改完 → 真机按 `r` 立即查看
- 若需「开发者模式」以支持部分插件符号链接（Windows），可运行 `start ms-settings:developers` 并开启

#### 常见问题（Android）

| 问题 | 处理 |
|------|------|
| `flutter devices` 看不到手机 | 换数据线（需支持数据传输）、重装 USB 驱动、确认已允许 USB 调试 |
| 首次构建很慢 | 正常，Gradle 会下载依赖，请保持网络畅通 |
| 中国网络 Gradle 慢 | 可配置 Android 镜像或使用稳定代理 |
| 安装失败 `INSTALL_FAILED` | 卸载手机上旧版同包名 App 后重试 |

---

### 其他平台（可选）

```bash
flutter devices

# Android 模拟器（需 Android Studio 创建 AVD）
flutter run -d emulator-5554

# Windows 桌面（需 Visual Studio「使用 C++ 的桌面开发」）
flutter run -d windows

# iOS（仅 macOS + Xcode）
flutter run -d ios
```

日常不必优先配置 Windows / iOS，除非你要专门适配该平台。

---

## Supabase 配置（多设备同步）

配置完成后，可在手机收集任务、在桌面处理页看到同一条数据。

### 1. 创建 Supabase 项目

1. 打开 [Supabase](https://supabase.com) 并登录
2. 点击 **New project**，选择区域并设置数据库密码
3. 等待项目创建完成

### 2. 执行数据库迁移

在 Supabase Dashboard 中打开 **SQL Editor**，将 [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql) 的全部内容粘贴并执行。

> 若报错 `policy "tasks_select_own" already exists`，说明迁移已执行过，可忽略；或重新粘贴最新版 SQL（已支持重复执行）再跑一遍。

迁移会创建：

- `tasks` 表 — 任务数据
- `operations` 表 — 增量同步日志
- 行级安全策略（RLS）— 用户只能访问自己的数据

### 3. 开启邮箱登录（魔法链接）

1. 进入 **Authentication → Providers**
2. 确认 **Email** 已启用
3. 在 **Authentication → URL Configuration** 中，将 **Site URL** 设为你的应用地址（本地开发可先用 `http://localhost`，**无需加端口**）
   - Site URL 是用户点击邮件魔法链接后，浏览器验证完成时的默认跳转地址
   - 本项目为原生 App 登录：点邮件链接后手动回到 App 即可，不要求 Site URL 精确对应 App 地址
   - 仅在做 **Flutter Web** 本地开发时才需带端口（如 `http://localhost:8080`），并同步在 **Redirect URLs** 中添加

### 4. 填入 API 密钥

1. 进入 **Project Settings → API**
2. 复制 **Project URL** 和 **anon public** key，在 https://supabase.com/dashboard/project/gurtakyggjaphkagzmgf/integrations/data_api/docs 查看 URL
3. 编辑 [`app/lib/core/config/supabase_config.example.dart`](app/lib/core/config/supabase_config.example.dart)，替换占位值：

```dart
class SupabaseConfig {
  static const String url = 'https://xxxx.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

> **注意：** 不要将含真实密钥的文件提交到公开仓库。若需独立本地配置，可复制为 `app/lib/core/config/supabase_config.dart`（已在 `.gitignore` 中），并修改 `auth_service.dart` 的 import 指向该文件。

### 5. 在 App 内登录并同步

1. 运行应用：`flutter run`
2. 进入 **处理** Tab，点击右上角 **同步** 图标
3. 输入邮箱，点击 **发送魔法链接登录**
4. 查收邮件中的登录链接并点击确认
5. 返回 App，点击 **立即同步**

同步行为：

- 本地变更后自动尝试上传（已登录时）
- 每 30 秒后台拉取一次远端数据
- 冲突默认按 `updated_at` **后写入者优先**（LWW）

### 6. 附件存储（可选，Phase 2+）

若需同步图片 / 录音附件：

1. 在 Supabase Dashboard → **Storage** 中新建 bucket：`attachments`
2. 设为私有（Private）
3. 为 bucket 配置 RLS，限制用户只能读写自己的文件路径 `{user_id}/*`

---

## 项目结构

```
todo/
├── docs/              # 产品与技术文档
├── app/               # Flutter 应用
│   ├── lib/
│   │   ├── core/      # 数据库、同步、认证
│   │   ├── features/  # 收集、处理、归档、回收站
│   │   └── shared/    # 组件、主题、工具
│   └── test/
├── scripts/           # 初始化脚本
└── supabase/          # 数据库迁移与 RLS
    └── migrations/
```

## 技术栈

Flutter · Riverpod · go_router · Supabase · SharedPreferences（本地存储）

## 常见问题

| 问题 | 处理 |
|------|------|
| `flutter` 命令找不到 | 安装 Flutter SDK 并将其 `bin` 目录加入 PATH；已加仍找不到时见 [WINDOWS-DEV-ENV-NOTES.md](docs/WINDOWS-DEV-ENV-NOTES.md)（需重启 Cursor，非仅新开终端） |
| `flutter run` 报缺少平台目录 | 执行 `scripts/init_platforms.ps1` 或 `flutter create .` |
| App 显示「Supabase 未配置」 | 检查 `supabase_config.example.dart` 是否已填入 URL 和 anon key |
| 登录后不同步 | 确认 SQL 迁移已执行，且邮箱已完成魔法链接验证 |
| 离线能用、联网不同步 | 进入同步页点击「立即同步」，查看控制台是否有网络错误 |
| Chrome 能跑、真机看不到设备 | 见 [Android 真机调试](#android-真机调试手势--动效) |
| 手势在 Web 上不顺手 | 属正常，见 [WEB-LIMITATIONS.md](docs/WEB-LIMITATIONS.md)；真机见 Android 清单 |

## License

MIT
