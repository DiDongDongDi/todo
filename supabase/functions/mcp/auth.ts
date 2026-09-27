import {
  createClient,
  type SupabaseClient,
} from "jsr:@supabase/supabase-js@2";

export const TOKEN_PREFIX = "todo_mcp_";

export type McpAuth = {
  userId: string;
  tokenId: string;
};

export function createAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

export async function hashToken(token: string): Promise<string> {
  const data = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * 验证 MCP 长期 Token，返回用户身份；无效或已吊销返回 null。
 * 同时异步更新 last_used_at。
 */
export async function authenticateMcpToken(
  req: Request,
  adminClient: SupabaseClient,
): Promise<McpAuth | null> {
  const header = req.headers.get("Authorization");
  if (!header || !header.startsWith("Bearer ")) return null;

  const token = header.slice("Bearer ".length).trim();
  if (!token.startsWith(TOKEN_PREFIX)) return null;

  const tokenHash = await hashToken(token);

  const { data, error } = await adminClient
    .from("mcp_tokens")
    .select("id, user_id, revoked_at")
    .eq("token_hash", tokenHash)
    .maybeSingle();

  if (error) {
    console.error("mcp token lookup error:", error);
    return null;
  }
  if (!data || data.revoked_at) return null;

  // 更新 last_used_at，不阻塞响应
  try {
    const updatePromise = adminClient
      .from("mcp_tokens")
      .update({ last_used_at: new Date().toISOString() })
      .eq("id", data.id);
    // @ts-ignore EdgeRuntime 是 Supabase Edge Functions 全局对象
    if (typeof EdgeRuntime !== "undefined" && EdgeRuntime.waitUntil) {
      // @ts-ignore
      EdgeRuntime.waitUntil(updatePromise);
    } else {
      await updatePromise;
    }
  } catch (e) {
    console.error("update last_used_at error:", e);
  }

  return { userId: data.user_id as string, tokenId: data.id as string };
}
