-- ALTER schema — run this in the Supabase SQL editor
-- Apply via Supabase SQL editor or `supabase db push` on your linked project.

-- ── Tables ───────────────────────────────────────────────────────────────────

create table if not exists public.assistant_briefs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  greeting    text not null,
  focus       text not null,
  next_action text not null,
  signals     text[] default '{}',
  created_at  timestamptz default now()
);

create table if not exists public.clone_agents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  role        text not null,
  state       text not null,
  confidence  double precision not null,
  accent_hex  text not null,
  summary     text not null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists public.future_scenarios (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  title       text not null,
  horizon     text not null,
  probability double precision not null,
  upside      text not null,
  risk        text not null,
  levers      text[] default '{}',
  created_at  timestamptz default now()
);

create table if not exists public.opportunity_signals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  title       text not null,
  category    text not null,
  score       double precision not null,
  source      text not null,
  time_window text not null,
  evidence    text not null,
  created_at  timestamptz default now()
);

create table if not exists public.social_contacts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  context     text not null,
  strength    double precision not null,
  tags        text[] default '{}',
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists public.reputation_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  title       text not null,
  delta       integer not null,
  description text not null,
  timestamp   text not null,
  created_at  timestamptz default now()
);

create table if not exists public.lens_insights (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  title       text not null,
  confidence  double precision not null,
  description text not null,
  actions     text[] default '{}',
  created_at  timestamptz default now()
);

-- ── Row Level Security ───────────────────────────────────────────────────────

alter table public.assistant_briefs    enable row level security;
alter table public.clone_agents        enable row level security;
alter table public.future_scenarios    enable row level security;
alter table public.opportunity_signals enable row level security;
alter table public.social_contacts     enable row level security;
alter table public.reputation_events   enable row level security;
alter table public.lens_insights       enable row level security;

-- Users can only see and manage their own data.

drop policy if exists "own_briefs" on public.assistant_briefs;
create policy "own_briefs"   on public.assistant_briefs    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_agents" on public.clone_agents;
create policy "own_agents"   on public.clone_agents        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_scenarios" on public.future_scenarios;
create policy "own_scenarios" on public.future_scenarios   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_signals" on public.opportunity_signals;
create policy "own_signals"  on public.opportunity_signals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_contacts" on public.social_contacts;
create policy "own_contacts" on public.social_contacts     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_repevents" on public.reputation_events;
create policy "own_repevents" on public.reputation_events  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own_insights" on public.lens_insights;
create policy "own_insights" on public.lens_insights       for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
