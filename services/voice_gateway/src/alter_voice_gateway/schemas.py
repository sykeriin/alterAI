from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


class VoiceIntent(StrEnum):
    future_decision = "future_decision"
    clone_council = "clone_council"
    opportunity_search = "opportunity_search"
    memory_capture = "memory_capture"
    lens_scan = "lens_scan"
    nfc_exchange = "nfc_exchange"
    office_briefing = "office_briefing"
    social_graph = "social_graph"
    reputation = "reputation"
    call_contact = "call_contact"
    send_message = "send_message"
    unknown = "unknown"


class DeviceSurface(StrEnum):
    phone = "phone"
    laptop = "laptop"


class VoiceSessionRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    transcript: str = Field(min_length=1, max_length=4000)
    locale: str = Field(default="en-US", min_length=2, max_length=16)
    device_surface: DeviceSurface = DeviceSurface.phone
    context: dict[str, str] = Field(default_factory=dict)

    @field_validator("transcript")
    @classmethod
    def compact_transcript(cls, value: str) -> str:
        return " ".join(value.strip().split())


class VoiceAction(BaseModel):
    label: str
    route: str
    reason: str
    priority: int = Field(ge=1, le=5)


class VoiceSessionResponse(BaseModel):
    session_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    wake_word_detected: bool
    normalized_text: str
    inferred_intent: VoiceIntent
    confidence: float = Field(ge=0, le=1)
    route_targets: list[str]
    actions: list[VoiceAction]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str
    wake_phrase: str


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    output_contract: dict[str, list[str]]
