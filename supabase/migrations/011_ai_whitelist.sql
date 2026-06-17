-- Email whitelist: bypass AI rate limits and attachment count (client-side)

CREATE TABLE IF NOT EXISTS public.ai_email_whitelist (
  email TEXT PRIMARY KEY CHECK (email = lower(email)),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_email_whitelist ENABLE ROW LEVEL SECURITY;

-- Users may only read their own whitelist entry (for client entitlement check).
DROP POLICY IF EXISTS ai_email_whitelist_select_own ON public.ai_email_whitelist;
CREATE POLICY ai_email_whitelist_select_own ON public.ai_email_whitelist
  FOR SELECT USING (email = lower(auth.jwt()->>'email'));

-- Inserts/updates/deletes: Dashboard / service role only (no user-facing policies).
