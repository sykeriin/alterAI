from __future__ import annotations

import math
from collections.abc import Iterable
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID

from .schemas import (
    MemoryItem,
    MemoryItemCreate,
    MemoryItemUpdate,
    MemoryPrivacy,
    MemorySearchHit,
    MemorySearchRequest,
    MemoryStatus,
    ShortTermMemory,
)


class MemoryRepository(Protocol):
    def create_memory(self, payload: MemoryItemCreate) -> MemoryItem:
        ...

    def get_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem | None:
        ...

    def update_memory(
        self,
        user_id: UUID,
        memory_id: UUID,
        payload: MemoryItemUpdate,
    ) -> MemoryItem | None:
        ...

    def archive_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem | None:
        ...

    def search(self, request: MemorySearchRequest) -> list[MemorySearchHit]:
        ...

    def recent(self, user_id: UUID, limit: int) -> list[MemoryItem]:
        ...

    def all_memories(self, user_id: UUID) -> list[MemoryItem]:
        ...

    def create_short_term(self, memory: ShortTermMemory) -> ShortTermMemory:
        ...

    def get_short_term(self, user_id: UUID, memory_id: UUID) -> ShortTermMemory | None:
        ...

    def mark_promoted(
        self,
        user_id: UUID,
        short_term_memory_id: UUID,
        promoted_memory_id: UUID,
    ) -> None:
        ...


class InMemoryMemoryRepository:
    """Contract-test repository. Production implementation should use PostgreSQL."""

    def __init__(self) -> None:
        self._memories: dict[UUID, MemoryItem] = {}
        self._short_term: dict[UUID, ShortTermMemory] = {}

    def create_memory(self, payload: MemoryItemCreate) -> MemoryItem:
        memory = MemoryItem(
            user_id=payload.user_id,
            memory_type=payload.memory_type,
            title=payload.title,
            summary=payload.summary,
            content=payload.content,
            source=payload.source,
            privacy=payload.privacy,
            retention=payload.retention,
            sensitivity=payload.sensitivity,
            lifecycle_stage=payload.lifecycle_stage,
            requires_confirmation=payload.requires_confirmation,
            confidence=payload.confidence,
            importance=payload.importance,
            emotional_valence=payload.emotional_valence,
            metadata=payload.metadata,
            embedding=payload.embedding,
            valid_from=payload.valid_from,
            valid_until=payload.valid_until,
            expires_at=payload.expires_at,
            pinned=payload.pinned,
        )
        self._memories[memory.id] = memory
        return memory

    def get_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem | None:
        memory = self._memories.get(memory_id)
        if memory is None or memory.user_id != user_id:
            return None
        accessed = memory.model_copy(
            update={
                "access_count": memory.access_count + 1,
                "last_accessed_at": datetime.now(UTC),
            }
        )
        self._memories[memory_id] = accessed
        return accessed

    def update_memory(
        self,
        user_id: UUID,
        memory_id: UUID,
        payload: MemoryItemUpdate,
    ) -> MemoryItem | None:
        memory = self.get_memory(user_id, memory_id)
        if memory is None:
            return None
        updates = payload.model_dump(exclude_unset=True)
        updates["updated_at"] = datetime.now(UTC)
        updated = memory.model_copy(update=updates)
        self._memories[memory_id] = updated
        return updated

    def archive_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem | None:
        memory = self.get_memory(user_id, memory_id)
        if memory is None:
            return None
        archived = memory.model_copy(
            update={
                "status": MemoryStatus.archived,
                "archived_at": datetime.now(UTC),
                "updated_at": datetime.now(UTC),
            }
        )
        self._memories[memory_id] = archived
        return archived

    def search(self, request: MemorySearchRequest) -> list[MemorySearchHit]:
        memories = [
            memory
            for memory in self._memories.values()
            if memory.user_id == request.user_id
            and memory.status == MemoryStatus.active
            and (
                not request.memory_types
                or memory.memory_type in set(request.memory_types)
            )
            and memory.privacy in {MemoryPrivacy.agent_visible, MemoryPrivacy.shareable}
        ]
        hits = [
            MemorySearchHit(
                memory=memory,
                similarity=_similarity(memory, request),
                reason="semantic vector match"
                if request.query_embedding and memory.embedding
                else "lexical and importance match",
            )
            for memory in memories
        ]
        hits = [hit for hit in hits if hit.similarity >= request.min_similarity]
        return sorted(
            hits,
            key=lambda hit: (
                hit.similarity,
                hit.memory.importance,
                hit.memory.updated_at,
            ),
            reverse=True,
        )[: request.limit]

    def recent(self, user_id: UUID, limit: int) -> list[MemoryItem]:
        memories = [
            memory
            for memory in self._memories.values()
            if memory.user_id == user_id and memory.status == MemoryStatus.active
        ]
        return sorted(memories, key=lambda memory: memory.updated_at, reverse=True)[:limit]

    def all_memories(self, user_id: UUID) -> list[MemoryItem]:
        return [
            memory
            for memory in self._memories.values()
            if memory.user_id == user_id and memory.status != MemoryStatus.deleted
        ]

    def create_short_term(self, memory: ShortTermMemory) -> ShortTermMemory:
        self._short_term[memory.id] = memory
        return memory

    def get_short_term(self, user_id: UUID, memory_id: UUID) -> ShortTermMemory | None:
        memory = self._short_term.get(memory_id)
        if memory is None or memory.user_id != user_id:
            return None
        if memory.expires_at <= datetime.now(UTC):
            return None
        return memory

    def mark_promoted(
        self,
        user_id: UUID,
        short_term_memory_id: UUID,
        promoted_memory_id: UUID,
    ) -> None:
        memory = self.get_short_term(user_id, short_term_memory_id)
        if memory is not None:
            self._short_term[short_term_memory_id] = memory.model_copy(
                update={"promoted_memory_id": promoted_memory_id}
            )


def _similarity(memory: MemoryItem, request: MemorySearchRequest) -> float:
    if request.query_embedding and memory.embedding:
        return _cosine_similarity(memory.embedding, request.query_embedding)
    query_terms = set(_terms(request.query))
    memory_terms = set(_terms(" ".join([memory.title, memory.summary, memory.content])))
    if not query_terms:
        return memory.importance
    lexical = len(query_terms & memory_terms) / max(len(query_terms), 1)
    return min(1.0, lexical * 0.74 + memory.importance * 0.26)


def _cosine_similarity(left: list[float], right: list[float]) -> float:
    if len(left) != len(right):
        return 0.0
    dot = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        return 0.0
    return max(0.0, min(1.0, (dot / (left_norm * right_norm) + 1) / 2))


def _terms(text: str) -> Iterable[str]:
    for raw in text.lower().replace("-", " ").split():
        term = "".join(char for char in raw if char.isalnum())
        if len(term) > 2:
            yield term
