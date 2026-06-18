from __future__ import annotations

from .schemas import (
    AgentChallenge,
    AgentOpinion,
    AgentSpec,
    ChallengeSeverity,
    ConsensusResult,
)


class DeterministicCouncilModelClient:
    """Fast deterministic client for graph contract tests and local demos."""

    async def generate_initial_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        context: dict[str, object],
    ) -> AgentOpinion:
        return AgentOpinion(
            agent_id=agent.id,
            agent_name=agent.name,
            stance=f"{agent.name} sees a focused path for: {question}",
            reasoning=[
                f"{agent.name} prioritizes its mandate.",
                "The decision should preserve optionality while forcing evidence.",
            ],
            assumptions=["The user can run a small validation step this week."],
            recommendation=f"{agent.name} recommends a reversible next step.",
            confidence=0.72,
            risks=["False certainty before enough evidence."],
            opportunities=["Use this decision to generate sharper market signal."],
        )

    async def generate_challenges(
        self,
        *,
        agent: AgentSpec,
        question: str,
        peer_opinions: list[AgentOpinion],
        max_challenges: int,
    ) -> list[AgentChallenge]:
        if not peer_opinions:
            return []
        target = peer_opinions[0]
        return [
            AgentChallenge(
                from_agent_id=agent.id,
                from_agent_name=agent.name,
                to_agent_id=target.agent_id,
                to_agent_name=target.agent_name,
                target_claim=target.recommendation,
                challenge="This recommendation needs a clearer falsification test.",
                severity=ChallengeSeverity.medium,
                suggested_revision="Add one measurable checkpoint before committing fully.",
            )
        ][:max_challenges]

    async def update_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        original_opinion: AgentOpinion,
        received_challenges: list[AgentChallenge],
    ) -> AgentOpinion:
        return original_opinion.model_copy(
            update={
                "reasoning": [
                    *original_opinion.reasoning,
                    f"Updated after {len(received_challenges)} challenge(s).",
                ],
                "recommendation": (
                    f"{original_opinion.recommendation} Add a measurable checkpoint."
                ),
                "confidence": min(0.88, original_opinion.confidence + 0.06),
            }
        )

    async def generate_consensus(
        self,
        *,
        question: str,
        updated_opinions: list[AgentOpinion],
        challenges: list[AgentChallenge],
    ) -> ConsensusResult:
        return ConsensusResult(
            final_recommendation=(
                "Run a reversible, evidence-producing next step before making the larger bet."
            ),
            confidence_score=0.81,
            risks=[
                "The decision may still depend on missing external facts.",
                "Momentum can disguise weak validation.",
            ],
            opportunities=[
                "A small test can create leverage with customers, investors, or hires.",
                "The debate exposes the highest-value assumptions to validate.",
            ],
            dissenting_views=[
                "Future You may prefer a bolder compounding move if downside is capped."
            ],
            action_plan=[
                "Define the riskiest assumption.",
                "Run one validation step within seven days.",
                "Reopen the council with fresh evidence.",
            ],
            rationale_summary=[
                "The council converged on reversible action.",
                "Confidence rose after challenges added falsification criteria.",
            ],
        )

