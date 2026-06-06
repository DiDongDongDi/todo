# Supabase Storage 附件 RLS 配置

> Phase 2+ 可选：同步图片 / 录音附件时使用。详见 [ARCHITECTURE.md](./ARCHITECTURE.md) Storage 小节。

## 概述

Supabase Storage 的访问控制通过 **`storage.objects` 表的 RLS 策略**实现，而不是在 bucket 上单独配置。Private bucket 默认拒绝所有访问；为 `authenticated` 角色添加策略后，用户只能读写路径第一段为自己 `user_id` 的文件。

| 项 | 值 |
|----|-----|
| Bucket 名称 | `attachments` |
| 可见性 | Private |
| 路径格式 | `{user_id}/{task_id}/{filename}` |

路径第一段必须是当前登录用户的 UUID，与 `tasks.user_id` 一致。

## 快速配置

**推荐：** 在 Supabase Dashboard → **SQL Editor** 中执行 [`supabase/migrations/002_storage_rls.sql`](../supabase/migrations/002_storage_rls.sql) 的全部内容（支持重复执行）。

或在 Dashboard → **Storage** → `attachments` → **Policies** 中手动创建等价策略（见下文「策略说明」）。

## 前提

1. 已执行 [`001_initial.sql`](../supabase/migrations/001_initial.sql)（`tasks` / `operations` 表及 RLS）。
2. 用户已通过 Supabase Auth 登录（App 内魔法链接即可）。

## 迁移 SQL 内容

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false)
ON CONFLICT (id) DO NOTHING;

-- storage.objects 由 supabase_storage_admin 管理：
-- 勿 ALTER TABLE / DROP POLICY（会报 must be owner of table objects）
-- 用 pg_policies 判断后 CREATE POLICY，可重复执行

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'attachments_select_own'
  ) THEN
    CREATE POLICY "attachments_select_own" ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
  -- insert / update / delete 策略同理，见 002_storage_rls.sql 全文
END $$;
```

若已在 Dashboard 手动创建了 `attachments` bucket，迁移中的 `INSERT` 会因 `ON CONFLICT DO NOTHING` 而跳过，不影响已有 bucket。

## 策略说明

| 条件 | 作用 |
|------|------|
| `bucket_id = 'attachments'` | 只作用于该 bucket |
| `(storage.foldername(name))[1] = auth.uid()::text` | 路径第一段必须是当前登录用户 ID |
| `TO authenticated` | 仅已登录用户；匿名用户无法访问 |

因此用户 A 无法读/写用户 B 的 `b-user-id/task-id/file.jpg`，但可以正常访问 `a-user-id/...` 下的文件。

## Dashboard 手动配置（可选）

1. **Storage** → 新建 bucket `attachments`，设为 **Private**。
2. 进入 **Policies**，为 `storage.objects` 新建 4 条策略：SELECT / INSERT / UPDATE / DELETE。
3. **Target roles** 选 `authenticated`。
4. **USING / WITH CHECK** 表达式：

   ```sql
   bucket_id = 'attachments'
   AND (storage.foldername(name))[1] = auth.uid()::text
   ```

   - INSERT：只需 **WITH CHECK**
   - UPDATE：需 **USING** 与 **WITH CHECK** 均填写
   - SELECT / DELETE：只需 **USING**

## App 端上传示例

路径第一段必须是 `auth.currentUser!.id`：

```dart
final userId = supabase.auth.currentUser!.id;
final path = '$userId/$taskId/$filename';

await supabase.storage.from('attachments').upload(path, file);
```

Private bucket 下载需签名 URL：

```dart
final url = await supabase.storage
    .from('attachments')
    .createSignedUrl(path, 3600);
```

上传成功后，将返回的 URL 写入 task 的 `attachments[].remoteUrl`（见 [ARCHITECTURE.md](./ARCHITECTURE.md)）。

## 常见错误

若在 SQL Editor 执行时报 `ERROR: 42501: must be owner of table objects`，通常是因为脚本里含有 `ALTER TABLE storage.objects` 或 `DROP POLICY ... ON storage.objects`。`storage.objects` 归 `supabase_storage_admin` 所有，`postgres` 不能改表结构或删策略；请使用当前版 `002_storage_rls.sql`（仅 `INSERT` + 条件 `CREATE POLICY`）。

若 `CREATE POLICY` 也失败，可改用 Dashboard → **Storage** → `attachments` → **Policies** 手动创建（见上文「Dashboard 手动配置」），或通过 **Connect** → Session pooler 的 `psql` 连接执行。

## 验证

1. 用户 A 登录，上传 `A的UUID/task1/test.jpg` → 应成功。
2. 用户 B 登录，尝试读取或删除 A 的路径 → 应返回 403 或失败。
3. 用户 B 尝试上传到 `A的UUID/...`（伪造第一段路径）→ INSERT 策略应拒绝。

## 相关文档

- [README.md](../README.md) — Supabase 接入步骤
- [ARCHITECTURE.md](./ARCHITECTURE.md) — 附件路径与 `remoteUrl` 设计
- [SUPABASE.md](./SUPABASE.md) — Supabase 入门
