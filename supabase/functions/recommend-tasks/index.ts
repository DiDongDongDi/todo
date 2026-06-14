import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  checkRateLimit,
  createAdminClient,
  rateLimitConfigFor,
} from "../_shared/rate_limit.ts";
import {
  selectTasksWithinBudget,
  type TaskSummary,
} from "../_shared/task_budget.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const QUERY_MAX_LENGTH = Number(
  Deno.env.get("AI_RECOMMEND_QUERY_MAX") ?? "500",
);

function createLLMClient(): { endpoint: string; apiKey: string; model: string } {
  const endpoint = Deno.env.get("AI_CHAT_URL")?.trim();
  const apiKey = Deno.env.get("AI_API_KEY")?.trim();
  const model = Deno.env.get("AI_CHAT_MODEL")?.trim();
  if (!endpoint) throw new Error("AI_CHAT_URL is not set");
  if (!apiKey) throw new Error("AI_API_KEY is not set");
  if (!model) throw new Error("AI_CHAT_MODEL is not set");
  return { endpoint, apiKey, model };
}

async function chatRecommend(
  endpoint: string,
  apiKey: string,
  model: string,
  query: string,
  tasks: TaskSummary[],
): Promise<{
  recommendedIds: string[];
  playlistName: string;
  summary?: string;
}> {
  const taskList = tasks
    .map((t) => `- [${t.id}] (${t.status}) ${t.title}`)
    .join("\n");

  const systemPrompt =
    `你是待办任务推荐助手。用户会描述当前想法和需求，以及可选任务列表（含 id、状态和标题）。` +
    `请仅从给定任务 id 中推荐最相关的任务（0-10 个），并生成简洁的中文清单名称。` +
    `必须返回合法 JSON，格式：{"recommendedIds":["id1"],"playlistName":"清单名","summary":"简短说明"}` +
    `不要编造不存在的 id。`;

  const userPrompt =
    `用户需求：${query}\n\n可选任务：\n${taskList || "(无任务)"}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`LLM HTTP ${response.status}: ${detail}`);
  }

  const json = await response.json();
  const content = json.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("LLM returned empty content");
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error("LLM returned invalid JSON");
  }

  const allowed = new Set(tasks.map((t) => t.id));
  const rawIds = parsed.recommendedIds;
  const recommendedIds: string[] = [];
  if (Array.isArray(rawIds)) {
    for (const id of rawIds) {
      const s = String(id);
      if (allowed.has(s) && !recommendedIds.includes(s)) {
        recommendedIds.push(s);
      }
    }
  }

  const playlistName = String(parsed.playlistName ?? "推荐清单").trim() ||
    "推荐清单";
  const summary = parsed.summary != null
    ? String(parsed.summary).trim()
    : undefined;

  return { recommendedIds, playlistName, summary };
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

    const { createClient } = await import("jsr:@supabase/supabase-js@2");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

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

    const body = await req.json();
    const query = body.query as string | undefined;

    if (!query?.trim()) {
      return jsonError("query is required", 400);
    }

    const trimmedQuery = query.trim();
    if (trimmedQuery.length > QUERY_MAX_LENGTH) {
      return jsonError(`query must be at most ${QUERY_MAX_LENGTH} characters`, 400);
    }

    const adminClient = createAdminClient();
    const rateLimit = await checkRateLimit(
      adminClient,
      user.id,
      "recommend",
      rateLimitConfigFor("recommend"),
    );
    if (!rateLimit.ok) {
      return jsonError(rateLimit.message, 429);
    }

    const { data: rawTasks, error: tasksError } = await userClient
      .from("tasks")
      .select("id, title, status")
      .eq("user_id", user.id)
      .in("status", ["inbox", "someday"])
      .is("deleted_at", null)
      .is("parent_id", null)
      .order("updated_at", { ascending: false });

    if (tasksError) {
      console.error("recommend-tasks fetch tasks error:", tasksError);
      return jsonError("Failed to load tasks", 500);
    }

    const allTasks: TaskSummary[] = (rawTasks ?? []).map((t) => ({
      id: String(t.id),
      title: String(t.title ?? ""),
      status: String(t.status ?? "inbox"),
    }));

    const tasks = selectTasksWithinBudget(allTasks);
    if (tasks.length === 0) {
      return jsonError("暂无任务可推荐", 400);
    }

    const { endpoint, apiKey, model } = createLLMClient();
    const result = await chatRecommend(
      endpoint,
      apiKey,
      model,
      trimmedQuery,
      tasks,
    );

    return jsonResponse(result);
  } catch (e) {
    console.error("recommend-tasks error:", e);
    return jsonError(e instanceof Error ? e.message : "Internal error", 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return jsonResponse({ error: message }, status);
}
