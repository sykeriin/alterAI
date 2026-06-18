-- Structured memory store for ALTER memory lifecycle (Stage 2)

create table if not exists public.memories (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete cascade not null,
  kind            text not null default 'observation',
  title           text not null default '',
  content         text not null default '',
  provenance      text not null default '',
  confidence      real not null default 0.5 check (confidence between 0 and 1),
  sensitivity     text not null default 'normal',
  retention       text not null default 'ephemeral',
  expires_at      timestamptz,
  source_ids      text[] default '{}',
  confirmed       boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists memories_user_id_idx on public.memories(user_id);
create index if not exists memories_expires_at_idx on public.memories(expires_at);

alter table public.memories enable row level security;

drop policy if exists "memories_owner_all" on public.memories;
create policy "memories_owner_all" on public.memories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Identity traits derived from confirmed memories (Stage 4)
create table if not exists public.identity_traits (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete cascade not null,
  dimension       text not null,
  value           text not null default '',
  confidence      real not null default 0.5 check (confidence between 0 and 1),
  source_memory_ids uuid[] default '{}',
  updated_at      timestamptz not null default now(),
  unique (user_id, dimension)
);

alter table public.identity_traits enable row level security;

drop policy if exists "identity_traits_owner_all" on public.identity_traits;
create policy "identity_traits_owner_all" on public.identity_traits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
