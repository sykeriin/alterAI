from __future__ import annotations

from collections import Counter
from uuid import UUID

from .classifier import MemoryClassifier
from .config import Settings, get_settings
from .repository import InMemoryMemoryRepository, MemoryRepository
from .schemas import (
    MemoryContextBlock,
    IdentitySignal,
    IdentitySnapshotResponse,
    MemoryGovernanceResponse,
    MemoryIngestRequest,
    MemoryIngestResponse,
    MemoryItem,
    MemoryItemCreate,
    MemoryItemUpdate,
    MemoryLifecycleStage,
    MemoryPolicy,
    MemoryPrivacy,
    MemoryRetrieveRequest,
    MemoryRetrieveResponse,
    MemoryRetention,
    MemorySearchRequest,
    MemorySearchResponse,
    PortableMemoryExport,
    PromoteShortTermRequest,
    ShortTermMemory,
    ShortTermMemoryCreate,
    TimelineResponse,
)


class MemoryNotFoundError(LookupError):
    pass


class MemoryService:
    def __init__(self, *, settings: Settings, repository: MemoryRepository) -> None:
        self._settings = settings
        self._repository = repository
        self._classifier = MemoryClassifier()
        self._policy = MemoryPolicy()

    def create_memory(self, payload: MemoryItemCreate) -> MemoryItem:
        return self._repository.create_memory(payload)

    def get_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem:
        memory = self._repository.get_memory(user_id, memory_id)
        if memory is None:
            raise MemoryNotFoundError(str(memory_id))
        return memory

    def update_memory(
        self,
        user_id: UUID,
        memory_id: UUID,
        payload: MemoryItemUpdate,
    ) -> MemoryItem:
        memory = self._repository.update_memory(user_id, memory_id, payload)
        if memory is None:
            raise MemoryNotFoundError(str(memory_id))
        return memory

    def archive_memory(self, user_id: UUID, memory_id: UUID) -> MemoryItem:
        memory = self._repository.archive_memory(user_id, memory_id)
        if memory is None:
            raise MemoryNotFoundError(str(memory_id))
        return memory

    def search(self, request: MemorySearchRequest) -> MemorySearchResponse:
        return MemorySearchResponse(
            query=request.query,
            hits=self._repository.search(request),
        )

    def retrieve(self, request: MemoryRetrieveRequest) -> MemoryRetrieveResponse:
        search_request = MemorySearchRequest(
            user_id=request.user_id,
            query=request.task,
            query_embedding=request.query_embedding,
            memory_types=request.memory_types,
            include_short_term=True,
            limit=request.limit,
        )
        hits = self._repository.search(search_request)
        context: list[MemoryContextBlock] = []
        context_chars = 0
        max_chars = min(request.max_context_chars, self._policy.max_retrieval_chars)
        for hit in hits:
            if not request.include_private and hit.memory.privacy == "private":
                continue
            block = MemoryContextBlock(
                memory_id=hit.memory.id,
                memory_type=hit.memory.memory_type,
                title=hit.memory.title,
                summary=hit.memory.summary,
                content=hit.memory.content,
                relevance=hit.similarity,
                confidence=hit.memory.confidence,
                importance=hit.memory.importance,
            )
            block_chars = len(block.title) + len(block.summary) + len(block.content)
            if context and context_chars + block_chars > max_chars:
                break
            context.append(block)
            context_chars += block_chars
        return MemoryRetrieveResponse(
            task=request.task,
            context=context,
            retrieval_notes=[
                "Ranked by semantic similarity when embeddings are supplied.",
                "Falls back to lexical overlap, importance, and recency without embeddings.",
                f"Context package limited to {max_chars} characters.",
            ],
            context_chars=context_chars,
        )

    def ingest(self, request: MemoryIngestRequest) -> MemoryIngestResponse:
        classification = self._classifier.classify(request)
        if not classification.should_store:
            return MemoryIngestResponse(classification=classification)

        abstract = _abstract_content(request.content)
        if classification.retention in {MemoryRetention.session, MemoryRetention.expiring}:
            short_term = self.create_short_term(
                ShortTermMemoryCreate(
                    user_id=request.user_id,
                    session_id=request.session_id,
                    key=f"{classification.memory_type.value}_signal",
                    value={
                        "abstract": abstract,
                        "source": request.source,
                        "metadata": request.metadata,
                    },
                    summary=abstract,
                    importance=classification.importance,
                    ttl_minutes=classification.expires_in_minutes,
                )
            )
            return MemoryIngestResponse(
                classification=classification,
                short_term_memory=short_term,
            )

        stored = self.create_memory(
            MemoryItemCreate(
                user_id=request.user_id,
                memory_type=classification.memory_type,
                title=_memory_title(classification.memory_type.value, abstract),
                summary=abstract,
                content=abstract,
                source=request.source,
                privacy=MemoryPrivacy.private
                if classification.sensitivity != "normal"
                else MemoryPrivacy.agent_visible,
                retention=classification.retention,
                sensitivity=classification.sensitivity,
                lifecycle_stage=MemoryLifecycleStage.stabilized,
                confidence=classification.confidence,
                importance=classification.importance,
                metadata={
                    **request.metadata,
                    "classifier_rationale": classification.rationale,
                    "raw_content_deleted": True,
                },
            )
        )
        return MemoryIngestResponse(classification=classification, stored_memory=stored)

    def governance(self, user_id: UUID) -> MemoryGovernanceResponse:
        memories = self._repository.all_memories(user_id)
        counts = Counter(str(memory.retention) for memory in memories)
        return MemoryGovernanceResponse(
            user_id=user_id,
            policy=self._policy,
            memory_counts=dict(counts),
            lifecycle=["encode", "stabilize", "store", "retrieve", "update", "forget"],
            user_controls=[
                "inspect",
                "correct",
                "confirm durable memory",
                "change retention",
                "change sharing scope",
                "export",
                "delete",
            ],
        )

    def identity_snapshot(self, user_id: UUID) -> IdentitySnapshotResponse:
        memories = [
            memory
            for memory in self._repository.all_memories(user_id)
            if memory.status == "active"
            and memory.retention == "durable"
            and memory.confidence >= 0.6
        ]
        grouped: dict[str, list[MemoryItem]] = {}
        for memory in memories:
            grouped.setdefault(str(memory.memory_type), []).append(memory)
        signals = [
            IdentitySignal(
                label=memory_type,
                evidence_count=len(evidence),
                confidence=min(
                    1.0,
                    sum(memory.confidence for memory in evidence) / len(evidence),
                ),
                evidence_memory_ids=[memory.id for memory in evidence],
            )
            for memory_type, evidence in sorted(grouped.items())
        ]
        return IdentitySnapshotResponse(user_id=user_id, signals=signals)

    def portable_export(self, user_id: UUID) -> PortableMemoryExport:
        memories = [
            memory
            for memory in self._repository.all_memories(user_id)
            if memory.privacy == "shareable"
        ]
        return PortableMemoryExport(
            user_id=user_id,
            memories=memories,
            identity=self.identity_snapshot(user_id),
            policy=self._policy,
        )

    def create_short_term(self, payload: ShortTermMemoryCreate) -> ShortTermMemory:
        memory = ShortTermMemory.from_create(
            payload,
            default_ttl_minutes=self._settings.short_term_ttl_minutes,
        )
        return self._repository.create_short_term(memory)

    def promote_short_term(self, payload: PromoteShortTermRequest) -> MemoryItem:
        short_term = self._repository.get_short_term(
            payload.user_id,
            payload.short_term_memory_id,
        )
        if short_term is None:
            raise MemoryNotFoundError(str(payload.short_term_memory_id))
        memory = self.create_memory(
            MemoryItemCreate(
                user_id=payload.user_id,
                memory_type=payload.memory_type,
                title=payload.title,
                summary=short_term.summary,
                content=str(short_term.value),
                source="short_term_promotion",
                confidence=payload.confidence,
                importance=payload.importance,
                metadata={
                    **payload.metadata,
                    "short_term_memory_id": str(short_term.id),
                    "key": short_term.key,
                },
            )
        )
        self._repository.mark_promoted(payload.user_id, short_term.id, memory.id)
        return memory

    def timeline(self, user_id: UUID, limit: int) -> TimelineResponse:
        return TimelineResponse(
            user_id=user_id,
            memories=self._repository.recent(user_id, limit),
        )


def create_memory_service(
    *,
    settings: Settings | None = None,
    repository: MemoryRepository | None = None,
) -> MemoryService:
    return MemoryService(
        settings=settings or get_settings(),
        repository=repository or InMemoryMemoryRepository(),
    )


def _abstract_content(content: str) -> str:
    compact = " ".join(content.split())
    return compact[:500]


def _memory_title(memory_type: str, abstract: str) -> str:
    words = abstract.split()
    preview = " ".join(words[:8])
    return f"{memory_type.replace('_', ' ').title()}: {preview}"[:240]

