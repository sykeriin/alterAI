from __future__ import annotations

import json
from typing import Any, Protocol, TypeVar

from pydantic import BaseModel

from .config import Settings
from .prompts import (
    agent_system_prompt,
    challenge_prompt,
    consensus_prompt,
    independent_thinking_prompt,
    opinion_update_prompt,
)
from .schemas import (
    AgentChallenge,
    AgentChallengeSet,
    AgentOpinion,
    AgentSpec,
    ConsensusResult,
)

StructuredModel = TypeVar("StructuredModel", bound=BaseModel)


class CouncilModelClient(Protocol):
    async def generate_initial_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        context: dict[str, object],
    ) -> AgentOpinion:
        ...

    async def generate_challenges(
        self,
        *,
        agent: AgentSpec,
        question: str,
        peer_opinions: list[AgentOpinion],
        max_challenges: int,
    ) -> list[AgentChallenge]:
        ...

    async def update_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        original_opinion: AgentOpinion,
        received_challenges: list[AgentChallenge],
    ) -> AgentOpinion:
        ...

    async def generate_consensus(
        self,
        *,
        question: str,
        updated_opinions: list[AgentOpinion],
        challenges: list[AgentChallenge],
    ) -> ConsensusResult:
        ...


class OpenAICouncilModelClient:
    """OpenAI Responses API client with Pydantic structured output."""

    def __init__(self, settings: Settings) -> None:
        if not settings.openai_api_key:
            raise RuntimeError(
                "OPENAI_API_KEY is required when ALTER_CLONE_COUNCIL_ENV is not local."
            )
        self._settings = settings
        from openai import AsyncOpenAI

        self._client = AsyncOpenAI(
            api_key=settings.openai_api_key,
            max_retries=settings.openai_max_retries,
            timeout=settings.request_timeout_seconds,
        )

    async def generate_initial_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        context: dict[str, object],
    ) -> AgentOpinion:
        opinion = await self._structured_call(
            AgentOpinion,
            [
                ("system", agent_system_prompt(agent)),
                ("human", independent_thinking_prompt(question, context)),
            ],
        )
        return opinion.model_copy(
            update={"agent_id": agent.id, "agent_name": agent.name},
        )

    async def generate_challenges(
        self,
        *,
        agent: AgentSpec,
        question: str,
        peer_opinions: list[AgentOpinion],
        max_challenges: int,
    ) -> list[AgentChallenge]:
        peer_opinion_text = _dump_models(peer_opinions)
        challenge_set = await self._structured_call(
            AgentChallengeSet,
            [
                ("system", agent_system_prompt(agent)),
                (
                    "human",
                    challenge_prompt(
                        agent=agent,
                        question=question,
                        peer_opinions=peer_opinion_text,
                        max_challenges=max_challenges,
                    ),
                ),
            ],
        )
        valid_peer_ids = {opinion.agent_id for opinion in peer_opinions}
        normalized = []
        for challenge in challenge_set.challenges:
            if challenge.to_agent_id not in valid_peer_ids:
                continue
            normalized.append(
                challenge.model_copy(
                    update={
                        "from_agent_id": agent.id,
                        "from_agent_name": agent.name,
                    },
                )
            )
        return normalized[:max_challenges]

    async def update_opinion(
        self,
        *,
        agent: AgentSpec,
        question: str,
        original_opinion: AgentOpinion,
        received_challenges: list[AgentChallenge],
    ) -> AgentOpinion:
        opinion = await self._structured_call(
            AgentOpinion,
            [
                ("system", agent_system_prompt(agent)),
                (
                    "human",
                    opinion_update_prompt(
                        agent=agent,
                        question=question,
                        original_opinion=original_opinion.model_dump_json(indent=2),
                        received_challenges=_dump_models(received_challenges),
                    ),
                ),
            ],
        )
        return opinion.model_copy(
            update={"agent_id": agent.id, "agent_name": agent.name},
        )

    async def generate_consensus(
        self,
        *,
        question: str,
        updated_opinions: list[AgentOpinion],
        challenges: list[AgentChallenge],
    ) -> ConsensusResult:
        return await self._structured_call(
            ConsensusResult,
            [
                ("system", "You are ALTER's Consensus Engine."),
                (
                    "human",
                    consensus_prompt(
                        question=question,
                        updated_opinions=_dump_models(updated_opinions),
                        challenges=_dump_models(challenges),
                    ),
                ),
            ],
        )

    async def _structured_call(
        self,
        schema: type[StructuredModel],
        messages: list[tuple[str, str]],
    ) -> StructuredModel:
        response = await self._client.responses.parse(
            model=self._settings.openai_model,
            input=[
                {
                    "role": "system",
                    "content": [{"type": "input_text", "text": content}],
                }
                if role == "system"
                else {
                    "role": "user",
                    "content": [{"type": "input_text", "text": content}],
                }
                for role, content in messages
            ],
            text_format=schema,
            temperature=self._settings.openai_temperature,
        )
        payload: Any = getattr(response, "output_parsed", None)
        if isinstance(payload, schema):
            return payload
        if payload is None:
            payload = getattr(response, "output_text", "")
        if isinstance(payload, str):
            return schema.model_validate_json(payload)
        return schema.model_validate(payload)


def _dump_models(items: list[BaseModel]) -> str:
    return json.dumps(
        [item.model_dump(mode="json") for item in items],
        indent=2,
        ensure_ascii=True,
    )
