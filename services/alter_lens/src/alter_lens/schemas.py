from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class LensScanType(StrEnum):
    resume = "resume"
    startup_deck = "startup_deck"
    event_poster = "event_poster"
    research_paper = "research_paper"
    product = "product"


class LensPriority(StrEnum):
    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"


class LensScanInput(BaseModel):
    scan_type: LensScanType
    image_bytes: bytes
    mime_type: str
    filename: str
    user_context: str = ""


class LensInsight(BaseModel):
    title: str
    detail: str
    confidence: float = Field(ge=0, le=1)
    tags: list[str] = Field(default_factory=list, max_length=8)


class LensOpportunity(BaseModel):
    title: str
    why_now: str
    next_step: str
    score: float = Field(ge=0, le=100)


class LensRecommendation(BaseModel):
    action: str
    priority: LensPriority
    rationale: str


class LensVisionOutput(BaseModel):
    detected_type: str
    summary: str
    confidence: float = Field(ge=0, le=1)
    insights: list[LensInsight] = Field(default_factory=list, max_length=8)
    opportunities: list[LensOpportunity] = Field(default_factory=list, max_length=8)
    recommendations: list[LensRecommendation] = Field(default_factory=list, max_length=8)
    extracted_entities: dict[str, list[str]] = Field(default_factory=dict)
    memory_candidates: list[str] = Field(default_factory=list, max_length=10)


class LensScanResponse(LensVisionOutput):
    scan_id: UUID = Field(default_factory=uuid4)
    scan_type: LensScanType
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str
    model: str


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    supported_scan_types: list[LensScanType]
    output_contract: dict[str, list[str]]
