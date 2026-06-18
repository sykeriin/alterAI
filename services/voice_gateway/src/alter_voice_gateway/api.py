from __future__ import annotations

from functools import lru_cache

from fastapi import FastAPI

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    HealthResponse,
    VoiceSessionRequest,
    VoiceSessionResponse,
)
from .service import VoiceGatewayService, create_voice_gateway_service

app = FastAPI(
    title="ALTER Voice Gateway",
    version="0.1.0",
    description="Wake phrase and voice intent gateway for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> VoiceGatewayService:
    return create_voice_gateway_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-voice-gateway",
        environment=settings.voice_env,
        wake_phrase=settings.wake_phrase,
    )


@app.get("/v1/voice/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-voice-gateway",
        components=[
            "wake phrase detector",
            "transcript normalizer",
            "deterministic intent classifier",
            "route target planner",
        ],
        data_flow=[
            "Phone captures voice and sends transcript.",
            "Gateway detects wake phrase and normalizes command text.",
            "Intent classifier maps command to ALTER workflow.",
            "Response returns route targets and prioritized actions.",
        ],
        output_contract={
            "VoiceSessionResponse": [
                "wake_word_detected",
                "normalized_text",
                "inferred_intent",
                "confidence",
                "route_targets",
                "actions",
            ]
        },
    )


@app.post("/v1/voice/session", response_model=VoiceSessionResponse)
async def start_session(request: VoiceSessionRequest) -> VoiceSessionResponse:
    return get_service().start_session(request)
