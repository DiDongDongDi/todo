import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient } from "../_shared/rate_limit.ts";

const RETENTION_DAYS = Number(Deno.env.get("AI_USAGE_LOG_RETENTION_DAYS") ?? "7");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok");
  }

  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret) {
    const provided = req.headers.get("x-cron-secret");
    if (provided !== cronSecret) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
  }

  try {
    const adminClient = createAdminClient();
    const cutoff = new Date(Date.now() - RETENTION_DAYS * 86_400_000)
      .toISOString();

    const { error, count } = await adminClient
      .from("ai_usage_log")
      .delete({ count: "exact" })
      .lt("created_at", cutoff);

    if (error) {
      console.error("cleanup-ai-usage error:", error);
      return jsonResponse({ error: error.message }, 500);
    }

    console.log(`cleanup-ai-usage: deleted ${count ?? 0} rows before ${cutoff}`);
    return jsonResponse({ deleted: count ?? 0, cutoff });
  } catch (e) {
    console.error("cleanup-ai-usage error:", e);
    return jsonResponse(
      { error: e instanceof Error ? e.message : "Internal error" },
      500,
    );
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
