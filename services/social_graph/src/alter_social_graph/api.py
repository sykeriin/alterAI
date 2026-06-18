from __future__ import annotations

from functools import lru_cache
from uuid import UUID

from fastapi import FastAPI, HTTPException

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    CareerPathRequest,
    CareerPathResponse,
    DiscoveryResponse,
    HealthResponse,
    MentorDiscoveryRequest,
    MutualConnectionsRequest,
    MutualConnectionsResponse,
    Person,
    PersonCreate,
    PersonRole,
    RecruiterDiscoveryRequest,
    RelationshipCreate,
    RelationshipType,
    TeamFormationRequest,
    TeamFormationResponse,
)
from .service import (
    SocialGraphNotFoundError,
    SocialGraphService,
    create_social_graph_service,
)

app = FastAPI(
    title="ALTER Social Graph Engine",
    version="0.1.0",
    description="Neo4j-backed relationship intelligence service for ALTER.",
)


@lru_cache(maxsize=1)
def get_service() -> SocialGraphService:
    return create_social_graph_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-social-graph",
        environment=settings.social_graph_env,
    )


@app.get("/v1/social-graph/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-social-graph",
        graph_database="Neo4j",
        nodes=[role.value for role in PersonRole],
        relationships=[relationship.value for relationship in RelationshipType],
        features=[
            "mutual connections",
            "career path discovery",
            "recruiter discovery",
            "mentor discovery",
            "team formation",
        ],
    )


@app.post("/v1/social-graph/people", response_model=Person)
async def upsert_person(payload: PersonCreate) -> Person:
    return get_service().upsert_person(payload)


@app.get("/v1/social-graph/people/{person_id}", response_model=Person)
async def get_person(person_id: UUID) -> Person:
    try:
        return get_service().get_person(person_id)
    except SocialGraphNotFoundError as exc:
        raise HTTPException(status_code=404, detail="person not found") from exc


@app.post("/v1/social-graph/relationships")
async def create_relationship(payload: RelationshipCreate):
    try:
        return get_service().create_relationship(payload)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="relationship endpoint not found") from exc


@app.post("/v1/social-graph/mutual-connections", response_model=MutualConnectionsResponse)
async def mutual_connections(request: MutualConnectionsRequest) -> MutualConnectionsResponse:
    return get_service().mutual_connections(request)


@app.post("/v1/social-graph/career-paths", response_model=CareerPathResponse)
async def career_paths(request: CareerPathRequest) -> CareerPathResponse:
    return get_service().career_paths(request)


@app.post("/v1/social-graph/discover/recruiters", response_model=DiscoveryResponse)
async def discover_recruiters(request: RecruiterDiscoveryRequest) -> DiscoveryResponse:
    try:
        return get_service().discover_recruiters(request)
    except SocialGraphNotFoundError as exc:
        raise HTTPException(status_code=404, detail="person not found") from exc


@app.post("/v1/social-graph/discover/mentors", response_model=DiscoveryResponse)
async def discover_mentors(request: MentorDiscoveryRequest) -> DiscoveryResponse:
    try:
        return get_service().discover_mentors(request)
    except SocialGraphNotFoundError as exc:
        raise HTTPException(status_code=404, detail="person not found") from exc


@app.post("/v1/social-graph/team-formation", response_model=TeamFormationResponse)
async def team_formation(request: TeamFormationRequest) -> TeamFormationResponse:
    try:
        return get_service().form_team(request)
    except SocialGraphNotFoundError as exc:
        raise HTTPException(status_code=404, detail="person not found") from exc

