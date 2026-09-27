import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return jsonResponse({ error: message }, status);
}

async function generateToken(): Promise<{ token: string; hash: string; prefix: string }> {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  const token = `todo_mcp_${hex}`;
  const hash = await hashToken(token);
  const prefix = token.slice(0, 16);
  return { token, hash, prefix };
}

async function hashToken(token: string): Promise<string> {
  const data = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Missing Authorization", 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 验证用户 JWT
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonError("Unauthorized", 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const body = await req.json().catch(() => ({}));
    const action = body.action;

    // ---- 生成 Token ----
    if (action === "create") {
      const name = String(body.name ?? "default").trim().slice(0, 100) || "default";

      // 限制每个用户最多 10 个未吊销 token
      const { count } = await adminClient
        .from("mcp_tokens")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .is("revoked_at", null);
      if ((count ?? 0) >= 10) {
        return jsonError("最多同时存在 10 个有效 token，请先吊销旧的", 400);
      }

      const { token, hash, prefix } = await generateToken();

      const { data, error } = await adminClient
        .from("mcp_tokens")
        .insert({
          user_id: user.id,
          name,
          token_hash: hash,
          token_prefix: prefix,
        })
        .select("id, name, token_prefix, created_at")
        .single();

      if (error) {
        console.error("mcp-tokens create error:", error);
        return jsonError("Failed to create token", 500);
      }

      // 明文 token 只返回一次
      return jsonResponse({ ...data, token });
    }

    // ---- 列出 Token ----
    if (action === "list") {
      const { data, error } = await adminClient
        .from("mcp_tokens")
        .select("id, name, token_prefix, last_used_at, created_at, revoked_at")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });

      if (error) {
        console.error("mcp-tokens list error:", error);
        return jsonError("Failed to list tokens", 500);
      }
      return jsonResponse({ tokens: data ?? [] });
    }

    // ---- 吊销 Token ----
    if (action === "revoke") {
      const tokenId = String(body.token_id ?? "").trim();
      if (!tokenId) {
        return jsonError("token_id is required", 400);
      }

      const { data, error } = await adminClient
        .from("mcp_tokens")
        .update({ revoked_at: new Date().toISOString() })
        .eq("id", tokenId)
        .eq("user_id", user.id)
        .select("id, name, revoked_at")
        .maybeSingle();

      if (error) {
        console.error("mcp-tokens revoke error:", error);
        return jsonError("Failed to revoke token", 500);
      }
      if (!data) {
        return jsonError("Token not found", 404);
      }
      return jsonResponse(data);
    }

    return jsonError("Invalid action. Use create / list / revoke", 400);
  } catch (e) {
    console.error("mcp-tokens error:", e);
    return jsonError(e instanceof Error ? e.message : "Internal error", 500);
  }
});
