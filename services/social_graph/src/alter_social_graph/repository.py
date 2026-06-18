from __future__ import annotations

from collections import deque
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID

from neo4j import GraphDatabase

from .config import Settings
from .schemas import (
    GraphRelationship,
    Person,
    PersonCreate,
    PersonRole,
    RelationshipCreate,
    RelationshipType,
)


class SocialGraphRepository(Protocol):
    def upsert_person(self, payload: PersonCreate) -> Person:
        ...

    def get_person(self, person_id: UUID) -> Person | None:
        ...

    def create_relationship(self, payload: RelationshipCreate) -> GraphRelationship:
        ...

    def list_people(self) -> list[Person]:
        ...

    def list_relationships(self) -> list[GraphRelationship]:
        ...


class InMemorySocialGraphRepository:
    def __init__(self) -> None:
        self.people: dict[UUID, Person] = {}
        self.relationships: dict[UUID, GraphRelationship] = {}

    def upsert_person(self, payload: PersonCreate) -> Person:
        person = Person(**payload.model_dump())
        self.people[person.id] = person
        return person

    def get_person(self, person_id: UUID) -> Person | None:
        return self.people.get(person_id)

    def create_relationship(self, payload: RelationshipCreate) -> GraphRelationship:
        if payload.from_person_id not in self.people or payload.to_person_id not in self.people:
            raise KeyError("relationship endpoints must exist")
        relationship = GraphRelationship(**payload.model_dump())
        self.relationships[relationship.id] = relationship
        return relationship

    def list_people(self) -> list[Person]:
        return list(self.people.values())

    def list_relationships(self) -> list[GraphRelationship]:
        return list(self.relationships.values())

    def neighbors(self, person_id: UUID) -> list[tuple[Person, GraphRelationship]]:
        results = []
        for relationship in self.relationships.values():
            if relationship.from_person_id == person_id:
                person = self.people.get(relationship.to_person_id)
            elif relationship.to_person_id == person_id:
                person = self.people.get(relationship.from_person_id)
            else:
                person = None
            if person is not None:
                results.append((person, relationship))
        return results

    def shortest_distance(self, start: UUID, target: UUID, max_depth: int = 4) -> int | None:
        if start == target:
            return 0
        visited = {start}
        queue = deque([(start, 0)])
        while queue:
            person_id, depth = queue.popleft()
            if depth >= max_depth:
                continue
            for neighbor, _relationship in self.neighbors(person_id):
                if neighbor.id == target:
                    return depth + 1
                if neighbor.id not in visited:
                    visited.add(neighbor.id)
                    queue.append((neighbor.id, depth + 1))
        return None

    def paths_to_role(
        self,
        start: UUID,
        target_role: PersonRole,
        max_depth: int,
    ) -> list[tuple[list[Person], list[GraphRelationship]]]:
        paths: list[tuple[list[Person], list[GraphRelationship]]] = []
        start_person = self.people.get(start)
        if start_person is None:
            return paths
        queue = deque([(start_person, [start_person], [])])
        while queue:
            current, people_path, rel_path = queue.popleft()
            if len(rel_path) > max_depth:
                continue
            if current.id != start and current.role == target_role:
                paths.append((people_path, rel_path))
                continue
            if len(rel_path) == max_depth:
                continue
            seen = {person.id for person in people_path}
            for neighbor, relationship in self.neighbors(current.id):
                if neighbor.id not in seen:
                    queue.append((neighbor, [*people_path, neighbor], [*rel_path, relationship]))
        return paths


class Neo4jSocialGraphRepository:
    """Neo4j repository. Tests use the in-memory repository."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._driver = GraphDatabase.driver(
            settings.neo4j_uri,
            auth=(settings.neo4j_user, settings.neo4j_password),
        )

    def close(self) -> None:
        self._driver.close()

    def upsert_person(self, payload: PersonCreate) -> Person:
        person = Person(**payload.model_dump())
        label = _label(person.role)
        query = f"""
        MERGE (p:Person:{label} {{id: $id}})
        SET p.name = $name,
            p.email = $email,
            p.headline = $headline,
            p.organization = $organization,
            p.location = $location,
            p.skills = $skills,
            p.interests = $interests,
            p.goals = $goals,
            p.metadata = $metadata,
            p.role = $role,
            p.updated_at = datetime($updated_at)
        SET p.created_at = coalesce(p.created_at, datetime($created_at))
        RETURN p
        """
        self._driver.execute_query(
            query,
            database_=self._settings.neo4j_database,
            **_person_params(person),
        )
        return person

    def get_person(self, person_id: UUID) -> Person | None:
        records, _summary, _keys = self._driver.execute_query(
            "MATCH (p:Person {id: $id}) RETURN p LIMIT 1",
            id=str(person_id),
            database_=self._settings.neo4j_database,
        )
        if not records:
            return None
        return _person_from_node(records[0]["p"])

    def create_relationship(self, payload: RelationshipCreate) -> GraphRelationship:
        relationship = GraphRelationship(**payload.model_dump())
        rel_type = (
            relationship.relationship_type.value
            if isinstance(relationship.relationship_type, RelationshipType)
            else relationship.relationship_type
        )
        query = f"""
        MATCH (a:Person {{id: $from_id}})
        MATCH (b:Person {{id: $to_id}})
        MERGE (a)-[r:{rel_type}]->(b)
        SET r.id = $id,
            r.strength = $strength,
            r.context = $context,
            r.metadata = $metadata,
            r.updated_at = datetime($updated_at)
        SET r.created_at = coalesce(r.created_at, datetime($created_at))
        RETURN r
        """
        self._driver.execute_query(
            query,
            database_=self._settings.neo4j_database,
            id=str(relationship.id),
            from_id=str(relationship.from_person_id),
            to_id=str(relationship.to_person_id),
            strength=relationship.strength,
            context=relationship.context,
            metadata=relationship.metadata,
            created_at=relationship.created_at.isoformat(),
            updated_at=relationship.updated_at.isoformat(),
        )
        return relationship

    def list_people(self) -> list[Person]:
        records, _summary, _keys = self._driver.execute_query(
            "MATCH (p:Person) RETURN p",
            database_=self._settings.neo4j_database,
        )
        return [_person_from_node(record["p"]) for record in records]

    def list_relationships(self) -> list[GraphRelationship]:
        records, _summary, _keys = self._driver.execute_query(
            """
            MATCH (a:Person)-[r]->(b:Person)
            WHERE type(r) IN ['KNOWS','WORKED_WITH','STUDIED_WITH','MENTORED_BY','INTERESTED_IN']
            RETURN a.id AS from_id, b.id AS to_id, type(r) AS type, r
            """,
            database_=self._settings.neo4j_database,
        )
        return [
            GraphRelationship(
                id=UUID(record["r"]["id"]),
                from_person_id=UUID(record["from_id"]),
                to_person_id=UUID(record["to_id"]),
                relationship_type=RelationshipType(record["type"]),
                strength=float(record["r"].get("strength", 0.5)),
                context=record["r"].get("context"),
                metadata=dict(record["r"].get("metadata") or {}),
            )
            for record in records
        ]


def _label(role: PersonRole | str) -> str:
    value = role.value if isinstance(role, PersonRole) else str(role)
    allowed = {role.value for role in PersonRole}
    if value not in allowed:
        raise ValueError(f"Unsupported role label: {value}")
    return value


def _person_params(person: Person) -> dict:
    return {
        "id": str(person.id),
        "name": person.name,
        "email": person.email,
        "headline": person.headline,
        "organization": person.organization,
        "location": person.location,
        "skills": person.skills,
        "interests": person.interests,
        "goals": person.goals,
        "metadata": person.metadata,
        "role": person.role.value if isinstance(person.role, PersonRole) else person.role,
        "created_at": person.created_at.isoformat(),
        "updated_at": person.updated_at.isoformat(),
    }


def _person_from_node(node) -> Person:
    data = dict(node)
    return Person(
        id=UUID(data["id"]),
        role=PersonRole(data["role"]),
        name=data["name"],
        email=data.get("email"),
        headline=data.get("headline"),
        organization=data.get("organization"),
        location=data.get("location"),
        skills=list(data.get("skills") or []),
        interests=list(data.get("interests") or []),
        goals=list(data.get("goals") or []),
        metadata=dict(data.get("metadata") or {}),
        created_at=_as_datetime(data.get("created_at")),
        updated_at=_as_datetime(data.get("updated_at")),
    )


def _as_datetime(value) -> datetime:
    if isinstance(value, datetime):
        return value
    if value is None:
        return datetime.now(UTC)
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
