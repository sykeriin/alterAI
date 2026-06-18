from __future__ import annotations

import pytest

from alter_opportunity_engine.repository import InMemoryOpportunityRepository
from alter_opportunity_engine.schemas import (
    CrawlRequest,
    OpportunityCategory,
    OpportunitySource,
    PipelineRequest,
    UserOpportunityProfile,
)
from alter_opportunity_engine.service import create_opportunity_service


@pytest.mark.asyncio
async def test_pipeline_crawls_normalizes_ranks_and_recommends() -> None:
    service = create_opportunity_service(repository=InMemoryOpportunityRepository())
    response = await service.pipeline(
        PipelineRequest(
            profile=UserOpportunityProfile(
                career_stage="student founder",
                skills=["Python", "AI", "backend", "product"],
                goals=["startup", "open source", "funding"],
                interests=["AI agents", "developer tools"],
                preferred_categories=[
                    OpportunityCategory.hackathon,
                    OpportunityCategory.grant,
                    OpportunityCategory.accelerator,
                ],
                risk_tolerance=0.65,
            ),
            crawl=CrawlRequest(
                sources=[
                    OpportunitySource.devpost,
                    OpportunitySource.gsoc,
                    OpportunitySource.startup_grants,
                ],
                query="AI open source startup",
                limit_per_source=2,
            ),
            limit=3,
        )
    )

    assert response.crawl.raw_opportunities
    assert response.normalized.opportunities
    assert response.categorized.opportunities
    assert response.ranked.ranked_opportunities[0].score > 0
    assert response.recommendations.recommendations


@pytest.mark.asyncio
async def test_crawl_uses_all_sources_by_default() -> None:
    service = create_opportunity_service(repository=InMemoryOpportunityRepository())
    response = await service.crawl(CrawlRequest(limit_per_source=1))

    assert response.source_count == 9
    assert len(response.raw_opportunities) == 9

