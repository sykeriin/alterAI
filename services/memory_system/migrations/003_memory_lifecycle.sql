DO $$
BEGIN
  CREATE TYPE memory.memory_retention AS ENUM ('ephemeral', 'session', 'expiring', 'durable');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE memory.memory_sensitivity AS ENUM ('normal', 'sensitive', 'restricted');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE memory.memory_lifecycle_stage AS ENUM (
    'encoded',
    'stabilized',
    'stored',
    'retrieved',
    'updated',
    'forgotten'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE memory.memory_items
  ADD COLUMN IF NOT EXISTS retention memory.memory_retention NOT NULL DEFAULT 'durable',
  ADD COLUMN IF NOT EXISTS sensitivity memory.memory_sensitivity NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS lifecycle_stage memory.memory_lifecycle_stage NOT NULL DEFAULT 'stored',
  ADD COLUMN IF NOT EXISTS requires_confirmation boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_memory_items_governance
  ON memory.memory_items (user_id, retention, sensitivity, lifecycle_stage, updated_at DESC);

CREATE TABLE IF NOT EXISTS memory.memory_governance_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  memory_id uuid REFERENCES memory.memory_items(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  rationale text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_memory_governance_events_user
  ON memory.memory_governance_events (user_id, created_at DESC);
