from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PersonRole(StrEnum):
    user = "User"
    founder = "Founder"
    recruiter = "Recruiter"
    professor = "Professor"
    student = "Student"
    investor = "Investor"


class RelationshipType(StrEnum):
    knows = "KNOWS"
    worked_with = "WORKED_WITH"
    studied_with = "STUDIED_WITH"
    mentored_by = "MENTORED_BY"
    interested_in = "INTERESTED_IN"


class PersonCreate(BaseModel):
    role: PersonRole
    name: str = Field(min_length=2, max_length=160)
    email: str | None = Field(default=None, max_length=240)
    headline: str | None = Field(default=None, max_length=280)
    organization: str | None = Field(default=None, max_length=180)
    location: str | None = Field(default=None, max_length=160)
    skills: list[str] = Field(default_factory=list, max_length=80)
    interests: list[str] = Field(default_factory=list, max_length=80)
    goals: list[str] = Field(default_factory=list, max_length=40)
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("skills", "interests", "goals")
    @classmethod
    def normalize_terms(cls, values: list[str]) -> list[str]:
        seen = set()
        normalized = []
        for value in values:
            clean = " ".join(value.strip().split())
            key = clean.lower()
            if clean and key not in seen:
                normalized.append(clean)
                seen.add(key)
        return normalized


class Person(PersonCreate):
    model_config = ConfigDict(use_enum_values=True)

    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class RelationshipCreate(BaseModel):
    from_person_id: UUID
    to_person_id: UUID
    relationship_type: RelationshipType
    strength: float = Field(default=0.5, ge=0.0, le=1.0)
    context: str | None = Field(default=None, max_length=1000)
    metadata: dict[str, Any] = Field(default_factory=dict)


class GraphRelationship(RelationshipCreate):
    model_config = ConfigDict(use_enum_values=True)

    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class MutualConnectionsRequest(BaseModel):
    person_a_id: UUID
    person_b_id: UUID
    max_depth: int = Field(default=2, ge=2, le=4)
    limit: int = Field(default=20, ge=1, le=100)


class MutualConnection(BaseModel):
    person: Person
    connection_strength: float = Field(ge=0.0, le=1.0)
    via_relationships: list[RelationshipType]


class MutualConnectionsResponse(BaseModel):
    mutual_connections: list[MutualConnection]


class CareerPathRequest(BaseModel):
    start_person_id: UUID
    target_role: PersonRole
    required_skills: list[str] = Field(default_factory=list, max_length=40)
    max_depth: int = Field(default=4, ge=1, le=6)
    limit: int = Field(default=10, ge=1, le=50)


class CareerPath(BaseModel):
    people: list[Person]
    relationships: list[RelationshipType]
    score: float = Field(ge=0.0, le=100.0)
    rationale: list[str]


class CareerPathResponse(BaseModel):
    paths: list[CareerPath]


class RecruiterDiscoveryRequest(BaseModel):
    person_id: UUID
    target_skills: list[str] = Field(default_factory=list, max_length=40)
    locations: list[str] = Field(default_factory=list, max_length=20)
    limit: int = Field(default=10, ge=1, le=50)


class MentorDiscoveryRequest(BaseModel):
    person_id: UUID
    target_interests: list[str] = Field(default_factory=list, max_length=40)
    target_skills: list[str] = Field(default_factory=list, max_length=40)
    limit: int = Field(default=10, ge=1, le=50)


class DiscoveryCandidate(BaseModel):
    person: Person
    score: float = Field(ge=0.0, le=100.0)
    mutual_connection_count: int
    reasons: list[str]


class DiscoveryResponse(BaseModel):
    candidates: list[DiscoveryCandidate]


class TeamFormationRequest(BaseModel):
    seed_person_id: UUID
    required_roles: list[PersonRole] = Field(default_factory=list, max_length=10)
    required_skills: list[str] = Field(default_factory=list, max_length=40)
    team_size: int = Field(default=4, ge=2, le=12)


class TeamMemberRecommendation(BaseModel):
    person: Person
    role_fit: float = Field(ge=0.0, le=1.0)
    skill_coverage: list[str]
    relationship_distance: int
    reasons: list[str]


class TeamFormationResponse(BaseModel):
    members: list[TeamMemberRecommendation]
    covered_skills: list[str]
    missing_skills: list[str]


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ArchitectureResponse(BaseModel):
    service: str
    graph_database: str
    nodes: list[str]
    relationships: list[str]
    features: list[str]

