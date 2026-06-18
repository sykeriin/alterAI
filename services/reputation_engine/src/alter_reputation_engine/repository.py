from __future__ import annotations

from collections import defaultdict
from typing import Protocol
from uuid import UUID

from .schemas import ReputationEvent, ReputationEventCreate


class ReputationRepository(Protocol):
    def create_event(self, payload: ReputationEventCreate) -> ReputationEvent:
        ...

    def list_events(self, user_id: UUID) -> list[ReputationEvent]:
        ...


class InMemoryReputationRepository:
    def __init__(self) -> None:
        self._events: dict[UUID, list[ReputationEvent]] = defaultdict(list)

    def create_event(self, payload: ReputationEventCreate) -> ReputationEvent:
        event = ReputationEvent(**payload.model_dump())
        self._events[event.user_id].append(event)
        return event

    def list_events(self, user_id: UUID) -> list[ReputationEvent]:
        return sorted(
            self._events.get(user_id, []),
            key=lambda event: event.occurred_at,
            reverse=True,
        )
