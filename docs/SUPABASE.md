# Supabase 入门笔记

> 本文档整理自项目开发过程中的基础概念说明，便于快速回顾。

## Supabase 是什么？

**Supabase** 是一个开源的 **Backend-as-a-Service（BaaS）** 平台，常被称作「开源版 Firebase」。它帮你在不写大量后端代码的情况下，快速获得数据库、用户认证、文件存储和实时同步等能力。

## 核心能力

| 能力 | 说明 |
|------|------|
| **PostgreSQL 数据库** | 托管的关系型数据库，支持 SQL、行级安全（RLS） |
| **身份认证（Auth）** | 邮箱、OAuth（Google/GitHub 等）、魔法链接等 |
| **实时订阅** | 数据变更可推送到客户端 |
| **存储（Storage）** | 文件/图片上传与管理 |
| **Edge Functions** | 在边缘运行的服务端函数 |
| **REST / GraphQL API** | 基于数据库表自动生成 API |

## 和 Firebase 的对比

- 底层是 **PostgreSQL**，而不是 NoSQL
- **开源**，可自托管，也可使用官方云服务
- 对 SQL 和关系型数据更友好
- 定价模式与 Firebase 类似：有免费额度，按用量计费

## 在本项目中的角色

根据 [ARCHITECTURE.md](./ARCHITECTURE.md)，本项目的后端选型为：

| 层 | 选型 |
|----|------|
| 本地数据库 | drift（SQLite），离线优先 |
| 后端 | Supabase（Postgres + Auth + Storage + Realtime） |
| 同步 | 离线优先 + operations 增量同步 |

当前已接入的部分：

1. **用户认证** — `app/lib/core/auth/auth_service.dart` 通过 `supabase_flutter` 做邮箱 OTP 登录/登出
2. **云端数据（规划中）** — 配置 `url` 和 `anonKey` 后连接 Supabase 项目，配合 SyncEngine 做增量同步

### 配置方式

复制 `app/lib/core/config/supabase_config.example.dart` 为 `supabase_config.dart`，填入在 [supabase.com](https://supabase.com) 创建项目后得到的 URL 和匿名密钥（该文件已在 `.gitignore` 中，不会提交到仓库）。

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

未配置时，`AuthService.isConfigured` 为 `false`，应用可纯本地运行；配置后才会初始化 Supabase 客户端。

### Site URL 与端口

在 Dashboard **Authentication → URL Configuration** 中配置 **Site URL** 时：

| 场景 | 推荐 Site URL |
|------|---------------|
| 原生 App（当前）+ 邮件魔法链接 | `http://localhost`（无需端口） |
| Flutter Web 本地开发 | `http://localhost:端口号`（如 `8080`） |
| 正式 Web 站点 | `https://你的域名` |

**Site URL** 仅在请求未指定 `redirect_to` 时作为回退地址。原生 App 发魔法链接时，代码会通过 `emailRedirectTo` 指定 Deep Link（`com.todo.app.todo_app://login-callback/`），**邮件里的链接应包含该地址，而不是 `http://localhost`**。若邮件链接仍是 `redirect_to=http://localhost`，说明发信时未带上 Deep Link，登录无法跳回 App。

若做 **Flutter Web** 本地开发，除 Site URL 外还需在 **Redirect URLs** 中添加对应地址（如 `http://localhost:8080/**`），并在 Web 端传入该 URL 作为 `emailRedirectTo`。

### 魔法链接邮件与 SMTP

开发调试时频繁发送魔法链接会触发 Supabase 默认邮件限流。解决方式：在 Dashboard 配置 **自定义 SMTP**。  
QQ 邮箱逐步配置、其他服务商对照表见 **[SUPABASE-SMTP.md](./SUPABASE-SMTP.md)**。

## 典型使用流程

1. 在 Supabase 官网注册并创建项目
2. 在控制台建表（如 `tasks`）
3. 配置 RLS（Row Level Security）策略，控制谁能读写哪些数据
4. 在客户端用 SDK 连接，进行 CRUD 和 Auth

## 一句话概括

Supabase = 托管 PostgreSQL + 认证 + 存储 + 实时 API，让你专注做前端/客户端，后端基础设施由它提供。
