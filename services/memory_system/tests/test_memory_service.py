from __future__ import annotations

from uuid import UUID

from alter_memory_system.repository import InMemoryMemoryRepository
from alter_memory_system.schemas import (
    MemoryItemCreate,
    MemoryIngestRequest,
    MemoryRetrieveRequest,
    MemorySearchRequest,
    MemoryType,
    PromoteShortTermRequest,
    ShortTermMemoryCreate,
)
from alter_memory_system.service import create_memory_service

USER_ID = UUID("11111111-1111-4111-8111-111111111111")


def test_create_search_and_retrieve_memory() -> None:
    service = create_memory_service(repository=InMemoryMemoryRepository())
    created = service.create_memory(
        MemoryItemCreate(
            user_id=USER_ID,
            memory_type=MemoryType.skill,
            title="Python systems engineering",
            summary="Strong at production Python services.",
            content="Built FastAPI services, agent orchestration, and backend APIs.",
            confidence=0.9,
            importance=0.8,
        )
    )

    search = service.search(
        MemorySearchRequest(
            user_id=USER_ID,
            query="production backend python",
            limit=5,
        )
    )
    retrieved = service.retrieve(
        MemoryRetrieveRequest(
            user_id=USER_ID,
            task="Find relevant engineering skills for a backend project.",
            limit=5,
        )
    )

    assert created.id == search.hits[0].memory.id
    assert retrieved.context[0].memory_id == created.id


def test_short_term_memory_can_be_promoted() -> None:
    service = create_memory_service(repository=InMemoryMemoryRepository())
    short_term = service.create_short_term(
        ShortTermMemoryCreate(
            user_id=USER_ID,
            key="current_focus",
            value={"focus": "Design ALTER memory"},
            summary="The user is currently designing ALTER's memory system.",
            importance=0.7,
        )
    )

    promoted = service.promote_short_term(
        PromoteShortTermRequest(
            user_id=USER_ID,
            short_term_memory_id=short_term.id,
            memory_type=MemoryType.goal,
            title="Design ALTER memory system",
            importance=0.8,
        )
    )

    assert promoted.memory_type == MemoryType.goal
    assert promoted.metadata["short_term_memory_id"] == str(short_term.id)


def test_classifier_defaults_to_forgetting_restricted_secrets() -> None:
    service = create_memory_service(repository=InMemoryMemoryRepository())

    result = service.ingest(
        MemoryIngestRequest(
            user_id=USER_ID,
            content="Your OTP is 482193. Do not share it.",
            source="sms",
        )
    )

    assert result.classification.should_store is False
    assert result.classification.sensitivity == "restricted"
    assert result.stored_memory is None
    assert result.raw_content_deleted is True


def test_confirmed_goal_becomes_durable_identity_evidence() -> None:
    service = create_memory_service(repository=InMemoryMemoryRepository())

    result = service.ingest(
        MemoryIngestRequest(
            user_id=USER_ID,
            content="My goal is to launch ALTER for private on-device assistance.",
            user_confirmed=True,
        )
    )
    identity = service.identity_snapshot(USER_ID)

    assert result.stored_memory is not None
    assert result.stored_memory.retention == "durable"
    assert identity.signals[0].label == "goal"


def test_unconfirmed_durable_signal_waits_for_confirmation() -> None:
    service = create_memory_service(repository=InMemoryMemoryRepository())

    result = service.ingest(
        MemoryIngestRequest(
            user_id=USER_ID,
            content="I prefer all important meetings in the morning.",
        )
    )

    assert result.classification.requires_confirmation is True
    assert result.stored_memory is None

