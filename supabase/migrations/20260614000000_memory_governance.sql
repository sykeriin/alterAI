-- User-visible controls for ALTER's local-first memory lifecycle.

create table if not exists public.memory_governance_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  default_retention text not null default 'ephemeral',
  durable_requires_confirmation boolean not null default true,
  sensitive_requires_confirmation boolean not null default true,
  restricted_storage_allowed boolean not null default false,
  portable_export_enabled boolean not null default true,
  max_retrieval_chars integer not null default 6000 check (max_retrieval_chars between 500 and 30000),
  updated_at timestamptz not null default now()
);

alter table public.memory_governance_settings enable row level security;

drop policy if exists "memory_governance_settings_owner_all"
  on public.memory_governance_settings;
create policy "memory_governance_settings_owner_all"
  on public.memory_governance_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
