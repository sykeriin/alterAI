from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from typing import Any, TypedDict

from langgraph.graph import END, START, StateGraph

from .agents import DEFAULT_AGENT_SPECS
from .config import Settings
from .model_client import CouncilModelClient
from .schemas import (
    AgentChallenge,
    AgentOpinion,
    AgentSpec,
    ConsensusResult,
    TranscriptEntry,
    TranscriptEventType,
)


class DebateState(TypedDict, total=False):
    debate_id: str
    question: str
    context: dict[str, Any]
    agents: list[AgentSpec]
    max_challenges_per_agent: int
    started_at: datetime
    initial_opinions: dict[str, AgentOpinion]
    challenges: list[AgentChallenge]
    updated_opinions: dict[str, AgentOpinion]
    consensus: ConsensusResult
    transcript: list[TranscriptEntry]


def build_clone_council_graph(
    *,
    model_client: CouncilModelClient,
    settings: Settings,
):
    """Build and compile the ALTER Clone Council LangGraph."""

    async def think_independently(state: DebateState) -> DebateState:
        agents = state.get("agents", list(DEFAULT_AGENT_SPECS))
        opinions = await asyncio.gather(
            *[
                model_client.generate_initial_opinion(
                    agent=agent,
                    question=state["question"],
                    context=state.get("context", {}),
                )
                for agent in agents
            ]
        )
        opinion_map = {opinion.agent_id: opinion for opinion in opinions}
        transcript = list(state.get("transcript", []))
        transcript.extend(_opinion_entries(opinions, TranscriptEventType.thought))
        return {"initial_opinions": opinion_map, "transcript": transcript}

    async def challenge_other_agents(state: DebateState) -> DebateState:
        agents = state.get("agents", list(DEFAULT_AGENT_SPECS))
        opinions = list(state.get("initial_opinions", {}).values())
        max_challenges = state.get(
            "max_challenges_per_agent",
            settings.max_challenges_per_agent,
        )
        challenge_batches = await asyncio.gather(
            *[
                model_client.generate_challenges(
                    agent=agent,
                    question=state["question"],
                    peer_opinions=[
                        opinion for opinion in opinions if opinion.agent_id != agent.id
                    ],
                    max_challenges=max_challenges,
                )
                for agent in agents
            ]
        )
        challenges = [
            challenge
            for challenge_batch in challenge_batches
            for challenge in challenge_batch
        ]
        transcript = list(state.get("transcript", []))
        transcript.extend(_challenge_entries(challenges))
        return {"challenges": challenges, "transcript": transcript}

    async def update_opinions(state: DebateState) -> DebateState:
        agents = state.get("agents", list(DEFAULT_AGENT_SPECS))
        initial_opinions = state.get("initial_opinions", {})
        challenges = state.get("challenges", [])

        updated = await asyncio.gather(
            *[
                model_client.update_opinion(
                    agent=agent,
                    question=state["question"],
                    original_opinion=initial_opinions[agent.id],
                    received_challenges=[
                        challenge
                        for challenge in challenges
                        if challenge.to_agent_id == agent.id
                    ],
                )
                for agent in agents
            ]
        )
        updated_map = {opinion.agent_id: opinion for opinion in updated}
        transcript = list(state.get("transcript", []))
        transcript.extend(_opinion_entries(updated, TranscriptEventType.revision))
        return {"updated_opinions": updated_map, "transcript": transcript}

    async def create_consensus(state: DebateState) -> DebateState:
        consensus = await model_client.generate_consensus(
            question=state["question"],
            updated_opinions=list(state.get("updated_opinions", {}).values()),
            challenges=state.get("challenges", []),
        )
        transcript = list(state.get("transcript", []))
        transcript.append(
            TranscriptEntry(
                event_type=TranscriptEventType.consensus,
                content=consensus.final_recommendation,
                metadata={
                    "confidence_score": consensus.confidence_score,
                    "risks": consensus.risks,
                    "opportunities": consensus.opportunities,
                },
            )
        )
        return {"consensus": consensus, "transcript": transcript}

    workflow = StateGraph(DebateState)
    workflow.add_node("think_independently", think_independently)
    workflow.add_node("challenge_other_agents", challenge_other_agents)
    workflow.add_node("update_opinions", update_opinions)
    workflow.add_node("consensus_engine", create_consensus)

    workflow.add_edge(START, "think_independently")
    workflow.add_edge("think_independently", "challenge_other_agents")
    workflow.add_edge("challenge_other_agents", "update_opinions")
    workflow.add_edge("update_opinions", "consensus_engine")
    workflow.add_edge("consensus_engine", END)

    return workflow.compile()


def initial_state(
    *,
    debate_id: str,
    question: str,
    context: dict[str, Any],
    max_challenges_per_agent: int,
) -> DebateState:
    return DebateState(
        debate_id=debate_id,
        question=question,
        context=context,
        agents=list(DEFAULT_AGENT_SPECS),
        max_challenges_per_agent=max_challenges_per_agent,
        started_at=datetime.now(UTC),
        transcript=[],
    )


def _opinion_entries(
    opinions: list[AgentOpinion],
    event_type: TranscriptEventType,
) -> list[TranscriptEntry]:
    return [
        TranscriptEntry(
            event_type=event_type,
            agent_id=opinion.agent_id,
            agent_name=opinion.agent_name,
            content=(
                f"Stance: {opinion.stance}\n"
                f"Recommendation: {opinion.recommendation}\n"
                f"Reasoning: {'; '.join(opinion.reasoning)}"
            ),
            metadata={
                "confidence": opinion.confidence,
                "assumptions": opinion.assumptions,
                "risks": opinion.risks,
                "opportunities": opinion.opportunities,
            },
        )
        for opinion in opinions
    ]


def _challenge_entries(challenges: list[AgentChallenge]) -> list[TranscriptEntry]:
    return [
        TranscriptEntry(
            event_type=TranscriptEventType.challenge,
            agent_id=challenge.from_agent_id,
            agent_name=challenge.from_agent_name,
            content=(
                f"Challenged {challenge.to_agent_name}: {challenge.challenge}\n"
                f"Suggested revision: {challenge.suggested_revision}"
            ),
            metadata={
                "to_agent_id": challenge.to_agent_id,
                "to_agent_name": challenge.to_agent_name,
                "target_claim": challenge.target_claim,
                "severity": challenge.severity,
            },
        )
        for challenge in challenges
    ]

