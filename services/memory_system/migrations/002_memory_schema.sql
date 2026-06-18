CREATE SCHEMA IF NOT EXISTS memory;

DO $$
BEGIN
  CREATE TYPE memory.memory_type AS ENUM (
    'skill',
    'project',
    'goal',
    'conversation',
    'opportunity',
    'decision',
    'mentor',
    'friend',
    'learning_progress',
    'note'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE memory.memory_status AS ENUM ('active', 'archived', 'superseded', 'deleted');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE memory.memory_privacy AS ENUM ('private', 'agent_visible', 'shareable');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE memory.relationship_type AS ENUM (
    'supports',
    'contradicts',
    'updates',
    'derived_from',
    'related_to',
    'belongs_to',
    'influenced_by'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS memory.memory_profiles (
  user_id uuid PRIMARY KEY,
  display_name text,
  locale text DEFAULT 'en',
  memory_policy jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memory.memory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  memory_type memory.memory_type NOT NULL,
  title text NOT NULL,
  summary text NOT NULL,
  content text NOT NULL,
  source text NOT NULL DEFAULT 'manual',
  status memory.memory_status NOT NULL DEFAULT 'active',
  privacy memory.memory_privacy NOT NULL DEFAULT 'agent_visible',
  confidence numeric(5,4) NOT NULL DEFAULT 0.75 CHECK (confidence >= 0 AND confidence <= 1),
  importance numeric(5,4) NOT NULL DEFAULT 0.50 CHECK (importance >= 0 AND importance <= 1),
  emotional_valence numeric(5,4) CHECK (emotional_valence >= -1 AND emotional_valence <= 1),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  valid_from timestamptz,
  valid_until timestamptz,
  expires_at timestamptz,
  pinned boolean NOT NULL DEFAULT false,
  access_count integer NOT NULL DEFAULT 0,
  last_accessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.memory_embeddings (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  embedding vector(1536) NOT NULL,
  embedding_model text NOT NULL DEFAULT 'text-embedding-3-small',
  content_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memory.memory_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  source_memory_id uuid NOT NULL REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  target_memory_id uuid NOT NULL REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  relationship_type memory.relationship_type NOT NULL,
  strength numeric(5,4) NOT NULL DEFAULT 0.5 CHECK (strength >= 0 AND strength <= 1),
  rationale text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_memory_id, target_memory_id, relationship_type)
);

CREATE TABLE IF NOT EXISTS memory.skill_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  skill_name text NOT NULL,
  category text NOT NULL DEFAULT 'domain',
  level numeric(5,4) NOT NULL CHECK (level >= 0 AND level <= 1),
  years numeric(6,2) NOT NULL DEFAULT 0,
  last_practiced_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.project_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  project_name text NOT NULL,
  role text,
  status text NOT NULL DEFAULT 'active',
  started_on date,
  ended_on date,
  url text,
  impact jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS memory.goal_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  goal_title text NOT NULL,
  category text NOT NULL DEFAULT 'career',
  priority integer NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  target_date date,
  progress numeric(5,4) NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 1)
);

CREATE TABLE IF NOT EXISTS memory.conversation_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text,
  channel text NOT NULL DEFAULT 'voice',
  language text NOT NULL DEFAULT 'en',
  summary_memory_id uuid REFERENCES memory.memory_items(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.conversation_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES memory.conversation_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
  content text NOT NULL,
  extracted_memory_ids uuid[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memory.opportunity_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  opportunity_name text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  source text NOT NULL,
  stage text NOT NULL DEFAULT 'discovered',
  opportunity_score numeric(5,2) NOT NULL DEFAULT 50 CHECK (opportunity_score >= 0 AND opportunity_score <= 100),
  deadline_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.decision_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  decision_title text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now(),
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  rationale text,
  outcome_status text NOT NULL DEFAULT 'pending',
  review_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.person_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  person_name text NOT NULL,
  relation text NOT NULL CHECK (relation IN ('mentor', 'friend', 'contact')),
  organization text,
  role text,
  contact jsonb NOT NULL DEFAULT '{}'::jsonb,
  trust_level numeric(5,4) NOT NULL DEFAULT 0.5 CHECK (trust_level >= 0 AND trust_level <= 1),
  last_interaction_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.learning_progress_details (
  memory_id uuid PRIMARY KEY REFERENCES memory.memory_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  topic text NOT NULL,
  progress numeric(5,4) NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 1),
  hours_spent numeric(8,2) NOT NULL DEFAULT 0,
  last_session_at timestamptz
);

CREATE TABLE IF NOT EXISTS memory.short_term_memory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  session_id uuid,
  key text NOT NULL,
  value jsonb NOT NULL,
  summary text NOT NULL,
  importance numeric(5,4) NOT NULL DEFAULT 0.25 CHECK (importance >= 0 AND importance <= 1),
  promoted_memory_id uuid REFERENCES memory.memory_items(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS memory.memory_access_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  memory_id uuid REFERENCES memory.memory_items(id) ON DELETE SET NULL,
  access_type text NOT NULL,
  request_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_memory_items_user_type_status
  ON memory.memory_items (user_id, memory_type, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_memory_items_user_importance
  ON memory.memory_items (user_id, importance DESC, updated_at DESC)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_memory_items_metadata
  ON memory.memory_items USING gin (metadata);

CREATE INDEX IF NOT EXISTS idx_memory_embeddings_user
  ON memory.memory_embeddings (user_id);

CREATE INDEX IF NOT EXISTS idx_memory_embeddings_vector_hnsw
  ON memory.memory_embeddings USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_short_term_memory_user_expires
  ON memory.short_term_memory (user_id, expires_at);

CREATE OR REPLACE FUNCTION memory.search_memories(
  p_user_id uuid,
  p_query_embedding vector(1536),
  p_match_count integer DEFAULT 12,
  p_min_similarity numeric DEFAULT 0.0
)
RETURNS TABLE (
  memory_id uuid,
  memory_type memory.memory_type,
  title text,
  summary text,
  content text,
  confidence numeric,
  importance numeric,
  similarity numeric,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    mi.id,
    mi.memory_type,
    mi.title,
    mi.summary,
    mi.content,
    mi.confidence,
    mi.importance,
    (1 - (me.embedding <=> p_query_embedding))::numeric AS similarity,
    mi.updated_at
  FROM memory.memory_embeddings me
  JOIN memory.memory_items mi ON mi.id = me.memory_id
  WHERE mi.user_id = p_user_id
    AND mi.status = 'active'
    AND mi.privacy IN ('agent_visible', 'shareable')
    AND (1 - (me.embedding <=> p_query_embedding)) >= p_min_similarity
  ORDER BY me.embedding <=> p_query_embedding
  LIMIT p_match_count;
$$;

