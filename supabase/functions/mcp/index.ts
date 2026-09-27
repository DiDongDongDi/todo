import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { authenticateMcpToken, createAdminClient } from "./auth.ts";
import { checkMcpRateLimit, logMcpUsage } from "./rate_limit.ts";
import { handleTool, MCP_TOOLS } from "./tools.ts";

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

function jsonRpcResult(id: unknown, result: unknown) {
  return jsonResponse({ jsonrpc: "2.0", id, result });
}

function jsonRpcError(id: unknown, code: number, message: string) {
  return jsonResponse({ jsonrpc: "2.0", id, error: { code, message } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createAdminClient();
    const auth = await authenticateMcpToken(req, adminClient);
    if (!auth) {
      return jsonError("Unauthorized: invalid or revoked MCP token", 401);
    }

    const rateLimit = await checkMcpRateLimit(adminClient, auth.tokenId);
    if (!rateLimit.ok) {
      return jsonError(rateLimit.message, 429);
    }

    const body = await req.json().catch(() => ({}));
    const { id, method, params } = body;

    // MCP initialize handshake
    if (method === "initialize") {
      return jsonRpcResult(id, {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "todo-mcp", version: "1.0.0" },
      });
    }

    // MCP tools/list
    if (method === "tools/list") {
      return jsonRpcResult(id, { tools: MCP_TOOLS });
    }

    // MCP tools/call
    if (method === "tools/call") {
      const toolName = params?.name;
      const toolArgs = params?.arguments ?? {};

      if (!toolName || typeof toolName !== "string") {
        return jsonRpcError(id, -32602, "Invalid params: name is required");
      }

      await logMcpUsage(adminClient, auth.tokenId, auth.userId, toolName);

      try {
        const result = await handleTool(adminClient, auth.userId, toolName, toolArgs);
        return jsonRpcResult(id, {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        });
      } catch (toolError) {
        const message = toolError instanceof Error ? toolError.message : "Tool execution failed";
        return jsonRpcError(id, -32603, message);
      }
    }

    return jsonRpcError(id ?? null, -32601, "Method not found");
  } catch (e) {
    console.error("mcp function error:", e);
    return jsonError(e instanceof Error ? e.message : "Internal error", 500);
  }
});
