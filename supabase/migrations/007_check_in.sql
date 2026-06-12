-- Task check-in: repeat N times before completion
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS check_in_target INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS check_in_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_check_in_at DATE;

ALTER TABLE public.task_templates
  ADD COLUMN IF NOT EXISTS check_in_target INT NOT NULL DEFAULT 1;
