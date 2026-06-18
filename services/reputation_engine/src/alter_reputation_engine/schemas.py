from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class ReputationEventType(StrEnum):
    delivered = "delivered"
    follow_up = "follow_up"
    intro_made = "intro_made"
    missed_reply = "missed_reply"
    endorsement = "endorsement"
    contribution = "contribution"
    commitment_created = "commitment_created"


class ReputationEventCreate(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    event_type: ReputationEventType
    title: str = Field(min_length=2, max_length=180)
    description: str = Field(default="", max_length=800)
    impact_score: int = Field(ge=-100, le=100)
    source: str = Field(default="manual", max_length=80)
    metadata: dict[str, str] = Field(default_factory=dict)
    occurred_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ReputationEvent(ReputationEventCreate):
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ReputationScoreResponse(BaseModel):
    user_id: UUID
    score: int = Field(ge=0, le=1000)
    trust_level: str
    recent_delta: int
    event_count: int
    strengths: list[str]
    risks: list[str]
    recommendations: list[str]
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ReputationEventsResponse(BaseModel):
    user_id: UUID
    events: list[ReputationEvent]


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    output_contract: dict[str, list[str]]
