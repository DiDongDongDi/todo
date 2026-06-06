-- attachments bucket + Storage RLS（Phase 2+ 附件同步）
-- 说明见 docs/SUPABASE-STORAGE-RLS.md

INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false)
ON CONFLICT (id) DO NOTHING;

-- storage.objects 由 supabase_storage_admin 管理，postgres 无法 ALTER TABLE；
-- RLS 在 Supabase 上已默认开启，无需手动 ENABLE。

DROP POLICY IF EXISTS "attachments_select_own" ON storage.objects;
DROP POLICY IF EXISTS "attachments_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "attachments_update_own" ON storage.objects;
DROP POLICY IF EXISTS "attachments_delete_own" ON storage.objects;

CREATE POLICY "attachments_select_own"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "attachments_insert_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "attachments_update_own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "attachments_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
