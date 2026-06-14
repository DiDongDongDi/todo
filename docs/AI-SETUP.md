# AI 任务推荐部署指南

## 概述

`recommend-tasks` Edge Function 根据用户描述，从收集箱和将来也许任务中推荐匹配项，并生成清单名称。

调用任意 **OpenAI 兼容** Chat Completions API（Groq、OpenAI、自建网关等），通过 URL + Key + Model 三件套配置，不绑定具体厂商。

## 前置条件

1. App 已配置 Supabase 连接（[`app/lib/core/config/supabase_config.example.dart`](../app/lib/core/config/supabase_config.example.dart)）
2. 已执行数据库迁移至 `010_resource_limits.sql`（见下文「数据库迁移」）
3. 已安装 Supabase CLI 并 `supabase link` 到项目

语音转写（`transcribe`）配置独立，见 [STT-SETUP.md](./STT-SETUP.md)。

## 环境变量

在 Supabase 项目 Secrets 中配置（Dashboard → **Project Settings → Edge Functions → Secrets**，或 `supabase secrets set`）：

| 变量 | 必填 | 说明 |
|------|------|------|
| `AI_CHAT_URL` | 是 | Chat Completions 完整 HTTP 地址（OpenAI 兼容 `/v1/chat/completions`） |
| `AI_API_KEY` | 是 | 该站点的 API Key（Bearer Token） |
| `AI_CHAT_MODEL` | 是 | 模型名称，由站点文档决定 |

| 变量 | 说明 | 默认 |
|------|------|------|
| `AI_RECOMMEND_PER_MINUTE` | 每用户每分钟调用上限 | `3` |
| `AI_RECOMMEND_PER_DAY` | 每用户每日调用上限 | `30` |
| `AI_RECOMMEND_QUERY_MAX` | 用户描述最大字数 | `500` |
| `AI_RECOMMEND_TASKS_TEXT_MAX` | 参与推荐的任务 title 总字符预算 | `32000` |

限额详情见 [RESOURCE-LIMITS.md](./RESOURCE-LIMITS.md)。

### 配置示例

```powershell
# Groq（OpenAI 兼容）
supabase secrets set `
  AI_CHAT_URL=https://api.groq.com/openai/v1/chat/completions `
  AI_API_KEY=gsk_... `
  AI_CHAT_MODEL=llama-3.3-70b-versatile

# OpenAI 官方
supabase secrets set `
  AI_CHAT_URL=https://api.openai.com/v1/chat/completions `
  AI_API_KEY=sk-... `
  AI_CHAT_MODEL=gpt-4o-mini

# 自建 / 第三方 OpenAI 兼容网关
supabase secrets set `
  AI_CHAT_URL=https://your-gateway.example.com/v1/chat/completions `
  AI_API_KEY=your-key `
  AI_CHAT_MODEL=your-model-id
```

### API 契约

Edge Function 向 `AI_CHAT_URL` 发送 OpenAI Chat Completions 格式请求：

- `POST`，Header `Authorization: Bearer ${AI_API_KEY}`
- Body：`model`、`messages`、`temperature: 0.3`、`response_format: { type: "json_object" }`

站点须支持 **Chat Completions + JSON mode**（或等价行为）。

## 部署

```bash
supabase functions deploy recommend-tasks
```

部署前请确认 Secrets 中已设置 `AI_CHAT_URL`、`AI_API_KEY`、`AI_CHAT_MODEL`。

## 本地调试（可选）

在 `supabase/functions/.env`（勿提交 Git）中配置：

```env
AI_CHAT_URL=https://api.groq.com/openai/v1/chat/completions
AI_API_KEY=gsk_...
AI_CHAT_MODEL=llama-3.3-70b-versatile
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

```powershell
supabase functions serve recommend-tasks --env-file supabase/functions/.env
```

调试完成后，将变量同步到远程：

```powershell
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy recommend-tasks
```

## 数据库迁移

确保已应用：

- `008_someday_status.sql` — someday 任务状态
- `009_task_playlists.sql` — 任务清单表
- `010_resource_limits.sql` — AI 用量日志与任务数上限

## 客户端调用

登录后，底部导航「问 AI」Tab 输入需求即可。未登录时 UI 会提示先登录。

请求体：

```json
{
  "query": "今天想整理家里"
}
```

响应体：

```json
{
  "recommendedIds": ["uuid"],
  "playlistName": "家务整理",
  "summary": "推荐与整理相关的任务"
}
```

## 限制

- 任务由服务端从 DB 拉取，客户端不再传 `tasks`
- 参与推荐的任务条数不限制；总 title 字符数受 `AI_RECOMMEND_TASKS_TEXT_MAX` 约束
- 需用户 JWT 鉴权；超限返回 429
