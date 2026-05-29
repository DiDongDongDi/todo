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

### 4. 指定设备运行

```bash
# 查看可用设备
flutter devices

# Android 真机 / 模拟器
flutter run -d android

# iOS 模拟器（仅 macOS）
flutter run -d ios

# Windows 桌面
flutter run -d windows

# macOS 桌面
flutter run -d macos

# Web 浏览器
flutter run -d chrome
```

### 5. 运行单元测试

```bash
cd app
flutter test
```

### 不配置 Supabase 也能用

未配置 Supabase 时，应用以**纯本地模式**运行：收集、处理、归档、回收站等功能均可离线使用，数据保存在本机（SharedPreferences）。

---

## Supabase 配置（多设备同步）

配置完成后，可在手机收集任务、在桌面处理页看到同一条数据。

### 1. 创建 Supabase 项目

1. 打开 [Supabase](https://supabase.com) 并登录
2. 点击 **New project**，选择区域并设置数据库密码
3. 等待项目创建完成

### 2. 执行数据库迁移

在 Supabase Dashboard 中打开 **SQL Editor**，将 [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql) 的全部内容粘贴并执行。

迁移会创建：

- `tasks` 表 — 任务数据
- `operations` 表 — 增量同步日志
- 行级安全策略（RLS）— 用户只能访问自己的数据

### 3. 开启邮箱登录（魔法链接）

1. 进入 **Authentication → Providers**
2. 确认 **Email** 已启用
3. 在 **Authentication → URL Configuration** 中，将 **Site URL** 设为你的应用地址（本地开发可先用 `http://localhost`）

### 4. 填入 API 密钥

1. 进入 **Project Settings → API**
2. 复制 **Project URL** 和 **anon public** key
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
| `flutter` 命令找不到 | 安装 Flutter SDK 并将其 `bin` 目录加入 PATH |
| `flutter run` 报缺少平台目录 | 执行 `scripts/init_platforms.ps1` 或 `flutter create .` |
| App 显示「Supabase 未配置」 | 检查 `supabase_config.example.dart` 是否已填入 URL 和 anon key |
| 登录后不同步 | 确认 SQL 迁移已执行，且邮箱已完成魔法链接验证 |
| 离线能用、联网不同步 | 进入同步页点击「立即同步」，查看控制台是否有网络错误 |

## License

MIT
