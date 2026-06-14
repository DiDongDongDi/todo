-- Resource abuse protection: AI usage logging + task count cap

CREATE TABLE IF NOT EXISTS public.ai_usage_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('recommend', 'transcribe')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_usage_log_user_action_time_idx
  ON public.ai_usage_log (user_id, action, created_at DESC);

ALTER TABLE public.ai_usage_log ENABLE ROW LEVEL SECURITY;
-- No user-facing policies: only service role / Edge Functions write and read.

CREATE OR REPLACE FUNCTION public.enforce_task_limit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE cnt INT;
BEGIN
  SELECT COUNT(*) INTO cnt FROM public.tasks
    WHERE user_id = NEW.user_id AND deleted_at IS NULL;
  IF cnt >= 5000 THEN
    RAISE EXCEPTION 'task_limit_exceeded' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_limit_before_insert ON public.tasks;
CREATE TRIGGER tasks_limit_before_insert
  BEFORE INSERT ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.enforce_task_limit();
