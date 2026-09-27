-- MCP server 长期 API Token 与调用日志
-- Token 明文形如 todo_mcp_<48 hex>，仅生成时返回一次；库中只存 SHA-256 哈希。

CREATE TABLE IF NOT EXISTS public.mcp_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  token_hash TEXT NOT NULL UNIQUE,
  token_prefix TEXT NOT NULL,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS mcp_tokens_user_idx ON public.mcp_tokens (user_id);

ALTER TABLE public.mcp_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mcp_tokens_select_own ON public.mcp_tokens;
CREATE POLICY mcp_tokens_select_own ON public.mcp_tokens
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS mcp_tokens_insert_own ON public.mcp_tokens;
CREATE POLICY mcp_tokens_insert_own ON public.mcp_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS mcp_tokens_update_own ON public.mcp_tokens;
CREATE POLICY mcp_tokens_update_own ON public.mcp_tokens
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS mcp_tokens_delete_own ON public.mcp_tokens;
CREATE POLICY mcp_tokens_delete_own ON public.mcp_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- MCP 调用日志（按 token 限流与审计）
CREATE TABLE IF NOT EXISTS public.mcp_usage_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_id UUID NOT NULL REFERENCES public.mcp_tokens(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tool_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mcp_usage_log_token_created_idx
  ON public.mcp_usage_log (token_id, created_at DESC);

ALTER TABLE public.mcp_usage_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mcp_usage_log_select_own ON public.mcp_usage_log;
CREATE POLICY mcp_usage_log_select_own ON public.mcp_usage_log
  FOR SELECT USING (auth.uid() = user_id);
