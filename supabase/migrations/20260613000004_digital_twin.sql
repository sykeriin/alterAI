-- ALTER Life OS Digital Twin consent map.
-- Stores the user's chosen source scope and autonomy ring.

create table if not exists public.digital_twin_sources (
  user_id uuid not null references auth.users (id) on delete cascade,
  source_key text not null,
  access_level text not null default 'off', -- off | metadata | redacted | local_full
  connected boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, source_key)
);

create table if not exists public.digital_twin_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  autonomy_level text not null default 'recommend', -- observe | recommend | draft | confirm_act
  updated_at timestamptz not null default now()
);

alter table public.digital_twin_sources enable row level security;
alter table public.digital_twin_settings enable row level security;

drop policy if exists "digital_twin_sources_owner_all" on public.digital_twin_sources;
create policy "digital_twin_sources_owner_all"
  on public.digital_twin_sources
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "digital_twin_settings_owner_all" on public.digital_twin_settings;
create policy "digital_twin_settings_owner_all"
  on public.digital_twin_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_digital_twin_sources_user
  on public.digital_twin_sources (user_id, updated_at desc);
