-- tasks 表
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  note TEXT,
  status TEXT NOT NULL DEFAULT 'inbox' CHECK (status IN ('inbox', 'archived', 'trashed')),
  sort_order DOUBLE PRECISION NOT NULL DEFAULT 0,
  attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  transcription_status TEXT NOT NULL DEFAULT 'none',
  archived_at TIMESTAMPTZ,
  trashed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  sync_version INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS tasks_user_status_idx ON public.tasks (user_id, status);
CREATE INDEX IF NOT EXISTS tasks_updated_at_idx ON public.tasks (user_id, updated_at DESC);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tasks_select_own ON public.tasks;
CREATE POLICY tasks_select_own ON public.tasks
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS tasks_insert_own ON public.tasks;
CREATE POLICY tasks_insert_own ON public.tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS tasks_update_own ON public.tasks;
CREATE POLICY tasks_update_own ON public.tasks
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS tasks_delete_own ON public.tasks;
CREATE POLICY tasks_delete_own ON public.tasks
  FOR DELETE USING (auth.uid() = user_id);

-- operations 增量同步表
CREATE TABLE IF NOT EXISTS public.operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  op_type TEXT NOT NULL CHECK (op_type IN ('insert', 'update', 'delete')),
  payload JSONB NOT NULL,
  device_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS operations_user_created_idx
  ON public.operations (user_id, created_at DESC);

ALTER TABLE public.operations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS operations_select_own ON public.operations;
CREATE POLICY operations_select_own ON public.operations
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS operations_insert_own ON public.operations;
CREATE POLICY operations_insert_own ON public.operations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Storage bucket（在 Supabase Dashboard 创建 attachments 桶后执行策略）
-- INSERT INTO storage.buckets (id, name, public) VALUES ('attachments', 'attachments', false);
