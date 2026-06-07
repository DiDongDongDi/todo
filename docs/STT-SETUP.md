# 语音转写（STT）配置

收集 Tab 使用 **本地录音 + 云端异步转写**，不依赖手机厂商语音引擎。

## 架构

1. App 用 `record` 录制 m4a，保存为任务音频附件
2. 登录且联网时，音频上传 Supabase Storage（`attachments` bucket）
3. 调用 Edge Function [`transcribe`](../supabase/functions/transcribe/index.ts)
4. Edge Function 调 STT 供应商，写回 `tasks.title` 与 `transcription_status`

## 1. 注册 Groq（默认供应商）

> **国内直连常见问题：** 浏览器打开 [console.groq.com](https://console.groq.com) 可能返回 `{"error":{"message":"Forbidden"}}`，属于 Groq 对部分地区或 IP 的拦截，并非账号或项目错误。

### 1a. 仍想用 Groq 时

1. 使用 **VPN / 系统代理** 后再打开控制台（本机代理示例：`http://127.0.0.1:12369`，以你实际可用的为准）
2. 注册并创建 API Key（格式通常以 `gsk_` 开头）
3. 在 Supabase Dashboard → **Project Settings → Edge Functions → Secrets** 添加：

```
GROQ_API_KEY=gsk_...
STT_PROVIDER=groq
```

可选：

```
GROQ_WHISPER_MODEL=whisper-large-v3
```

**说明：** 即使你在国内无法打开 Groq 控制台，只要 Supabase Edge Function 所在区域能访问 Groq API，部署后转写仍可能正常工作；但 **API Key 必须先通过能访问控制台的方式创建**。

### 1b. 无法访问 Groq 时的替代（推荐国内用户）

不必强求 Groq，改用 **OpenAI Whisper**（若你有 OpenAI 账号与 Key）：

在 Supabase Secrets 中设置：

```
STT_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

OpenAI 平台：[platform.openai.com](https://platform.openai.com)（同样可能需要代理注册；Key 仅保存在 Supabase，不进 App）。

若 Groq / OpenAI 均不可用，见下文 [§7 国内网络与 Plan B](#7-国内网络与-plan-b)。

## 2. 部署 Edge Function

在项目根目录（需安装 [Supabase CLI](https://supabase.com/docs/guides/cli)）：

```bash
supabase functions deploy transcribe
```

本地调试：

```bash
supabase secrets set GROQ_API_KEY=gsk_...
supabase functions serve transcribe
```

## 3. 切换 OpenAI Whisper

Secrets：

```
STT_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

## 4. 前置条件

- 已执行 [`001_initial.sql`](../supabase/migrations/001_initial.sql)（含 `transcription_status`）
- 已执行 [`002_storage_rls.sql`](../supabase/migrations/002_storage_rls.sql)（`attachments` bucket）
- 用户已登录（匿名或未登录时任务仅本地 `pending`，登录同步后再转写）

## 5. 客户端行为

| 状态 | 表现 |
|------|------|
| 录音中 | 麦克风变红，卡片提示「录音中…」 |
| 已保存、转写中 | 处理 Tab 标题「转写中…」 |
| 转写完成 | 标题变为识别文本 |
| 转写失败 | 标题「转写失败」，可点刷新重试 |

## 6. 费用参考

Groq Whisper：短语音（10–30 秒）在免费额度内通常足够个人使用。

## 7. 国内网络与 Plan B

| 现象 | 原因 | 建议 |
|------|------|------|
| `console.groq.com` 返回 `Forbidden` | Groq 控制台地域/WAF 限制 | 代理后注册，或改用 OpenAI（§1b） |
| Edge Function 日志里 Groq 请求失败 | Supabase 机房访问 Groq 不稳定 | Secrets 改为 `STT_PROVIDER=openai` |
| 控制台与 API 均不可达 | 无可用海外 STT | 在 Edge Function 内扩展国内 ASR（火山/阿里等），客户端无需改 |

国内 ASR 接入需在 [`supabase/functions/transcribe/index.ts`](../supabase/functions/transcribe/index.ts) 增加对应 `STTProvider`；当前仓库已预留 `STT_PROVIDER` 切换，**App 端录音与 pending 流程不变**。
