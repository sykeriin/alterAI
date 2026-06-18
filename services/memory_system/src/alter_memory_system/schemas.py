from __future__ import annotations

from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MemoryType(StrEnum):
    skill = "skill"
    project = "project"
    goal = "goal"
    conversation = "conversation"
    opportunity = "opportunity"
    decision = "decision"
    mentor = "mentor"
    friend = "friend"
    learning_progress = "learning_progress"
    note = "note"


class MemoryStatus(StrEnum):
    active = "active"
    archived = "archived"
    superseded = "superseded"
    deleted = "deleted"


class MemoryPrivacy(StrEnum):
    private = "private"
    agent_visible = "agent_visible"
    shareable = "shareable"


class MemoryRetention(StrEnum):
    ephemeral = "ephemeral"
    session = "session"
    expiring = "expiring"
    durable = "durable"


class MemorySensitivity(StrEnum):
    normal = "normal"
    sensitive = "sensitive"
    restricted = "restricted"


class MemoryLifecycleStage(StrEnum):
    encoded = "encoded"
    stabilized = "stabilized"
    stored = "stored"
    retrieved = "retrieved"
    updated = "updated"
    forgotten = "forgotten"


class RelationshipType(StrEnum):
    supports = "supports"
    contradicts = "contradicts"
    updates = "updates"
    derived_from = "derived_from"
    related_to = "related_to"
    belongs_to = "belongs_to"
    influenced_by = "influenced_by"


class MemoryItemCreate(BaseModel):
    user_id: UUID
    memory_type: MemoryType
    title: str = Field(min_length=2, max_length=240)
    summary: str = Field(min_length=2, max_length=1000)
    content: str = Field(min_length=2, max_length=12000)
    source: str = Field(default="manual", min_length=2, max_length=120)
    privacy: MemoryPrivacy = MemoryPrivacy.agent_visible
    retention: MemoryRetention = MemoryRetention.durable
    sensitivity: MemorySensitivity = MemorySensitivity.normal
    lifecycle_stage: MemoryLifecycleStage = MemoryLifecycleStage.stored
    requires_confirmation: bool = False
    confidence: float = Field(default=0.75, ge=0.0, le=1.0)
    importance: float = Field(default=0.5, ge=0.0, le=1.0)
    emotional_valence: float | None = Field(default=None, ge=-1.0, le=1.0)
    metadata: dict[str, Any] = Field(default_factory=dict)
    embedding: list[float] | None = Field(default=None)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    expires_at: datetime | None = None
    pinned: bool = False

    @field_validator("embedding")
    @classmethod
    def validate_embedding(cls, value: list[float] | None) -> list[float] | None:
        if value is not None and len(value) == 0:
            raise ValueError("embedding cannot be empty")
        return value


class MemoryItemUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=240)
    summary: str | None = Field(default=None, min_length=2, max_length=1000)
    content: str | None = Field(default=None, min_length=2, max_length=12000)
    status: MemoryStatus | None = None
    privacy: MemoryPrivacy | None = None
    retention: MemoryRetention | None = None
    sensitivity: MemorySensitivity | None = None
    lifecycle_stage: MemoryLifecycleStage | None = None
    requires_confirmation: bool | None = None
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    importance: float | None = Field(default=None, ge=0.0, le=1.0)
    metadata: dict[str, Any] | None = None
    embedding: list[float] | None = None
    pinned: bool | None = None


class MemoryItem(BaseModel):
    model_config = ConfigDict(use_enum_values=True)

    id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    memory_type: MemoryType
    title: str
    summary: str
    content: str
    source: str
    status: MemoryStatus = MemoryStatus.active
    privacy: MemoryPrivacy = MemoryPrivacy.agent_visible
    retention: MemoryRetention = MemoryRetention.durable
    sensitivity: MemorySensitivity = MemorySensitivity.normal
    lifecycle_stage: MemoryLifecycleStage = MemoryLifecycleStage.stored
    requires_confirmation: bool = False
    confidence: float
    importance: float
    emotional_valence: float | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    embedding: list[float] | None = None
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    expires_at: datetime | None = None
    pinned: bool = False
    access_count: int = 0
    last_accessed_at: datetime | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    archived_at: datetime | None = None


class MemoryRelationshipCreate(BaseModel):
    user_id: UUID
    source_memory_id: UUID
    target_memory_id: UUID
    relationship_type: RelationshipType
    strength: float = Field(default=0.5, ge=0.0, le=1.0)
    rationale: str | None = Field(default=None, max_length=1000)


class MemoryRelationship(MemoryRelationshipCreate):
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class MemorySearchRequest(BaseModel):
    user_id: UUID
    query: str = Field(min_length=1, max_length=2000)
    query_embedding: list[float] | None = None
    memory_types: list[MemoryType] = Field(default_factory=list)
    include_short_term: bool = True
    limit: int = Field(default=12, ge=1, le=50)
    min_similarity: float = Field(default=0.0, ge=0.0, le=1.0)


class MemorySearchHit(BaseModel):
    memory: MemoryItem
    similarity: float = Field(ge=0.0, le=1.0)
    reason: str


class MemorySearchResponse(BaseModel):
    query: str
    hits: list[MemorySearchHit]


class MemoryRetrieveRequest(BaseModel):
    user_id: UUID
    task: str = Field(min_length=2, max_length=3000)
    query_embedding: list[float] | None = None
    memory_types: list[MemoryType] = Field(default_factory=list)
    limit: int = Field(default=12, ge=1, le=50)
    include_private: bool = False
    max_context_chars: int = Field(default=6000, ge=500, le=30000)


class MemoryContextBlock(BaseModel):
    memory_id: UUID
    memory_type: MemoryType
    title: str
    summary: str
    content: str
    relevance: float = Field(ge=0.0, le=1.0)
    confidence: float = Field(ge=0.0, le=1.0)
    importance: float = Field(ge=0.0, le=1.0)


class MemoryRetrieveResponse(BaseModel):
    task: str
    context: list[MemoryContextBlock]
    retrieval_notes: list[str]
    context_chars: int = 0


class MemoryIngestRequest(BaseModel):
    user_id: UUID
    content: str = Field(min_length=1, max_length=12000)
    source: str = Field(default="conversation", min_length=2, max_length=120)
    session_id: UUID | None = None
    user_confirmed: bool = False
    metadata: dict[str, Any] = Field(default_factory=dict)


class MemoryClassification(BaseModel):
    should_store: bool
    retention: MemoryRetention
    sensitivity: MemorySensitivity
    memory_type: MemoryType
    importance: float = Field(ge=0.0, le=1.0)
    confidence: float = Field(ge=0.0, le=1.0)
    requires_confirmation: bool
    rationale: list[str]
    expires_in_minutes: int | None = None


class MemoryIngestResponse(BaseModel):
    classification: MemoryClassification
    stored_memory: MemoryItem | None = None
    short_term_memory: ShortTermMemory | None = None
    raw_content_deleted: bool = True


class MemoryPolicy(BaseModel):
    default_retention: MemoryRetention = MemoryRetention.ephemeral
    durable_requires_confirmation: bool = True
    sensitive_requires_confirmation: bool = True
    restricted_storage_allowed: bool = False
    max_retrieval_chars: int = Field(default=6000, ge=500, le=30000)
    portable_export_enabled: bool = True


class MemoryGovernanceResponse(BaseModel):
    user_id: UUID
    policy: MemoryPolicy
    memory_counts: dict[str, int]
    lifecycle: list[str]
    user_controls: list[str]


class IdentitySignal(BaseModel):
    label: str
    evidence_count: int
    confidence: float = Field(ge=0.0, le=1.0)
    evidence_memory_ids: list[UUID]


class IdentitySnapshotResponse(BaseModel):
    user_id: UUID
    signals: list[IdentitySignal]
    evidence_based: bool = True
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class PortableMemoryExport(BaseModel):
    format_version: str = "alter-memory-v1"
    user_id: UUID
    exported_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    memories: list[MemoryItem]
    identity: IdentitySnapshotResponse
    policy: MemoryPolicy


class ShortTermMemoryCreate(BaseModel):
    user_id: UUID
    session_id: UUID | None = None
    key: str = Field(min_length=1, max_length=180)
    value: dict[str, Any]
    summary: str = Field(min_length=2, max_length=1000)
    importance: float = Field(default=0.25, ge=0.0, le=1.0)
    ttl_minutes: int | None = Field(default=None, ge=5, le=43200)


class ShortTermMemory(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    session_id: UUID | None = None
    key: str
    value: dict[str, Any]
    summary: str
    importance: float
    promoted_memory_id: UUID | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    expires_at: datetime

    @classmethod
    def from_create(
        cls,
        payload: ShortTermMemoryCreate,
        *,
        default_ttl_minutes: int,
    ) -> ShortTermMemory:
        ttl = payload.ttl_minutes or default_ttl_minutes
        return cls(
            user_id=payload.user_id,
            session_id=payload.session_id,
            key=payload.key,
            value=payload.value,
            summary=payload.summary,
            importance=payload.importance,
            expires_at=datetime.now(UTC) + timedelta(minutes=ttl),
        )


class PromoteShortTermRequest(BaseModel):
    user_id: UUID
    short_term_memory_id: UUID
    memory_type: MemoryType = MemoryType.note
    title: str = Field(min_length=2, max_length=240)
    confidence: float = Field(default=0.7, ge=0.0, le=1.0)
    importance: float = Field(default=0.55, ge=0.0, le=1.0)
    metadata: dict[str, Any] = Field(default_factory=dict)


class TimelineResponse(BaseModel):
    user_id: UUID
    memories: list[MemoryItem]


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ArchitectureResponse(BaseModel):
    service: str
    storage: list[str]
    capabilities: list[str]
    api_groups: list[str]
