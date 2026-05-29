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

## 快速开始

```bash
# 1. 生成 Android / iOS / Windows 等平台目录（首次）
powershell -ExecutionPolicy Bypass -File scripts/init_platforms.ps1

cd app
flutter pub get
flutter run
```

### Supabase 配置（Phase 2 同步）

1. 创建 [Supabase](https://supabase.com) 项目
2. 执行 `supabase/migrations/` 中的 SQL
3. 复制 `app/lib/core/config/supabase_config.example.dart` 为 `supabase_config.dart` 并填入 URL / anon key

```bash
# 示例：Android
flutter run -d android

# 示例：Web
flutter run -d chrome

# 示例：Windows
flutter run -d windows
```

## 项目结构

```
todo/
├── docs/           # 产品与技术文档
├── app/            # Flutter 应用
└── supabase/       # 数据库迁移与 RLS
```

## 技术栈

Flutter · Riverpod · Drift · go_router · Supabase

## License

MIT
