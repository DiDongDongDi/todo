-- task_playlists: user-created task lists referencing inbox/someday tasks
CREATE TABLE IF NOT EXISTS public.task_playlists (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  task_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  source_query TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sync_version INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS task_playlists_user_updated_idx
  ON public.task_playlists (user_id, updated_at DESC);

ALTER TABLE public.task_playlists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS task_playlists_select_own ON public.task_playlists;
CREATE POLICY task_playlists_select_own ON public.task_playlists
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS task_playlists_insert_own ON public.task_playlists;
CREATE POLICY task_playlists_insert_own ON public.task_playlists
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS task_playlists_update_own ON public.task_playlists;
CREATE POLICY task_playlists_update_own ON public.task_playlists
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS task_playlists_delete_own ON public.task_playlists;
CREATE POLICY task_playlists_delete_own ON public.task_playlists
  FOR DELETE USING (auth.uid() = user_id);
