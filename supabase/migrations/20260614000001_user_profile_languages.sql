-- Extend user_profiles for onboarding persistence (languages, location, availability)
-- Safe to run on a fresh Supabase project OR after 20260613000001_user_profiles.sql

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

alter table public.user_profiles
  add column if not exists languages text[] default '{English}',
  add column if not exists location text not null default '',
  add column if not exists availability text not null default '';

alter table public.user_profiles enable row level security;

drop policy if exists "own_user_profiles" on public.user_profiles;
create policy "own_user_profiles" on public.user_profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
