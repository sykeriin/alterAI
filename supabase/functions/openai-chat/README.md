# openai-chat — secure OpenAI proxy

The Flutter client never holds the OpenAI key and never calls OpenAI directly.
It calls this Edge Function with the user's Supabase JWT; the function holds the
platform key as a secret, meters per-user usage, and proxies the request.

## One-time setup

1. **Install the Supabase CLI** (if you don't have it):
   ```
   npm install -g supabase
   ```

2. **Link your project:**
   ```
   supabase link --project-ref YOUR_PROJECT_REF
   ```

3. **Apply the migrations** (creates `ai_usage` + the `increment_ai_usage` RPC):
   ```
   supabase db push
   ```
   Or paste `supabase/migrations/20260613000002_ai_usage.sql` into the SQL editor.

4. **Set the platform OpenAI key as a secret:**
   ```
   supabase secrets set OPENAI_API_KEY=sk-your-real-key
   ```
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
   injected automatically by the platform — you do **not** set those.

5. **Deploy the function:**
   ```
   supabase functions deploy openai-chat
   ```

That's it. Every authenticated user now gets AI with a fair-use daily cap
(`DAILY_REQUEST_LIMIT`, default 200/day). Users who paste their own key in
Settings bypass the cap and bill their own OpenAI account.

## Tuning

- `DAILY_REQUEST_LIMIT` in `index.ts` — platform-key requests per user per day.
- `ALLOWED_MODELS` — which models the client may request (defaults to `gpt-4o-mini`).

## Security notes

- The platform key lives only in Supabase secrets — never in the repo, the DB,
  or the client bundle.
- JWT is verified on every call; `ai_usage` writes go through the service role
  inside the function, so users can read their own usage but never forge it.
