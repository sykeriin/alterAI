-- ALTER ContextOS — the decision-loop data model.
-- Sense → Intercept → Understand → Simulate → Decide → Confirm → Act → Learn.
-- Every table is RLS'd to the owning user.

-- A moment captured from a phone surface (share sheet, notification, camera, …).
create table if not exists public.captured_moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source_surface text not null,           -- notification | share_sheet | camera | mic | screenshot | manual | qr | call | install | payment
  source_type text not null default 'text',
  raw_excerpt text not null default '',    -- short, already-redacted excerpt (never store raw secrets)
  redacted_text text not null default '',
  private_mode boolean not null default false,
  created_at timestamptz not null default now()
);

-- The risk verdict + proof for a moment (LifeShield output).
create table if not exists public.risk_analyses (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid references public.captured_moments (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  verdict text not null,                   -- safe | caution | dangerous | needs_verification
  risk_score double precision not null default 0,
  headline text not null default '',
  why_it_matters text not null default '',
  facts jsonb not null default '[]',
  red_flags jsonb not null default '[]',
  assumptions jsonb not null default '[]',
  missing_info jsonb not null default '[]',
  what_could_make_wrong text not null default '',
  verification_steps jsonb not null default '[]',
  confidence double precision not null default 0,
  edge_summary text not null default '',
  cloud_used boolean not null default false,
  created_at timestamptz not null default now()
);

-- A safe action ALTER proposed for a moment.
create table if not exists public.alter_actions (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid references public.captured_moments (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  action_type text not null,               -- draft_reply | reminder | checklist | open_app | call_verified | save_evidence | share_warning | safe_ignore | …
  title text not null,
  detail text not null default '',
  requires_confirmation boolean not null default true,
  irreversible boolean not null default false,
  status text not null default 'proposed', -- proposed | confirmed | executed | dismissed
  created_at timestamptz not null default now()
);

-- Outcome learning after an action (feeds Decision DNA).
create table if not exists public.action_outcomes (
  id uuid primary key default gen_random_uuid(),
  action_id uuid references public.alter_actions (id) on delete cascade,
  moment_id uuid references public.captured_moments (id) on delete set null,
  user_id uuid not null references auth.users (id) on delete cascade,
  outcome text not null,                   -- correct_warning | false_alarm | worked | failed | delayed | regretted | verified_safe | needs_stronger_warning
  note text not null default '',
  created_at timestamptz not null default now()
);

-- Learned decision patterns per user.
create table if not exists public.decision_dna (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  pattern text not null,
  evidence text not null default '',
  weight double precision not null default 0.5,
  updated_at timestamptz not null default now()
);

-- Tamper-evident audit trail of edge/cloud/privacy + action events.
create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  moment_id uuid references public.captured_moments (id) on delete set null,
  kind text not null,                      -- capture | redaction | cloud_escalation | consent | analysis | action_confirm | action_execute | outcome
  detail text not null default '',
  edge_state text not null default 'edge', -- edge | private | cloud
  created_at timestamptz not null default now()
);

-- User-trusted contacts / domains (reduce false alarms).
create table if not exists public.trusted_entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entity_type text not null,               -- contact | domain | app
  value text not null,
  created_at timestamptz not null default now()
);

-- ContextOS preferences (Private Mode default, sensors, consent).
create table if not exists public.contextos_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  private_mode_default boolean not null default false,
  cloud_consent boolean not null default true,
  enabled_surfaces jsonb not null default '["share_sheet","manual","camera"]',
  updated_at timestamptz not null default now()
);

-- ---- RLS ----
alter table public.captured_moments enable row level security;
alter table public.risk_analyses enable row level security;
alter table public.alter_actions enable row level security;
alter table public.action_outcomes enable row level security;
alter table public.decision_dna enable row level security;
alter table public.audit_events enable row level security;
alter table public.trusted_entities enable row level security;
alter table public.contextos_preferences enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'captured_moments','risk_analyses','alter_actions','action_outcomes',
    'decision_dna','audit_events','trusted_entities','contextos_preferences'
  ]
  loop
    execute format('drop policy if exists "%1$s_owner_all" on public.%1$s', t);
    execute format(
      'create policy "%1$s_owner_all" on public.%1$s for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t
    );
  end loop;
end $$;

create index if not exists idx_moments_user_created on public.captured_moments (user_id, created_at desc);
create index if not exists idx_risk_user_created on public.risk_analyses (user_id, created_at desc);
create index if not exists idx_actions_moment on public.alter_actions (moment_id);
create index if not exists idx_audit_user_created on public.audit_events (user_id, created_at desc);
