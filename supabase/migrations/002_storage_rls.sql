-- attachments bucket + Storage RLS（Phase 2+ 附件同步）
-- 说明见 docs/SUPABASE-STORAGE-RLS.md
--
-- storage.objects 由 supabase_storage_admin 管理：
-- - 勿 ALTER TABLE / DROP POLICY（postgres 非 owner，会报 42501）
-- - RLS 已默认开启；CREATE POLICY 可在 SQL Editor 执行
-- - 用 pg_policies 判断实现可重复执行

INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'attachments_select_own'
  ) THEN
    CREATE POLICY "attachments_select_own"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'attachments_insert_own'
  ) THEN
    CREATE POLICY "attachments_insert_own"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'attachments_update_own'
  ) THEN
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
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'attachments_delete_own'
  ) THEN
    CREATE POLICY "attachments_delete_own"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;
