-- Task schedule: daily recurrence and one-off due dates
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS is_daily BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_until DATE,
  ADD COLUMN IF NOT EXISTS last_daily_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS due_date DATE;
