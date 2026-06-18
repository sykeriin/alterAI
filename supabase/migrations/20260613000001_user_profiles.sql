-- User profiles and conversation history
-- Run after 20260613000000_alter_schema.sql

create table if not exists public.user_profiles (
  id              uuid references auth.users(id) on delete cascade primary key,
  display_name    text not null default '',
  role            text not null default '',
  career_stage    text not null default '',
  industry        text not null default '',
  bio             text not null default '',
  skills          text[] default '{}',
  goals           text[] default '{}',
  interests       text[] default '{}',
  openai_key      text not null default '',
  onboarding_done boolean default false,
  languages       text[] default '{English}',
  location        text not null default '',
  availability    text not null default '',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

create table if not exists public.conversations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  role        text not null check (role in ('user', 'assistant')),
  content     text not null,
  intent      text,
  created_at  timestamptz default now()
);

alter table public.user_profiles  enable row level security;
alter table public.conversations   enable row level security;

drop policy if exists "own_user_profiles" on public.user_profiles;
create policy "own_user_profiles" on public.user_profiles  for all using (auth.uid() = id)      with check (auth.uid() = id);
drop policy if exists "own_conversations" on public.conversations;
create policy "own_conversations"  on public.conversations  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
