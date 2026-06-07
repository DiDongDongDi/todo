# 语音转写（STT）配置

收集 Tab 使用 **本地录音 + 云端异步转写**，不依赖手机厂商语音引擎。

## 架构

1. App 用 `record` 录制 m4a，保存为任务音频附件
2. 登录且联网时，音频上传 Supabase Storage（`attachments` bucket）
3. 调用 Edge Function [`transcribe`](../supabase/functions/transcribe/index.ts)
4. Edge Function 调 STT 供应商，写回 `tasks.title` 与 `transcription_status`

## 什么是 Edge Function？

**Edge Function（边缘函数）** 是跑在 **Supabase 云端** 里的一小段服务端代码，不是你的 Flutter App，也不是你本机的脚本。

可以把它理解成：**Supabase 帮你托管的「轻量后端接口」**——你写好函数、用 CLI 部署上去，App 或网页通过 HTTP 调用它，逻辑在云端执行。

### 和 App 里直接调 Groq 有什么区别？

| | App 直接调 Groq | 通过 Edge Function |
|--|----------------|-------------------|
| **API Key 放哪** | 必须打进 App，可被反编译泄露 | 只存在 Supabase **Secrets**，客户端看不到 |
| **谁能调用** | 任何人拿到 Key 都能滥用 | 需带 Supabase **登录 JWT**，函数内可校验用户 |
| **能做什么** | 只能调外部 API | 可同时读 **Storage**、写 **数据库**、再调 Groq |
| **运行环境** | 用户手机 | Supabase 边缘节点（靠近机房的 Deno 运行时） |

本项目的转写流程里，App **只负责**上传录音到 Storage，然后 `invoke('transcribe', ...)`；**下载音频、调 Whisper、更新 `tasks` 表** 都在 Edge Function 里完成，Groq/OpenAI 的 Key 永远不会进 APK。

### 在本项目里具体指什么？

- **源码**：[`supabase/functions/transcribe/index.ts`](../supabase/functions/transcribe/index.ts)（TypeScript，运行在 Deno）
- **部署后**：Supabase 会给你一个 HTTPS 地址，例如  
  `https://<project-ref>.supabase.co/functions/v1/transcribe`
- **App 调用**：`AuthService` 登录后的客户端执行  
  `client.functions.invoke('transcribe', body: { taskId, storagePath })`
- **Secrets**：`GROQ_API_KEY`、`STT_PROVIDER` 等环境变量，在 Dashboard 或 `supabase secrets set` 配置，函数内用 `Deno.env.get(...)` 读取

### 和「数据库 / Storage」的分工

```text
Flutter App          Supabase 云端
───────────          ─────────────
录音 → 本地文件  →   Storage（attachments 桶）
同步 tasks      →   PostgreSQL（tasks 表）
invoke transcribe →  Edge Function transcribe
                         ├─ 从 Storage 取 m4a
                         ├─ 调 Groq / OpenAI Whisper
                         └─ UPDATE tasks SET title=..., transcription_status='done'
```

**Edge Function 不是** Postgres 的触发器，也**不是** Storage 的上传接口；它是 **按需调用的自定义后端逻辑**。没有部署 `transcribe` 时，录音能保存，但标题会一直停在「转写中…」。

更多 Supabase 整体概念见 [SUPABASE.md](./SUPABASE.md#edge-functions边缘函数)。

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

若 Groq / OpenAI 均不可用，见下文 [§8 国内网络与 Plan B](#8-国内网络与-plan-b)。

## 2. 安装 Supabase CLI（Windows）

报错 `无法将“supabase”项识别为 cmdlet` 表示 **未安装 CLI 或未加入 PATH**，不是部署命令写错了。

任选一种方式：

### 方式 A：Scoop（推荐，可全局使用 `supabase`）

在 PowerShell 中：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
supabase --version
```

### 方式 B：项目内二进制（无需 Scoop / Node）

仓库已支持将 CLI 放在 `tools/supabase.exe`。若还没有，在项目根目录执行（需可访问 GitHub，必要时开代理）：

```powershell
$proxy = "http://127.0.0.1:12369"   # 按你的代理修改；无代理可去掉 -x 参数
New-Item -ItemType Directory -Force -Path tools | Out-Null
curl.exe -x $proxy -sL "https://github.com/supabase/cli/releases/download/v2.105.0/supabase_windows_amd64.tar.gz" -o tools/supabase_windows_amd64.tar.gz
tar -xzf tools/supabase_windows_amd64.tar.gz -C tools
.\tools\supabase.exe --version
```

之后用 **`.\tools\supabase.exe`** 代替文档里的 `supabase` 命令。

> **说明：** `npm install -g supabase` / `pnpm dlx supabase` 需要本机已安装 **Node.js**；若只有 Flutter、没有 Node，请用 Scoop 或方式 B。

### 登录并关联项目

```powershell
# 若用方式 B，将 supabase 换成 .\tools\supabase.exe
supabase login
supabase link --project-ref gurtakyggjaphkagzmgf
```

`project-ref` 即 Supabase 项目 URL 中的子域名（例如 `https://xxxx.supabase.co` 里的 `xxxx`）。

## 3. 部署 Edge Function

在项目根目录 `todo/`：

```powershell
supabase secrets set GROQ_API_KEY=gsk_... STT_PROVIDER=groq
supabase functions deploy transcribe
```

使用方式 B 时：

```powershell
.\tools\supabase.exe secrets set GROQ_API_KEY=gsk_... STT_PROVIDER=groq
.\tools\supabase.exe functions deploy transcribe
```

也可在 **Supabase Dashboard → Project Settings → Edge Functions → Secrets** 网页里配置密钥，CLI 只负责 `deploy`。

### 本地调试（可选，与上面部署是两条路）

| | **§3 部署（正式用）** | **本地调试（开发函数代码）** |
|--|----------------------|------------------------------|
| 目的 | App 真机/模拟器走 **云端** 转写 | 在本机跑 `transcribe` 源码，改代码立刻试 |
| 函数跑在哪 | Supabase 云端 | 你电脑上的 Deno（`functions serve`） |
| 密钥放哪 | `secrets set` 或 Dashboard → **远程项目 Secrets** | `supabase/functions/.env`（**不要提交 Git**） |
| App 要不要改 | 不用，默认调云端 URL | 一般要改客户端指向 `http://127.0.0.1:54321/...`，或只用 curl 测 |

**关系说明：**

- **`secrets set`** 写入的是 **已 link 的远程 Supabase 项目** 的环境变量，供 **`functions deploy` 之后** 云端运行时读取；**不是**给本机 `serve` 用的。
- **`functions deploy`** 只上传代码；Secrets 已在云端则 **无需为改 Key 重新 deploy**。
- **`functions serve`** **不会部署** 任何东西；它在本地启动一个临时 HTTP 服务，读 `supabase/functions/.env`（或 `--env-file`）。

日常让 Flutter App 能转写，做完 **login → link → secrets set → deploy** 即可，**不必**跑 `serve`。

若要在本机调试函数逻辑，先建 `supabase/functions/.env`（示例）：

```env
GROQ_API_KEY=gsk_...
STT_PROVIDER=groq
SUPABASE_URL=https://gurtakyggjaphkagzmgf.supabase.co
SUPABASE_ANON_KEY=你的anon_key
SUPABASE_SERVICE_ROLE_KEY=你的service_role_key
```

后两项在 Dashboard → **Settings → API**；`service_role` 仅本地调试，勿打进 App。

```powershell
# 方式 B 时把 supabase 换成 .\tools\supabase.exe
supabase functions serve transcribe --env-file supabase/functions/.env
```

另开终端用 curl 带 **用户 JWT** 调用 `http://127.0.0.1:54321/functions/v1/transcribe` 验证；Storage / 数据库仍用 **云端** 项目（除非另起 `supabase start` 全栈本地）。

调试完要上线：把 `.env` 里 STT 相关变量同步到远程（二选一）：

```powershell
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy transcribe
```

## 4. 切换 OpenAI Whisper

Secrets：

```
STT_PROVIDER=openai
OPENAI_API_KEY=sk-...
```

## 5. 前置条件

- 已执行 [`001_initial.sql`](../supabase/migrations/001_initial.sql)（含 `transcription_status`）
- 已执行 [`002_storage_rls.sql`](../supabase/migrations/002_storage_rls.sql)（`attachments` bucket）
- 用户已登录（匿名或未登录时任务仅本地 `pending`，登录同步后再转写）

## 6. 客户端行为

| 状态 | 表现 |
|------|------|
| 录音中 | 麦克风变红，卡片提示「录音中…」 |
| 已保存、转写中 | 处理 Tab 标题「转写中…」 |
| 转写完成 | 标题变为识别文本 |
| 转写失败 | 标题「转写失败」，可点刷新重试 |

## 7. 费用参考

Groq Whisper：短语音（10–30 秒）在免费额度内通常足够个人使用。

## 8. 国内网络与 Plan B

| 现象 | 原因 | 建议 |
|------|------|------|
| `console.groq.com` 返回 `Forbidden` | Groq 控制台地域/WAF 限制 | 代理后注册，或改用 OpenAI（§1b） |
| Edge Function 日志里 Groq 请求失败 | Supabase 机房访问 Groq 不稳定 | Secrets 改为 `STT_PROVIDER=openai` |
| 控制台与 API 均不可达 | 无可用海外 STT | 在 Edge Function 内扩展国内 ASR（火山/阿里等），客户端无需改 |

国内 ASR 接入需在 [`supabase/functions/transcribe/index.ts`](../supabase/functions/transcribe/index.ts) 增加对应 `STTProvider`；当前仓库已预留 `STT_PROVIDER` 切换，**App 端录音与 pending 流程不变**。
