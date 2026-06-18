-- Structured phone-control actions and audit metadata.

alter table public.alter_actions
  add column if not exists action_payload jsonb not null default '{}',
  add column if not exists policy_tier text not null default 'safe',
  add column if not exists executed_result text not null default '';

alter table public.audit_events
  add column if not exists metadata jsonb not null default '{}';

create index if not exists idx_actions_user_status
  on public.alter_actions (user_id, status, created_at desc);

create index if not exists idx_audit_phone_control
  on public.audit_events (user_id, kind, created_at desc)
  where kind = 'phone_control';
