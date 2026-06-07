-- Subtasks: parent_id on tasks
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS tasks_parent_id_idx ON public.tasks (parent_id);

-- Task templates
CREATE TABLE IF NOT EXISTS public.task_templates (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  note TEXT,
  attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_daily BOOLEAN NOT NULL DEFAULT false,
  daily_until DATE,
  due_date DATE,
  subtask_titles JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sync_version INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS task_templates_user_updated_idx
  ON public.task_templates (user_id, updated_at DESC);

ALTER TABLE public.task_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS task_templates_select_own ON public.task_templates;
CREATE POLICY task_templates_select_own ON public.task_templates
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS task_templates_insert_own ON public.task_templates;
CREATE POLICY task_templates_insert_own ON public.task_templates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS task_templates_update_own ON public.task_templates;
CREATE POLICY task_templates_update_own ON public.task_templates
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS task_templates_delete_own ON public.task_templates;
CREATE POLICY task_templates_delete_own ON public.task_templates
  FOR DELETE USING (auth.uid() = user_id);
