-- Task recurrence: monthly and yearly in addition to daily
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS recurrence_type TEXT NOT NULL DEFAULT 'none';

ALTER TABLE public.task_templates
  ADD COLUMN IF NOT EXISTS recurrence_type TEXT NOT NULL DEFAULT 'none';

-- Backfill existing daily tasks
UPDATE public.tasks
  SET recurrence_type = 'daily'
  WHERE is_daily = true AND recurrence_type = 'none';

UPDATE public.task_templates
  SET recurrence_type = 'daily'
  WHERE is_daily = true AND recurrence_type = 'none';
