from __future__ import annotations

from functools import lru_cache
from uuid import UUID

from fastapi import FastAPI, HTTPException, Query

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    HealthResponse,
    IdentitySnapshotResponse,
    MemoryGovernanceResponse,
    MemoryIngestRequest,
    MemoryIngestResponse,
    MemoryItem,
    MemoryItemCreate,
    MemoryItemUpdate,
    MemoryRetrieveRequest,
    MemoryRetrieveResponse,
    MemorySearchRequest,
    MemorySearchResponse,
    PromoteShortTermRequest,
    PortableMemoryExport,
    ShortTermMemory,
    ShortTermMemoryCreate,
    TimelineResponse,
)
from .service import MemoryNotFoundError, MemoryService, create_memory_service

app = FastAPI(
    title="ALTER Memory System",
    version="0.1.0",
    description="Lifelong memory API with PostgreSQL and pgvector schema.",
)


@lru_cache(maxsize=1)
def get_service() -> MemoryService:
    return create_memory_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-memory-system",
        environment=settings.memory_env,
    )


@app.get("/v1/memory/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-memory-system",
        storage=[
            "PostgreSQL canonical memory tables",
            "pgvector HNSW semantic index",
            "short_term_memory TTL table",
            "typed detail tables for lifelong memory domains",
        ],
        capabilities=[
            "classifier-first ingestion",
            "encode, stabilize, store, retrieve, update, forget lifecycle",
            "long-term memory",
            "short-term memory",
            "semantic search",
            "memory retrieval",
            "memory updating",
            "short-term promotion",
            "relationship graph inside Postgres",
            "evidence-based identity snapshots",
            "governance and portable export",
        ],
        api_groups=[
            "classified ingestion",
            "memory item CRUD",
            "semantic search",
            "agent context retrieval",
            "short-term memory",
            "timeline",
            "governance, identity, and export",
        ],
    )


@app.post("/v1/memory/items", response_model=MemoryItem)
async def create_memory(payload: MemoryItemCreate) -> MemoryItem:
    return get_service().create_memory(payload)


@app.post("/v1/memory/ingest", response_model=MemoryIngestResponse)
async def ingest_memory(payload: MemoryIngestRequest) -> MemoryIngestResponse:
    return get_service().ingest(payload)


@app.get("/v1/memory/items/{memory_id}", response_model=MemoryItem)
async def get_memory(memory_id: UUID, user_id: UUID = Query(...)) -> MemoryItem:
    try:
        return get_service().get_memory(user_id, memory_id)
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail="memory not found") from exc


@app.patch("/v1/memory/items/{memory_id}", response_model=MemoryItem)
async def update_memory(
    memory_id: UUID,
    payload: MemoryItemUpdate,
    user_id: UUID = Query(...),
) -> MemoryItem:
    try:
        return get_service().update_memory(user_id, memory_id, payload)
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail="memory not found") from exc


@app.post("/v1/memory/items/{memory_id}/archive", response_model=MemoryItem)
async def archive_memory(memory_id: UUID, user_id: UUID = Query(...)) -> MemoryItem:
    try:
        return get_service().archive_memory(user_id, memory_id)
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail="memory not found") from exc


@app.post("/v1/memory/search", response_model=MemorySearchResponse)
async def search_memories(request: MemorySearchRequest) -> MemorySearchResponse:
    return get_service().search(request)


@app.post("/v1/memory/retrieve", response_model=MemoryRetrieveResponse)
async def retrieve_memory(request: MemoryRetrieveRequest) -> MemoryRetrieveResponse:
    return get_service().retrieve(request)


@app.post("/v1/memory/short-term", response_model=ShortTermMemory)
async def create_short_term_memory(payload: ShortTermMemoryCreate) -> ShortTermMemory:
    return get_service().create_short_term(payload)


@app.post("/v1/memory/short-term/promote", response_model=MemoryItem)
async def promote_short_term_memory(payload: PromoteShortTermRequest) -> MemoryItem:
    try:
        return get_service().promote_short_term(payload)
    except MemoryNotFoundError as exc:
        raise HTTPException(status_code=404, detail="short-term memory not found") from exc


@app.get("/v1/memory/users/{user_id}/timeline", response_model=TimelineResponse)
async def memory_timeline(
    user_id: UUID,
    limit: int = Query(default=25, ge=1, le=100),
) -> TimelineResponse:
    return get_service().timeline(user_id, limit)


@app.get("/v1/memory/users/{user_id}/governance", response_model=MemoryGovernanceResponse)
async def memory_governance(user_id: UUID) -> MemoryGovernanceResponse:
    return get_service().governance(user_id)


@app.get("/v1/memory/users/{user_id}/identity", response_model=IdentitySnapshotResponse)
async def memory_identity(user_id: UUID) -> IdentitySnapshotResponse:
    return get_service().identity_snapshot(user_id)


@app.get("/v1/memory/users/{user_id}/export", response_model=PortableMemoryExport)
async def memory_export(user_id: UUID) -> PortableMemoryExport:
    return get_service().portable_export(user_id)
