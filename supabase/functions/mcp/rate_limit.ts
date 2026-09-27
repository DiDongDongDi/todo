import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const PER_MINUTE = Number(Deno.env.get("MCP_RATE_LIMIT_PER_MINUTE") ?? "60");
const PER_DAY = Number(Deno.env.get("MCP_RATE_LIMIT_PER_DAY") ?? "1000");

export type RateLimitResult =
  | { ok: true }
  | { ok: false; message: string };

export async function checkMcpRateLimit(
  adminClient: SupabaseClient,
  tokenId: string,
): Promise<RateLimitResult> {
  const now = Date.now();
  const minuteAgo = new Date(now - 60_000).toISOString();
  const dayAgo = new Date(now - 86_400_000).toISOString();

  const { count: minuteCount, error: minuteError } = await adminClient
    .from("mcp_usage_log")
    .select("id", { count: "exact", head: true })
    .eq("token_id", tokenId)
    .gte("created_at", minuteAgo);

  if (minuteError) {
    console.error("mcp rate limit minute check error:", minuteError);
    throw new Error("Rate limit check failed");
  }
  if ((minuteCount ?? 0) >= PER_MINUTE) {
    return { ok: false, message: "MCP 调用过于频繁，请稍后再试" };
  }

  const { count: dayCount, error: dayError } = await adminClient
    .from("mcp_usage_log")
    .select("id", { count: "exact", head: true })
    .eq("token_id", tokenId)
    .gte("created_at", dayAgo);

  if (dayError) {
    console.error("mcp rate limit day check error:", dayError);
    throw new Error("Rate limit check failed");
  }
  if ((dayCount ?? 0) >= PER_DAY) {
    return { ok: false, message: "今日 MCP 调用次数已用完" };
  }

  return { ok: true };
}

export async function logMcpUsage(
  adminClient: SupabaseClient,
  tokenId: string,
  userId: string,
  toolName: string,
): Promise<void> {
  const { error } = await adminClient.from("mcp_usage_log").insert({
    token_id: tokenId,
    user_id: userId,
    tool_name: toolName,
  });
  if (error) {
    console.error("mcp usage log error:", error);
  }
}
