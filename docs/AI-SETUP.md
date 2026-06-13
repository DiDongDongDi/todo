# AI 任务推荐部署指南

## 概述

`recommend-tasks` Edge Function 根据用户描述，从收集箱和将来也许任务中推荐匹配项，并生成清单名称。

## 环境变量

在 Supabase 项目 Secrets 中配置（与 STT 共用 Key 即可）：

| 变量 | 说明 | 默认 |
|------|------|------|
| `LLM_PROVIDER` | `groq` 或 `openai` | `groq` |
| `GROQ_API_KEY` | Groq API Key | — |
| `GROQ_CHAT_MODEL` | Groq 聊天模型 | `llama-3.3-70b-versatile` |
| `OPENAI_API_KEY` | OpenAI API Key（`LLM_PROVIDER=openai` 时） | — |
| `OPENAI_CHAT_MODEL` | OpenAI 聊天模型 | `gpt-4o-mini` |

## 部署

```bash
supabase functions deploy recommend-tasks
```

## 数据库迁移

确保已应用：

- `008_someday_status.sql` — someday 任务状态
- `009_task_playlists.sql` — 任务清单表

## 客户端调用

登录后，处理页点击「问 AI」按钮，输入需求即可。未登录时 UI 会提示先登录。

请求体：

```json
{
  "query": "今天想整理家里",
  "tasks": [
    { "id": "uuid", "title": "打扫厨房", "status": "inbox" }
  ]
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

- 客户端最多发送 200 条父任务摘要
- LLM 只能推荐请求中存在的任务 ID
- 需用户 JWT 鉴权
