from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChallengeSeverity(StrEnum):
    low = "low"
    medium = "medium"
    high = "high"


class TranscriptEventType(StrEnum):
    thought = "thought"
    challenge = "challenge"
    revision = "revision"
    consensus = "consensus"


class AgentSpec(BaseModel):
    id: str = Field(min_length=2, max_length=64, pattern=r"^[a-z0-9_]+$")
    name: str = Field(min_length=2, max_length=80)
    mandate: str = Field(min_length=10, max_length=1200)
    operating_style: str = Field(min_length=10, max_length=600)
    blind_spots_to_watch: str = Field(min_length=10, max_length=600)


class AgentOpinion(BaseModel):
    agent_id: str = Field(min_length=2, max_length=64)
    agent_name: str = Field(min_length=2, max_length=80)
    stance: str = Field(min_length=3, max_length=500)
    reasoning: list[str] = Field(default_factory=list, min_length=1, max_length=8)
    assumptions: list[str] = Field(default_factory=list, max_length=8)
    recommendation: str = Field(min_length=3, max_length=1200)
    confidence: float = Field(ge=0.0, le=1.0)
    risks: list[str] = Field(default_factory=list, max_length=8)
    opportunities: list[str] = Field(default_factory=list, max_length=8)


class AgentChallenge(BaseModel):
    from_agent_id: str = Field(min_length=2, max_length=64)
    from_agent_name: str = Field(min_length=2, max_length=80)
    to_agent_id: str = Field(min_length=2, max_length=64)
    to_agent_name: str = Field(min_length=2, max_length=80)
    target_claim: str = Field(min_length=3, max_length=800)
    challenge: str = Field(min_length=3, max_length=1200)
    severity: ChallengeSeverity = ChallengeSeverity.medium
    suggested_revision: str = Field(min_length=3, max_length=800)


class AgentChallengeSet(BaseModel):
    challenges: list[AgentChallenge] = Field(default_factory=list, max_length=10)


class ConsensusResult(BaseModel):
    final_recommendation: str = Field(min_length=10, max_length=2400)
    confidence_score: float = Field(ge=0.0, le=1.0)
    risks: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    opportunities: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    dissenting_views: list[str] = Field(default_factory=list, max_length=8)
    action_plan: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    rationale_summary: list[str] = Field(default_factory=list, min_length=1, max_length=8)


class TranscriptEntry(BaseModel):
    event_type: TranscriptEventType
    agent_id: str | None = None
    agent_name: str | None = None
    content: str = Field(min_length=1, max_length=2500)
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class DebateRequest(BaseModel):
    question: str = Field(min_length=3, max_length=4000)
    context: dict[str, Any] = Field(default_factory=dict)
    user_id: str | None = Field(default=None, max_length=128)
    debate_id: str = Field(default_factory=lambda: f"debate_{uuid4().hex}")
    max_challenges_per_agent: int | None = Field(default=None, ge=1, le=5)

    @field_validator("question")
    @classmethod
    def normalize_question(cls, value: str) -> str:
        normalized = " ".join(value.strip().split())
        if not normalized.endswith("?"):
            normalized = f"{normalized}?"
        return normalized


class CloneCouncilResponse(BaseModel):
    model_config = ConfigDict(use_enum_values=True)

    debate_id: str
    question: str
    agents: list[AgentSpec]
    debate_transcript: list[TranscriptEntry]
    initial_opinions: list[AgentOpinion]
    challenges: list[AgentChallenge]
    updated_opinions: list[AgentOpinion]
    final_recommendation: str
    confidence_score: float
    risks: list[str]
    opportunities: list[str]
    dissenting_views: list[str]
    action_plan: list[str]
    rationale_summary: list[str]
    created_at: datetime
    completed_at: datetime


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str
    model: str

