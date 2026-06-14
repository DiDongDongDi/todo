# 远程资源限额

官方托管模式下，用于限制用户恶意消耗 Groq/OpenAI、Supabase DB、Storage 等远程资源。服务端强制为主，客户端校验为辅。

## 问 AI — `recommend-tasks`

| 项 | 默认限额 | 环境变量 |
|----|----------|----------|
| 每分钟调用 | 3 次 / 用户 | `AI_RECOMMEND_PER_MINUTE` |
| 每日调用 | 30 次 / 用户 | `AI_RECOMMEND_PER_DAY` |
| 用户描述 `query` | 500 字 | `AI_RECOMMEND_QUERY_MAX` |
| 参与推荐的任务条数 | 不限制 | — |
| 参与推荐的任务总文字量 | 32,000 字 | `AI_RECOMMEND_TASKS_TEXT_MAX` |
| 单条任务 `title` | 不限制、不截断 | — |

- 任务由 Edge Function 用 JWT 从 DB 拉取（`inbox` + `someday` 父任务），请求体仅 `{ "query": "..." }`。
- 超出总文字预算时停止纳入后续任务，不截断已纳入的 title。

## 语音转写 — `transcribe`

| 项 | 默认限额 | 环境变量 |
|----|----------|----------|
| 每分钟调用 | 2 次 / 用户 | `AI_TRANSCRIBE_PER_MINUTE` |
| 每日调用 | 20 次 / 用户 | `AI_TRANSCRIBE_PER_DAY` |
| 单文件大小 | 10 MB | `AI_TRANSCRIBE_MAX_AUDIO_BYTES` |
| 单用户 pending 转写 | 20 条 | 客户端 `ResourceLimits.maxPendingTranscriptions` |

## 数据库

| 项 | 默认限额 | 实现 |
|----|----------|------|
| 单用户活跃任务数 | 5,000 条 | [`010_resource_limits.sql`](../supabase/migrations/010_resource_limits.sql) 触发器 |
| `note` 字段 | 不存在 | 已由 `006_drop_note.sql` 删除 |

## Storage

| 项 | 默认限额 | 实现 |
|----|----------|------|
| 单文件（录音） | 10 MB | 客户端上传前校验 |
| 单文件（图片） | 5 MB | 客户端上传前校验 |
| 单用户总 Storage | 500 MB | 客户端上传前估算 |
| 单任务附件数 | 5 个 | 收集页拦截 |

常量定义：[`app/lib/core/limits/resource_limits.dart`](../app/lib/core/limits/resource_limits.dart)

## AI 用量日志清理

Edge Function [`cleanup-ai-usage`](../supabase/functions/cleanup-ai-usage/index.ts) 删除超过 7 天的 `ai_usage_log` 记录。

### 清理的是什么？

`ai_usage_log` 是 **AI 限流用的调用日志**，不是业务数据。每次用户成功通过限流检查并调用以下函数时，会写入一条记录：

| `action` | 来源 |
|----------|------|
| `recommend` | `recommend-tasks`（问 AI） |
| `transcribe` | `transcribe`（语音转写） |

每条记录含 `user_id`、调用类型、`created_at`。Edge Function 据此统计「最近 1 分钟 / 最近 24 小时」调用次数，超限则返回 429。

**定时清理会删除：** 超过 7 天的上述日志（默认，见 `AI_USAGE_LOG_RETENTION_DAYS`）。

**不会删除：** 待办任务（`tasks`）、附件（Storage）、用户账号、清单等业务数据；也不影响 Groq 账单本身。

### 不配定时清理会怎样？

| 方面 | 影响 |
|------|------|
| 功能 | 问 AI、转写、限流 **照常工作** |
| 数据库 | `ai_usage_log` 持续增大（每次 AI 调用 +1 行） |
| 长期 | 表变大 → 限流 COUNT 变慢 → DB 存储与读写成本略增 |
| 风险 | 低～中：用户少可拖很久；用户多、调用频繁时建议配置 Schedule |

可理解为 **访问日志的定期删除**，非核心业务表。刚上线、用户少时可先不配 Schedule；量上来后再 `deploy cleanup-ai-usage` 并加每日定时任务即可。

### `CRON_SECRET` 是什么？

文档里的 `your-random-secret` **不是** Supabase 或 Groq 提供的固定值，而是占位符，表示 **你自己生成的一串随机密钥**。

| 项 | 说明 |
|----|------|
| 用途 | 防止他人随意调用 `cleanup-ai-usage`；仅持有正确密钥的定时任务可执行清理 |
| 存放位置 | Supabase Secrets（`CRON_SECRET`）+ Dashboard Schedule 的 HTTP 头（`x-cron-secret`） |
| 与 LLM Key 关系 | 无关；只用于定时清理，不参与 App 或 AI 调用 |

函数逻辑：若配置了 `CRON_SECRET`，请求头 `x-cron-secret` 必须与 Secrets 中的值一致，否则返回 401。

### 生成密钥

任意足够长、难猜的随机字符串即可，例如 PowerShell：

```powershell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
```

记下输出（示例：`k8F2mN9pQ4xR7vL1sT6wZ3aB0cD5eH8j=`），**两处填同一个值**。

### 部署

```bash
supabase functions deploy cleanup-ai-usage
supabase secrets set CRON_SECRET=k8F2mN9pQ4xR7vL1sT6wZ3aB0cD5eH8j=
```

在 Supabase Dashboard → **Edge Functions** → **Schedules** 添加每日调用，HTTP 头：

```http
x-cron-secret: k8F2mN9pQ4xR7vL1sT6wZ3aB0cD5eH8j=
```

**注意：** 不要将 `CRON_SECRET` 写入 Git、Flutter 客户端或公开文档；仅保存在 Supabase Secrets 与 Schedule 配置中。若暂不配置 Schedule，可先不设置该 Secret（此时勿将 cleanup 函数暴露给不可信调用方）。

保留天数环境变量：`AI_USAGE_LOG_RETENTION_DAYS`（默认 7）

## 运维告警（建议）

1. **Groq Dashboard** — 设置月度 spend cap 与邮件告警
2. **Supabase Dashboard** — Database size、Storage、Edge Function invocations 告警
3. **Edge Function 日志** — 记录 `user_id`、`action`、429 拒绝（不记录 query 全文）

## 用户可见错误文案

| 场景 | 文案 |
|------|------|
| AI 每分钟超限 | 操作太频繁，请稍后再试 |
| AI 每日超限 | 今日 AI 推荐次数已用完，明天再试 |
| 转写每日超限 | 今日语音转写次数已用完，明天再试 |
| 任务数超限 | 任务数量已达上限（5000 条），请归档或删除后再添加 |
| 附件过大 | 文件过大，录音请控制在 10MB 以内 |
| Storage 配额 | 云存储空间已达上限（500MB），请删除部分附件后再试 |

## 相关文档

- [AI-SETUP.md](./AI-SETUP.md) — AI 推荐部署
- [STT-SETUP.md](./STT-SETUP.md) — 语音转写部署
