from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class OfficeArtifactType(StrEnum):
    meeting = "meeting"
    email = "email"
    document = "document"
    slide_deck = "slide_deck"
    calendar_event = "calendar_event"
    drive_file = "drive_file"


class OfficeArtifactCreate(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    provider: str = Field(default="manual", max_length=80)
    artifact_type: OfficeArtifactType
    title: str = Field(min_length=2, max_length=220)
    content: str = Field(default="", max_length=12_000)
    participants: list[str] = Field(default_factory=list, max_length=50)
    metadata: dict[str, str] = Field(default_factory=dict)
    external_id: str | None = Field(default=None, max_length=180)
    occurred_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class OfficeArtifact(OfficeArtifactCreate):
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class BriefingRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    objective: str = Field(min_length=2, max_length=600)
    artifact_ids: list[UUID] = Field(default_factory=list, max_length=30)
    inline_artifacts: list[OfficeArtifactCreate] = Field(default_factory=list, max_length=20)


class OfficeActionItem(BaseModel):
    title: str
    owner: str
    priority: str
    due_hint: str
    rationale: str


class MemoryCandidate(BaseModel):
    title: str
    memory_type: str
    content: str
    confidence: float = Field(ge=0, le=1)


class ReputationSignal(BaseModel):
    title: str
    event_type: str
    impact_score: int = Field(ge=-100, le=100)
    rationale: str


class BriefingResponse(BaseModel):
    briefing_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    objective: str
    summary: str
    key_context: list[str]
    decisions: list[str]
    risks: list[str]
    action_items: list[OfficeActionItem]
    memory_candidates: list[MemoryCandidate]
    reputation_signals: list[ReputationSignal]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    output_contract: dict[str, list[str]]
