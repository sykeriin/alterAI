from __future__ import annotations

from functools import lru_cache

from fastapi import FastAPI

from .agents import DEFAULT_AGENT_SPECS
from .config import get_settings
from .schemas import CloneCouncilResponse, DebateRequest, HealthResponse
from .service import CloneCouncilService, create_clone_council_service

app = FastAPI(
    title="ALTER Clone Council",
    version="0.1.0",
    description="LangGraph multi-agent debate service for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> CloneCouncilService:
    return create_clone_council_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-clone-council",
        environment=settings.clone_council_env,
        model=settings.openai_model,
    )


@app.get("/v1/clone-council/agents")
async def list_agents():
    return {"agents": list(DEFAULT_AGENT_SPECS)}


@app.post("/v1/clone-council/debate", response_model=CloneCouncilResponse)
async def run_debate(request: DebateRequest) -> CloneCouncilResponse:
    return await get_service().debate(request)
