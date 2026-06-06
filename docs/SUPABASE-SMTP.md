# Supabase 自定义 SMTP（魔法链接邮件）

> 开发 / 自用时，Supabase **内置邮件**限额很低，频繁点「发送魔法链接」容易触发 `over_email_send_rate_limit`（HTTP 429）。  
> 配置自定义 SMTP 后，由你的邮箱服务商发信，限额更高、也更稳定。

## 为什么需要

| 发信方式 | 典型限额 | 适用 |
|----------|----------|------|
| Supabase 默认邮件 | 约 **2～4 封 / 小时**（免费项目） | 偶尔试一次 |
| 自定义 SMTP | 取决于服务商（QQ 邮箱个人额度、SendGrid / Resend 等） | 开发调试、自用、上线 |

App 内若触发限流，会提示：「发送太频繁，请约 1 小时后再试…」（见 `app/lib/core/auth/auth_error_messages.dart`）。

## 在 Dashboard 中开启

1. 打开 [Supabase Dashboard](https://supabase.com/dashboard) → 你的项目  
2. **Project Settings** → **Authentication**  
3. 找到 **SMTP Settings**（部分界面在 **Emails** 子页下）  
4. 打开 **Enable Custom SMTP**  
5. 填入服务商提供的参数（下方有 QQ 邮箱示例）  
6. 点击 **Save**

配置成功后，Auth 相关邮件（魔法链接、确认邮件等）都走你的 SMTP，不再走 Supabase 默认通道。

### 字段说明

| 字段 | 含义 |
|------|------|
| **Sender email** | 收件人看到的「发件人」邮箱地址 |
| **Sender name** | 发件人显示名称（如 `Todo App`） |
| **Host** | SMTP 服务器主机名（不要带 `http://`） |
| **Port** | 常见 `465`（SSL）或 `587`（STARTTLS） |
| **Username** | SMTP 登录用户名 |
| **Password** | SMTP 密码或授权码（不是邮箱网页登录密码） |

### 配置后调整限流（建议）

启用自定义 SMTP 后，Supabase 仍可能保留较低的 Auth 邮件限流。可在：

**Authentication → Rate Limits**

中适当提高 **Email sent** 等项（按你的使用场景调整，开发环境可放宽，生产环境勿设过高以防滥用）。

官方说明：[Send emails with custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)

---

## QQ 邮箱配置示例

适合**个人开发 / 自用**。正式产品更推荐自有域名 + SendGrid、Resend、Mailgun 等（送达率与信誉更好）。

### 第一步：在 QQ 邮箱开启 SMTP 并获取授权码

1. 浏览器打开 [mail.qq.com](https://mail.qq.com) 并登录  
2. 右上角 **设置** → **账号与安全**（旧版界面可能在 **设置 → 账户**）  
3. 找到 **POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV 服务**  
4. 开启 **IMAP/SMTP 服务** 或 **POP3/SMTP 服务**（任选其一即可发信）  
5. 按提示完成手机 / QQ 验证  
6. 点击 **生成授权码**，得到 **16 位授权码**（只显示一次，请保存）

> **重要：** 第三方客户端（含 Supabase SMTP）的 **Password 必须填授权码**，不能填 QQ 登录密码。  
> 修改 QQ 密码或主动失效授权码后，需重新生成并在 Supabase 里更新。

官方帮助：[如何生成授权码](https://help.mail.qq.com/detail/0/985)

### 第二步：填入 Supabase SMTP Settings

假设你的 QQ 邮箱为 `yourname@qq.com`，授权码为 `abcdefghijklmnop`（示例，请替换为真实值）：

| 字段 | 填写值 |
|------|--------|
| **Sender email** | `yourname@qq.com`（须与 SMTP 登录邮箱一致） |
| **Sender name** | `Todo` 或任意显示名 |
| **Host** | `smtp.qq.com` |
| **Port** | `465`（优先；若保存失败可试 `587`） |
| **Username** | `yourname@qq.com`（完整邮箱地址） |
| **Password** | 上一步的 **16 位授权码** |

保存后，在 App **账号与同步** 页重新发送魔法链接测试。

### 常见问题（QQ 邮箱）

| 现象 | 处理 |
|------|------|
| SMTP 登录失败 / 密码错误 | 确认填的是**授权码**；重新生成授权码并更新 Supabase |
| 仍报 rate limit | 等内置限流窗口过去；并在 **Rate Limits** 中调高；确认已保存自定义 SMTP |
| 收不到邮件 | 查垃圾箱；确认 QQ 邮箱 SMTP 服务已开启；在 Supabase **Authentication → Logs** 看发信是否成功 |
| 发件进垃圾箱 | 个人 `@qq.com` 发系统邮件较常见；自用可接受，上线建议换域名邮箱 |

---

## 其他服务商（简要）

只需把 **Host / Port / Username / Password** 换成对应文档中的 SMTP 凭证，步骤与上文相同。

| 服务商 | Host | Port | Username | Password |
|--------|------|------|----------|----------|
| [Resend](https://resend.com) | `smtp.resend.com` | 465 或 587 | `resend` | API Key（`re_...`） |
| [SendGrid](https://sendgrid.com) | `smtp.sendgrid.net` | 587 | `apikey` | API Key（`SG....`） |

使用自有域名时，通常还需在服务商处验证域名并配置 SPF / DKIM。

---

## 与本项目的关系

- 发魔法链接：`app/lib/core/auth/auth_service.dart` → `signInWithOtp`  
- 登录页与错误提示：`app/lib/features/auth/auth_screen.dart`  
- Redirect URL 等仍见 [README 邮箱登录章节](../README.md#3-开启邮箱登录魔法链接)
