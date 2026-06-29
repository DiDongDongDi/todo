ALTER TABLE public.task_templates
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
