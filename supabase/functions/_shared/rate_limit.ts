import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type AiAction = "recommend" | "transcribe";

export type RateLimitConfig = {
  perMinute: number;
  perDay: number;
  minuteMessage?: string;
  dayMessage?: string;
};

export type RateLimitResult =
  | { ok: true }
  | { ok: false; message: string };

const DEFAULT_MESSAGES: Record<
  AiAction,
  { minute: string; day: string }
> = {
  recommend: {
    minute: "操作太频繁，请稍后再试",
    day: "今日 AI 推荐次数已用完，明天再试",
  },
  transcribe: {
    minute: "操作太频繁，请稍后再试",
    day: "今日语音转写次数已用完，明天再试",
  },
};

export function createAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set");
  }
  return createClient(supabaseUrl, serviceRoleKey);
}

export async function checkRateLimit(
  adminClient: SupabaseClient,
  userId: string,
  action: AiAction,
  config: RateLimitConfig,
): Promise<RateLimitResult> {
  const now = Date.now();
  const minuteAgo = new Date(now - 60_000).toISOString();
  const dayAgo = new Date(now - 86_400_000).toISOString();

  const { count: minuteCount, error: minuteError } = await adminClient
    .from("ai_usage_log")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action", action)
    .gte("created_at", minuteAgo);

  if (minuteError) {
    console.error("rate_limit minute count error:", minuteError);
    throw new Error("Rate limit check failed");
  }

  if ((minuteCount ?? 0) >= config.perMinute) {
    return {
      ok: false,
      message: config.minuteMessage ?? DEFAULT_MESSAGES[action].minute,
    };
  }

  const { count: dayCount, error: dayError } = await adminClient
    .from("ai_usage_log")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("action", action)
    .gte("created_at", dayAgo);

  if (dayError) {
    console.error("rate_limit day count error:", dayError);
    throw new Error("Rate limit check failed");
  }

  if ((dayCount ?? 0) >= config.perDay) {
    return {
      ok: false,
      message: config.dayMessage ?? DEFAULT_MESSAGES[action].day,
    };
  }

  const { error: insertError } = await adminClient.from("ai_usage_log").insert({
    user_id: userId,
    action,
  });

  if (insertError) {
    console.error("rate_limit insert error:", insertError);
    throw new Error("Rate limit log failed");
  }

  return { ok: true };
}

export function rateLimitConfigFor(action: AiAction): RateLimitConfig {
  if (action === "recommend") {
    return {
      perMinute: Number(Deno.env.get("AI_RECOMMEND_PER_MINUTE") ?? "3"),
      perDay: Number(Deno.env.get("AI_RECOMMEND_PER_DAY") ?? "30"),
    };
  }
  return {
    perMinute: Number(Deno.env.get("AI_TRANSCRIBE_PER_MINUTE") ?? "2"),
    perDay: Number(Deno.env.get("AI_TRANSCRIBE_PER_DAY") ?? "20"),
  };
}
