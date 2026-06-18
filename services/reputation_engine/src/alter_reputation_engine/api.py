from __future__ import annotations

from functools import lru_cache
from uuid import UUID

from fastapi import FastAPI

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    HealthResponse,
    ReputationEvent,
    ReputationEventCreate,
    ReputationEventsResponse,
    ReputationScoreResponse,
)
from .service import ReputationService, create_reputation_service

app = FastAPI(
    title="ALTER Reputation Engine",
    version="0.1.0",
    description="Trust ledger and reputation scoring service for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> ReputationService:
    return create_reputation_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-reputation-engine",
        environment=settings.reputation_env,
    )


@app.get("/v1/reputation/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-reputation-engine",
        components=[
            "event ledger",
            "trust score calculator",
            "risk detector",
            "recommendation generator",
        ],
        data_flow=[
            "OfficeKit, Social Graph, and manual events write reputation signals.",
            "Engine aggregates positive and negative trust deltas.",
            "Score response returns trust level, strengths, risks, and recommendations.",
        ],
        output_contract={
            "ReputationScoreResponse": [
                "score",
                "trust_level",
                "recent_delta",
                "strengths",
                "risks",
                "recommendations",
            ]
        },
    )


@app.post("/v1/reputation/events", response_model=ReputationEvent)
async def create_event(payload: ReputationEventCreate) -> ReputationEvent:
    return get_service().create_event(payload)


@app.get("/v1/reputation/users/{user_id}/events", response_model=ReputationEventsResponse)
async def list_events(user_id: UUID) -> ReputationEventsResponse:
    return ReputationEventsResponse(
        user_id=user_id,
        events=get_service().list_events(user_id),
    )


@app.get("/v1/reputation/users/{user_id}/score", response_model=ReputationScoreResponse)
async def score(user_id: UUID) -> ReputationScoreResponse:
    return get_service().score(user_id)
