-- Per-user daily AI usage tracking, used by the openai-chat Edge Function
-- to enforce a fair-use quota on the platform OpenAI key.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  request_count integer not null default 0,
  token_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.ai_usage enable row level security;

-- Users may read their own usage (for showing remaining quota in the UI).
-- Writes happen exclusively via the Edge Function using the service role,
-- which bypasses RLS — so no insert/update policy is granted to users.
drop policy if exists "ai_usage_select_own" on public.ai_usage;
create policy "ai_usage_select_own"
  on public.ai_usage
  for select
  using (auth.uid() = user_id);

-- Atomic upsert + increment so concurrent requests can't race the counter.
create or replace function public.increment_ai_usage(
  p_user_id uuid,
  p_day date,
  p_tokens integer
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.ai_usage (user_id, day, request_count, token_count, updated_at)
  values (p_user_id, p_day, 1, coalesce(p_tokens, 0), now())
  on conflict (user_id, day)
  do update set
    request_count = public.ai_usage.request_count + 1,
    token_count = public.ai_usage.token_count + coalesce(p_tokens, 0),
    updated_at = now();
$$;
