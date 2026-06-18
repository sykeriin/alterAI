from __future__ import annotations

from functools import lru_cache

from fastapi import FastAPI

from .config import get_settings
from .schemas import (
    CategorizeRequest,
    CategorizeResponse,
    CrawlRequest,
    CrawlResponse,
    HealthResponse,
    NormalizeRequest,
    NormalizeResponse,
    PipelineRequest,
    PipelineResponse,
    RankRequest,
    RankResponse,
    RecommendRequest,
    RecommendResponse,
)
from .service import OpportunityService, create_opportunity_service
from .sources import SOURCE_DEFINITIONS

app = FastAPI(
    title="ALTER Opportunity Engine",
    version="0.1.0",
    description="Crawl, normalize, categorize, rank, and recommend opportunities.",
)


@lru_cache(maxsize=1)
def get_service() -> OpportunityService:
    return create_opportunity_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-opportunity-engine",
        environment=settings.opportunity_env,
    )


@app.get("/v1/opportunities/sources")
async def sources():
    return {"sources": list(SOURCE_DEFINITIONS.values())}


@app.post("/v1/opportunities/crawl", response_model=CrawlResponse)
async def crawl(request: CrawlRequest) -> CrawlResponse:
    return await get_service().crawl(request)


@app.post("/v1/opportunities/normalize", response_model=NormalizeResponse)
async def normalize(request: NormalizeRequest) -> NormalizeResponse:
    return get_service().normalize(request)


@app.post("/v1/opportunities/categorize", response_model=CategorizeResponse)
async def categorize(request: CategorizeRequest) -> CategorizeResponse:
    return get_service().categorize(request)


@app.post("/v1/opportunities/rank", response_model=RankResponse)
async def rank(request: RankRequest) -> RankResponse:
    return get_service().rank(request)


@app.post("/v1/opportunities/recommend", response_model=RecommendResponse)
async def recommend(request: RecommendRequest) -> RecommendResponse:
    return get_service().recommend(request)


@app.post("/v1/opportunities/pipeline", response_model=PipelineResponse)
async def pipeline(request: PipelineRequest) -> PipelineResponse:
    return await get_service().pipeline(request)

