import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type TaskSummary = { id: string; title: string; status: string };

type LLMProvider = {
  recommend(query: string, tasks: TaskSummary[]): Promise<{
    recommendedIds: string[];
    playlistName: string;
    summary?: string;
  }>;
};

function createLLMProvider(): LLMProvider {
  const provider = (Deno.env.get("LLM_PROVIDER") ?? "groq").toLowerCase();

  if (provider === "openai") {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) throw new Error("OPENAI_API_KEY is not set");
    const model = Deno.env.get("OPENAI_CHAT_MODEL") ?? "gpt-4o-mini";
    return {
      async recommend(query, tasks) {
        return chatRecommend(
          "https://api.openai.com/v1/chat/completions",
          apiKey,
          model,
          query,
          tasks,
        );
      },
    };
  }

  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (!groqKey) {
    throw new Error("GROQ_API_KEY is not set (default LLM provider is groq)");
  }
  const model = Deno.env.get("GROQ_CHAT_MODEL") ?? "llama-3.3-70b-versatile";
  return {
    async recommend(query, tasks) {
      return chatRecommend(
        "https://api.groq.com/openai/v1/chat/completions",
        groqKey,
        model,
        query,
        tasks,
      );
    },
  };
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
    const tasks = body.tasks as TaskSummary[] | undefined;

    if (!query?.trim()) {
      return jsonError("query is required", 400);
    }
    if (!Array.isArray(tasks)) {
      return jsonError("tasks array is required", 400);
    }

    const sanitized: TaskSummary[] = tasks
      .filter((t) => t?.id && t?.title)
      .map((t) => ({
        id: String(t.id),
        title: String(t.title).slice(0, 500),
        status: String(t.status ?? "inbox"),
      }))
      .slice(0, 200);

    const llm = createLLMProvider();
    const result = await llm.recommend(query.trim(), sanitized);

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
