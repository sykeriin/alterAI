from __future__ import annotations

import pytest

from alter_clone_council.config import Settings
from alter_clone_council.schemas import DebateRequest
from alter_clone_council.service import create_clone_council_service
from alter_clone_council.testing import DeterministicCouncilModelClient


@pytest.mark.asyncio
async def test_clone_council_returns_required_sections() -> None:
    service = create_clone_council_service(
        settings=Settings(),
        model_client=DeterministicCouncilModelClient(),
    )

    response = await service.debate(
        DebateRequest(
            question="Should I raise a seed round now or bootstrap for six more months?",
            context={"runway_months": 9, "weekly_growth": "8%"},
        )
    )

    assert response.final_recommendation
    assert 0 <= response.confidence_score <= 1
    assert response.risks
    assert response.opportunities
    assert len(response.agents) == 7
    assert len(response.initial_opinions) == 7
    assert len(response.updated_opinions) == 7
    assert response.debate_transcript


@pytest.mark.asyncio
async def test_debate_request_normalizes_question_mark() -> None:
    request = DebateRequest(question="What should I do next")
    assert request.question == "What should I do next?"


@pytest.mark.asyncio
async def test_local_service_uses_deterministic_model_client() -> None:
    service = create_clone_council_service(
        settings=Settings(ALTER_CLONE_COUNCIL_ENV="local"),
    )

    response = await service.debate(
        DebateRequest(question="Should I run an end-to-end demo today?")
    )

    assert response.final_recommendation
    assert response.confidence_score == 0.81
    assert len(response.agents) == 7
