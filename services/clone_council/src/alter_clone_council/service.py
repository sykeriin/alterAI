from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from .agents import DEFAULT_AGENT_SPECS
from .config import Settings, get_settings
from .graph import build_clone_council_graph, initial_state
from .model_client import CouncilModelClient, OpenAICouncilModelClient
from .schemas import CloneCouncilResponse, DebateRequest
from .testing import DeterministicCouncilModelClient


class CloneCouncilService:
    def __init__(self, *, settings: Settings, model_client: CouncilModelClient) -> None:
        self._settings = settings
        self._graph = build_clone_council_graph(
            model_client=model_client,
            settings=settings,
        )

    async def debate(self, request: DebateRequest) -> CloneCouncilResponse:
        max_challenges = (
            request.max_challenges_per_agent or self._settings.max_challenges_per_agent
        )
        state = initial_state(
            debate_id=request.debate_id,
            question=request.question,
            context=request.context,
            max_challenges_per_agent=max_challenges,
        )
        result: dict[str, Any] = await self._graph.ainvoke(
            state,
            config={"configurable": {"thread_id": request.debate_id}},
        )
        consensus = result["consensus"]
        return CloneCouncilResponse(
            debate_id=request.debate_id,
            question=request.question,
            agents=list(DEFAULT_AGENT_SPECS),
            debate_transcript=result["transcript"],
            initial_opinions=list(result["initial_opinions"].values()),
            challenges=result["challenges"],
            updated_opinions=list(result["updated_opinions"].values()),
            final_recommendation=consensus.final_recommendation,
            confidence_score=consensus.confidence_score,
            risks=consensus.risks,
            opportunities=consensus.opportunities,
            dissenting_views=consensus.dissenting_views,
            action_plan=consensus.action_plan,
            rationale_summary=consensus.rationale_summary,
            created_at=result["started_at"],
            completed_at=datetime.now(UTC),
        )


def create_clone_council_service(
    *,
    settings: Settings | None = None,
    model_client: CouncilModelClient | None = None,
) -> CloneCouncilService:
    resolved_settings = settings or get_settings()
    resolved_client = (
        model_client
        or (
            DeterministicCouncilModelClient()
            if resolved_settings.clone_council_env == "local"
            else OpenAICouncilModelClient(resolved_settings)
        )
    )
    return CloneCouncilService(
        settings=resolved_settings,
        model_client=resolved_client,
    )
