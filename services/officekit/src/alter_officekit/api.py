from __future__ import annotations

from functools import lru_cache

from fastapi import FastAPI

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    BriefingRequest,
    BriefingResponse,
    HealthResponse,
    OfficeArtifact,
    OfficeArtifactCreate,
)
from .service import OfficeKitService, create_officekit_service

app = FastAPI(
    title="ALTER OfficeKit",
    version="0.1.0",
    description="Mission briefing and office artifact intelligence for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> OfficeKitService:
    return create_officekit_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-officekit",
        environment=settings.officekit_env,
    )


@app.get("/v1/officekit/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-officekit",
        components=[
            "artifact intake",
            "briefing generator",
            "action item extractor",
            "memory candidate writer",
            "reputation signal generator",
        ],
        data_flow=[
            "User imports or selects calendar, email, document, or slide artifacts.",
            "OfficeKit creates a mission briefing around the active objective.",
            "Briefing response includes action items, risks, memory candidates, and trust signals.",
        ],
        output_contract={
            "BriefingResponse": [
                "summary",
                "key_context",
                "decisions",
                "risks",
                "action_items",
                "memory_candidates",
                "reputation_signals",
            ]
        },
    )


@app.post("/v1/officekit/artifacts", response_model=OfficeArtifact)
async def create_artifact(payload: OfficeArtifactCreate) -> OfficeArtifact:
    return get_service().create_artifact(payload)


@app.post("/v1/officekit/briefing", response_model=BriefingResponse)
async def briefing(request: BriefingRequest) -> BriefingResponse:
    return get_service().briefing(request)
