-- Add someday/maybe status and timestamp
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS someday_at TIMESTAMPTZ;

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_status_check;

ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_status_check
  CHECK (status IN ('inbox', 'archived', 'trashed', 'someday'));
