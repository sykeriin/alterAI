/// SQLCipher schema v1 — ported from Supabase migrations.
const kMigrationV1Statements = <String>[
  '''
  CREATE TABLE IF NOT EXISTS local_session (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    pin_setup_complete INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT '',
    career_stage TEXT NOT NULL DEFAULT '',
    industry TEXT NOT NULL DEFAULT '',
    bio TEXT NOT NULL DEFAULT '',
    skills TEXT NOT NULL DEFAULT '[]',
    goals TEXT NOT NULL DEFAULT '[]',
    interests TEXT NOT NULL DEFAULT '[]',
    openai_key TEXT NOT NULL DEFAULT '',
    sarvam_key TEXT NOT NULL DEFAULT '',
    onboarding_done INTEGER NOT NULL DEFAULT 0,
    languages TEXT NOT NULL DEFAULT '["English"]',
    location TEXT NOT NULL DEFAULT '',
    availability TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    intent TEXT,
    created_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_conversations_user_created ON conversations(user_id, created_at DESC)',
  '''
  CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'observation',
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    provenance TEXT NOT NULL DEFAULT '',
    confidence REAL NOT NULL DEFAULT 0.5,
    sensitivity TEXT NOT NULL DEFAULT 'normal',
    retention TEXT NOT NULL DEFAULT 'ephemeral',
    expires_at TEXT,
    source_ids TEXT NOT NULL DEFAULT '[]',
    confirmed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_memories_user_created ON memories(user_id, created_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_memories_expires ON memories(expires_at)',
  '''
  CREATE TABLE IF NOT EXISTS memory_embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    memory_id TEXT,
    abstract_text TEXT NOT NULL,
    kind TEXT NOT NULL,
    embedding BLOB NOT NULL,
    embedding_model TEXT NOT NULL DEFAULT 'hash_v1',
    created_at INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_embeddings_memory_id ON memory_embeddings(memory_id)',
  'CREATE INDEX IF NOT EXISTS idx_embeddings_created ON memory_embeddings(created_at DESC)',
  '''
  CREATE TABLE IF NOT EXISTS memory_governance_settings (
    user_id TEXT PRIMARY KEY,
    default_retention TEXT NOT NULL DEFAULT 'ephemeral',
    durable_requires_confirmation INTEGER NOT NULL DEFAULT 1,
    sensitive_requires_confirmation INTEGER NOT NULL DEFAULT 1,
    restricted_storage_allowed INTEGER NOT NULL DEFAULT 0,
    portable_export_enabled INTEGER NOT NULL DEFAULT 1,
    max_retrieval_chars INTEGER NOT NULL DEFAULT 6000,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS identity_traits (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    dimension TEXT NOT NULL,
    value TEXT NOT NULL DEFAULT '',
    confidence REAL NOT NULL DEFAULT 0.5,
    source_memory_ids TEXT NOT NULL DEFAULT '[]',
    updated_at TEXT NOT NULL,
    UNIQUE(user_id, dimension)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS assistant_briefs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    greeting TEXT NOT NULL,
    focus TEXT NOT NULL,
    next_action TEXT NOT NULL,
    signals TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS clone_agents (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    state TEXT NOT NULL,
    confidence REAL NOT NULL,
    accent_hex TEXT NOT NULL,
    summary TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS future_scenarios (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    horizon TEXT NOT NULL,
    probability REAL NOT NULL,
    upside TEXT NOT NULL,
    risk TEXT NOT NULL,
    levers TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS opportunity_signals (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    score REAL NOT NULL,
    source TEXT NOT NULL,
    time_window TEXT NOT NULL,
    evidence TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS social_contacts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    context TEXT NOT NULL,
    strength REAL NOT NULL,
    tags TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reputation_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    delta INTEGER NOT NULL,
    description TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS lens_insights (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    confidence REAL NOT NULL,
    description TEXT NOT NULL,
    actions TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS captured_moments (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    source_surface TEXT NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'text',
    raw_excerpt TEXT NOT NULL DEFAULT '',
    redacted_text TEXT NOT NULL DEFAULT '',
    private_mode INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS risk_analyses (
    id TEXT PRIMARY KEY,
    moment_id TEXT,
    user_id TEXT NOT NULL,
    verdict TEXT NOT NULL,
    risk_score REAL NOT NULL DEFAULT 0,
    headline TEXT NOT NULL DEFAULT '',
    why_it_matters TEXT NOT NULL DEFAULT '',
    facts TEXT NOT NULL DEFAULT '[]',
    red_flags TEXT NOT NULL DEFAULT '[]',
    assumptions TEXT NOT NULL DEFAULT '[]',
    missing_info TEXT NOT NULL DEFAULT '[]',
    what_could_make_wrong TEXT NOT NULL DEFAULT '',
    verification_steps TEXT NOT NULL DEFAULT '[]',
    confidence REAL NOT NULL DEFAULT 0,
    edge_summary TEXT NOT NULL DEFAULT '',
    cloud_used INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS alter_actions (
    id TEXT PRIMARY KEY,
    moment_id TEXT,
    user_id TEXT NOT NULL,
    action_type TEXT NOT NULL,
    title TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    requires_confirmation INTEGER NOT NULL DEFAULT 1,
    irreversible INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'proposed',
    action_payload TEXT NOT NULL DEFAULT '{}',
    policy_tier TEXT NOT NULL DEFAULT 'safe',
    executed_result TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_actions_user_status ON alter_actions(user_id, status, created_at DESC)',
  '''
  CREATE TABLE IF NOT EXISTS action_outcomes (
    id TEXT PRIMARY KEY,
    action_id TEXT,
    moment_id TEXT,
    user_id TEXT NOT NULL,
    outcome TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS decision_dna (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    pattern TEXT NOT NULL,
    evidence TEXT NOT NULL DEFAULT '',
    weight REAL NOT NULL DEFAULT 0.5,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS audit_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    moment_id TEXT,
    kind TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    edge_state TEXT NOT NULL DEFAULT 'edge',
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_audit_user_created ON audit_events(user_id, created_at DESC)',
  '''
  CREATE TABLE IF NOT EXISTS trusted_entities (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    value TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS contextos_preferences (
    user_id TEXT PRIMARY KEY,
    private_mode_default INTEGER NOT NULL DEFAULT 0,
    cloud_consent INTEGER NOT NULL DEFAULT 1,
    enabled_surfaces TEXT NOT NULL DEFAULT '["share_sheet","manual","camera"]',
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS digital_twin_sources (
    user_id TEXT NOT NULL,
    source_key TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'off',
    connected INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, source_key)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS digital_twin_settings (
    user_id TEXT PRIMARY KEY,
    autonomy_level TEXT NOT NULL DEFAULT 'recommend',
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_moments_user_created ON captured_moments(user_id, created_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_risk_user_created ON risk_analyses(user_id, created_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_actions_moment ON alter_actions(moment_id)',
];
