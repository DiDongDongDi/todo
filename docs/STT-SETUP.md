# 语音转写（STT）配置

收集 Tab 使用 **本地录音 + 云端异步转写**，不依赖手机厂商语音引擎。

## 架构

1. App 用 `record` 录制 m4a，保存为任务音频附件
2. 登录且联网时，音频上传 Supabase Storage（`attachments` bucket）
3. 调用 Edge Function [`transcribe`](../supabase/functions/transcribe/index.ts)
4. Edge Function 调 STT 供应商，写回 `tasks.title` 与 `transcription_status`

## 1. 注册 Groq（默认供应商）

1. 打开 [console.groq.com](https://console.groq.com) 注册
2. 创建 API Key
3. 在 Supabase Dashboard → **Project Settings → Edge Functions → Secrets** 添加：

```
GROQ_API_KEY=gsk_...
STT_PROVIDER=groq
```

可选：

```
GROQ_WHISPER_MODEL=whisper-large-v3
```

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

## 7. 国内网络

若 Groq/OpenAI 在 Edge Function 所在区域不可达，可将 `STT_PROVIDER` 换为自建网关或后续接入火山/阿里 ASR（在 Edge Function 内扩展 `STTProvider` 即可，客户端无需改动）。
