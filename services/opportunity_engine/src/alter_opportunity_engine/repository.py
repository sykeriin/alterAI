from __future__ import annotations

from typing import Protocol
from uuid import UUID

from .schemas import Opportunity


class OpportunityRepository(Protocol):
    def upsert_many(self, opportunities: list[Opportunity]) -> list[Opportunity]:
        ...

    def list(self, limit: int = 100) -> list[Opportunity]:
        ...


class InMemoryOpportunityRepository:
    def __init__(self) -> None:
        self._items: dict[UUID, Opportunity] = {}

    def upsert_many(self, opportunities: list[Opportunity]) -> list[Opportunity]:
        for opportunity in opportunities:
            self._items[opportunity.id] = opportunity
        return opportunities

    def list(self, limit: int = 100) -> list[Opportunity]:
        return sorted(
            self._items.values(),
            key=lambda opportunity: opportunity.updated_at,
            reverse=True,
        )[:limit]

