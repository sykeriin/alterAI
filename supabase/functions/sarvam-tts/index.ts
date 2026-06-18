// ALTER — Sarvam AI TTS proxy Edge Function.
//
// Deploy:
//   supabase functions deploy sarvam-tts
//   supabase secrets set SARVAM_API_KEY=...
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const SARVAM_STREAM_URL = 'https://api.sarvam.ai/text-to-speech/stream';

interface TtsRequest {
  text: string;
  target_language_code?: string;
  speaker?: string;
  byok_key?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Missing authorization' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const body = (await req.json()) as TtsRequest;
    const text = body.text?.trim();
    if (!text) return json({ error: 'text is required' }, 400);

    const apiKey = body.byok_key?.trim() || Deno.env.get('SARVAM_API_KEY') || '';
    if (!apiKey) {
      return json({ error: 'SARVAM_API_KEY not configured' }, 503);
    }

    const sarvamRes = await fetch(SARVAM_STREAM_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-subscription-key': apiKey,
      },
      body: JSON.stringify({
        text,
        target_language_code: body.target_language_code ?? 'en-IN',
        speaker: body.speaker ?? 'shubh',
        model: 'bulbul:v3',
        speech_sample_rate: '24000',
        output_audio_codec: 'mp3',
      }),
    });

    if (!sarvamRes.ok) {
      const errText = await sarvamRes.text();
      return json({ error: `Sarvam error: ${errText}` }, sarvamRes.status);
    }

    const audioBytes = new Uint8Array(await sarvamRes.arrayBuffer());
    let binary = '';
    for (let i = 0; i < audioBytes.length; i++) {
      binary += String.fromCharCode(audioBytes[i]);
    }
    const audio_base64 = btoa(binary);

    return json({ audio_base64, content_type: 'audio/mpeg' });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
