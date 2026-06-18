from __future__ import annotations

from functools import lru_cache

from fastapi import FastAPI

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    FutureSimulationRequest,
    FutureSimulationResponse,
    HealthResponse,
)
from .service import FutureSimulationService, create_future_simulation_service

app = FastAPI(
    title="ALTER Future Simulation Engine",
    version="0.1.0",
    description="Structured future simulation service for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> FutureSimulationService:
    return create_future_simulation_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-future-simulation",
        environment=settings.future_simulation_env,
    )


@app.get("/v1/future-simulation/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-future-simulation",
        components=[
            "FastAPI transport",
            "Pydantic contract validation",
            "Signal extraction",
            "Future archetype generation",
            "Trajectory projection",
            "Opportunity, risk, and probability scoring",
        ],
        data_flow=[
            "Validate input profile, skills, goals, experience, and interests.",
            "Extract normalized readiness, alignment, learning, network, and salary signals.",
            "Generate Future A, Future B, and Future C from distinct archetypes.",
            "Project timeline, salary, skill, and network trajectories.",
            "Return strict structured JSON with summary recommendation.",
        ],
        output_contract={
            "futures": [
                "future_id",
                "timeline",
                "salary_trajectory",
                "skill_trajectory",
                "network_growth",
                "opportunity_score",
                "risk_score",
                "success_probability",
            ]
        },
    )


@app.post("/v1/future-simulation/simulate", response_model=FutureSimulationResponse)
async def simulate(request: FutureSimulationRequest) -> FutureSimulationResponse:
    return get_service().simulate(request)

