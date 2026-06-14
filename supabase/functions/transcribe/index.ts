import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  checkRateLimit,
  createAdminClient,
  rateLimitConfigFor,
} from "../_shared/rate_limit.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_AUDIO_BYTES = Number(
  Deno.env.get("AI_TRANSCRIBE_MAX_AUDIO_BYTES") ?? String(10 * 1024 * 1024),
);

type STTProvider = {
  transcribe(audio: Uint8Array, mime: string): Promise<string>;
};

function createSTTProvider(): STTProvider {
  const provider = (Deno.env.get("STT_PROVIDER") ?? "groq").toLowerCase();

  if (provider === "openai") {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) throw new Error("OPENAI_API_KEY is not set");
    return {
      async transcribe(audio, mime) {
        return whisperTranscribe(
          "https://api.openai.com/v1/audio/transcriptions",
          apiKey,
          audio,
          mime,
        );
      },
    };
  }

  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (!groqKey) {
    throw new Error("GROQ_API_KEY is not set (default STT provider is groq)");
  }
  return {
    async transcribe(audio, mime) {
      return whisperTranscribe(
        "https://api.groq.com/openai/v1/audio/transcriptions",
        groqKey,
        audio,
        mime,
        Deno.env.get("GROQ_WHISPER_MODEL") ?? "whisper-large-v3",
      );
    },
  };
}

async function whisperTranscribe(
  endpoint: string,
  apiKey: string,
  audio: Uint8Array,
  mime: string,
  model = "whisper-large-v3",
): Promise<string> {
  const ext = mime.includes("mp4") || mime.includes("m4a")
    ? "m4a"
    : mime.includes("mpeg")
    ? "mp3"
    : mime.includes("wav")
    ? "wav"
    : "m4a";

  const form = new FormData();
  form.append(
    "file",
    new Blob([audio], { type: mime || "audio/mp4" }),
    `audio.${ext}`,
  );
  form.append("model", model);
  form.append("language", "zh");

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: form,
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`STT HTTP ${response.status}: ${detail}`);
  }

  const json = await response.json();
  const text = (json.text as string | undefined)?.trim() ?? "";
  if (!text) throw new Error("STT returned empty text");
  return text;
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

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonError("Unauthorized", 401);
    }

    const body = await req.json();
    const taskId = body.taskId as string | undefined;
    const storagePath = body.storagePath as string | undefined;
    if (!taskId || !storagePath) {
      return jsonError("taskId and storagePath are required", 400);
    }

    if (!storagePath.startsWith(`${user.id}/`)) {
      return jsonError("Forbidden storage path", 403);
    }

    const { data: task, error: taskError } = await adminClient
      .from("tasks")
      .select("id, user_id, title, transcription_status")
      .eq("id", taskId)
      .maybeSingle();

    if (taskError || !task) {
      return jsonError("Task not found", 404);
    }
    if (task.user_id !== user.id) {
      return jsonError("Forbidden", 403);
    }
    if (
      task.transcription_status !== "pending" &&
      task.transcription_status !== "failed"
    ) {
      return jsonResponse({
        taskId,
        title: task.title ?? "",
        transcription_status: task.transcription_status ?? "none",
      });
    }

    const { data: fileData, error: downloadError } = await adminClient.storage
      .from("attachments")
      .download(storagePath);

    if (downloadError || !fileData) {
      await markFailed(adminClient, taskId);
      return jsonError("Audio download failed", 400);
    }

    const audioBytes = new Uint8Array(await fileData.arrayBuffer());
    const mime = fileData.type || "audio/mp4";

    if (audioBytes.length > MAX_AUDIO_BYTES) {
      await markFailed(adminClient, taskId);
      return jsonError("Audio file too large", 400);
    }

    const adminForRateLimit = createAdminClient();
    const rateLimit = await checkRateLimit(
      adminForRateLimit,
      user.id,
      "transcribe",
      rateLimitConfigFor("transcribe"),
    );
    if (!rateLimit.ok) {
      return jsonError(rateLimit.message, 429);
    }

    let title: string;
    try {
      const stt = createSTTProvider();
      title = await stt.transcribe(audioBytes, mime);
    } catch (e) {
      console.error("STT failed:", e);
      await markFailed(adminClient, taskId);
      return jsonResponse({
        taskId,
        transcription_status: "failed",
        title: task.title ?? "",
      });
    }

    const { error: updateError } = await adminClient
      .from("tasks")
      .update({
        title,
        transcription_status: "done",
        updated_at: new Date().toISOString(),
      })
      .eq("id", taskId);

    if (updateError) {
      console.error("Task update failed:", updateError);
      return jsonError("Task update failed", 500);
    }

    return jsonResponse({
      taskId,
      title,
      transcription_status: "done",
    });
  } catch (e) {
    console.error("transcribe error:", e);
    return jsonError(e instanceof Error ? e.message : "Internal error", 500);
  }
});

async function markFailed(
  client: ReturnType<typeof createClient>,
  taskId: string,
) {
  await client
    .from("tasks")
    .update({
      transcription_status: "failed",
      updated_at: new Date().toISOString(),
    })
    .eq("id", taskId);
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return jsonResponse({ error: message }, status);
}
