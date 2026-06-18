// ALTER — LLM proxy Edge Function (Groq for chat/tools, OpenAI for embeddings).
//
// The Flutter client NEVER holds a provider key. It calls this function with its
// Supabase JWT; the function authenticates the user, enforces a per-user daily
// quota, and proxies chat + agent tool-calling to Groq (OpenAI-compatible) using
// the server-held GROQ_API_KEY secret.
//
// Embeddings: Groq has no embeddings endpoint, so the embed branch uses
// OPENAI_API_KEY if it is configured; otherwise it returns an empty result and
// callers fall back to keyword search (never an error).
//
// Optional BYOK: if the client sends `byok_key` (an OpenAI key), chat and
// embeddings go to OpenAI directly with that key and quota is not consumed.
//
// Deploy:
//   supabase secrets set GROQ_API_KEY=gsk_...
//   supabase functions deploy openai-chat
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const EMBED_URL = 'https://api.openai.com/v1/embeddings';
const EMBED_MODEL = 'text-embedding-3-small';
const DAILY_REQUEST_LIMIT = 100000; // effectively unlimited (demo); raise/lower as needed

// Default Groq model for the platform key (tool-calling capable). Override with
// the GROQ_MODEL secret without redeploying code.
const DEFAULT_GROQ_MODEL = 'llama-3.3-70b-versatile';

// BYOK (a user's own OpenAI key) allowed chat models.
const ALLOWED_OPENAI_MODELS = new Set([
  'gpt-4o-mini',
  'gpt-4o',
  'gpt-4.1-mini',
  'gpt-4.1',
]);

interface ChatRequest {
  messages?: Array<Record<string, unknown>>;
  model?: string;
  temperature?: number;
  max_tokens?: number;
  json_mode?: boolean;
  byok_key?: string;
  tools?: unknown;
  tool_choice?: unknown;
  // Semantic memory: when present, return one embedding vector per string.
  embed?: string[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function callChat(
  url: string,
  apiKey: string,
  payload: unknown,
): Promise<Response> {
  // One retry on transient errors (429 / 5xx) with a short backoff.
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });
    if (res.status !== 429 && res.status < 500) return res;
    if (attempt === 0) await new Promise((r) => setTimeout(r, 600));
    else return res;
  }
  // Unreachable, but satisfies the type checker.
  return new Response(null, { status: 500 });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  // --- Authenticate the user from their JWT ---
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing authorization header' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();
  if (authError || !user) {
    return json({ error: 'Invalid or expired session' }, 401);
  }

  // --- Parse and validate the request ---
  let body: ChatRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid JSON body' }, 400);
  }
  // Only treat a provided key as a real BYOK key if it looks like an OpenAI key
  // (sk-...). This guards against a non-OpenAI token (e.g. a HuggingFace hf_
  // token) pasted into the key field: forwarding that to OpenAI just gets it
  // rejected. Anything that isn't an sk- key falls through to the platform
  // (Groq) path instead.
  const byokRaw = (body.byok_key ?? '').trim();
  const byok = byokRaw.startsWith('sk-') ? byokRaw : '';
  const usingPlatformKey = byok.length === 0;

  // --- Per-user daily quota (only for the platform key) ---
  const admin = createClient(supabaseUrl, serviceKey);
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  if (usingPlatformKey) {
    const { data: usage } = await admin
      .from('ai_usage')
      .select('request_count')
      .eq('user_id', user.id)
      .eq('day', today)
      .maybeSingle();

    const used = usage?.request_count ?? 0;
    if (used >= DAILY_REQUEST_LIMIT) {
      return json(
        {
          error:
            'Daily AI limit reached. Add your own key in Settings to continue without limits.',
        },
        429,
      );
    }
  }

  // --- Embeddings branch (semantic memory): one vector per input string. ---
  // Groq has no embeddings API, so this needs an OpenAI key (platform or BYOK).
  // If none is configured, return empty so callers fall back to keyword search.
  if (Array.isArray(body.embed) && body.embed.length > 0) {
    const embedKey = usingPlatformKey
      ? (Deno.env.get('OPENAI_API_KEY') ?? '')
      : byok;
    if (!embedKey) return json({ embeddings: [] });

    const inputs = body.embed.slice(0, 96).map((s) => String(s).slice(0, 8000));
    const res = await fetch(EMBED_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${embedKey}`,
      },
      body: JSON.stringify({ model: EMBED_MODEL, input: inputs }),
    });
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      // Degrade gracefully rather than breaking memory.
      return json({ embeddings: [] });
    }
    const embeddings = (data?.data ?? []).map(
      (d: { embedding: number[] }) => d.embedding,
    );
    if (usingPlatformKey) {
      await admin.rpc('increment_ai_usage', {
        p_user_id: user.id,
        p_day: today,
        p_tokens: data?.usage?.total_tokens ?? 0,
      });
    }
    return json({ embeddings });
  }

  // --- Chat / tool-calling branch ---
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return json({ error: 'messages is required' }, 400);
  }

  // Platform key -> Groq. BYOK -> the user's own OpenAI key.
  let chatUrl: string;
  let apiKey: string;
  let model: string;
  if (usingPlatformKey) {
    chatUrl = GROQ_URL;
    apiKey = Deno.env.get('GROQ_API_KEY') ?? '';
    model = Deno.env.get('GROQ_MODEL') ?? DEFAULT_GROQ_MODEL;
  } else {
    chatUrl = OPENAI_URL;
    apiKey = byok;
    model = ALLOWED_OPENAI_MODELS.has(body.model ?? '')
      ? body.model!
      : 'gpt-4o-mini';
  }
  if (!apiKey) {
    return json({ error: 'AI service is not configured.' }, 503);
  }

  const payload: Record<string, unknown> = {
    model,
    messages: body.messages,
    temperature: body.temperature ?? 0.7,
    max_tokens: body.max_tokens ?? 1200,
  };
  if (body.json_mode) {
    payload.response_format = { type: 'json_object' };
  }
  // Agent function-calling: pass tools/tool_choice straight through (Groq is
  // OpenAI-compatible and returns choices[0].message.tool_calls).
  if (body.tools) {
    payload.tools = body.tools;
    if (body.tool_choice) payload.tool_choice = body.tool_choice;
  }

  let chatRes = await callChat(chatUrl, apiKey, payload);
  let resBody = await chatRes.json().catch(() => null);

  // Groq sometimes 400s on its OWN malformed or hallucinated tool calls
  // ("failed_generation", or 'tool "x" was not in request.tools'). Rather than
  // surface a scary error, retry once as a plain completion (no tools) so the
  // user still gets a natural-language answer.
  if (!chatRes.ok && payload.tools) {
    const retry: Record<string, unknown> = { ...payload };
    delete retry.tools;
    delete retry.tool_choice;
    chatRes = await callChat(chatUrl, apiKey, retry);
    resBody = await chatRes.json().catch(() => null);
  }

  if (!chatRes.ok) {
    const msg =
      resBody?.error?.message ?? `AI request failed (${chatRes.status})`;
    return json({ error: msg }, chatRes.status === 401 ? 502 : chatRes.status);
  }

  const message = resBody?.choices?.[0]?.message ?? {};
  const content: string = message?.content ?? '';
  const toolCalls = message?.tool_calls ?? null;
  const finishReason: string = resBody?.choices?.[0]?.finish_reason ?? '';
  const totalTokens: number = resBody?.usage?.total_tokens ?? 0;

  // --- Record usage (fire-and-forget, platform key only) ---
  if (usingPlatformKey) {
    await admin.rpc('increment_ai_usage', {
      p_user_id: user.id,
      p_day: today,
      p_tokens: totalTokens,
    });
  }

  return json({
    content,
    tool_calls: toolCalls,
    finish_reason: finishReason,
    model,
    tokens: totalTokens,
  });
});
