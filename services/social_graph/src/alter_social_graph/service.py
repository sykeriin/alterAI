from __future__ import annotations

from collections import Counter
from uuid import UUID

from .config import Settings, get_settings
from .repository import (
    InMemorySocialGraphRepository,
    Neo4jSocialGraphRepository,
    SocialGraphRepository,
)
from .schemas import (
    CareerPath,
    CareerPathRequest,
    CareerPathResponse,
    DiscoveryCandidate,
    DiscoveryResponse,
    GraphRelationship,
    MentorDiscoveryRequest,
    MutualConnection,
    MutualConnectionsRequest,
    MutualConnectionsResponse,
    Person,
    PersonCreate,
    PersonRole,
    RecruiterDiscoveryRequest,
    RelationshipCreate,
    TeamFormationRequest,
    TeamFormationResponse,
    TeamMemberRecommendation,
)


class SocialGraphNotFoundError(LookupError):
    pass


class SocialGraphService:
    def __init__(self, *, settings: Settings, repository: SocialGraphRepository) -> None:
        self._settings = settings
        self._repository = repository

    def upsert_person(self, payload: PersonCreate) -> Person:
        return self._repository.upsert_person(payload)

    def get_person(self, person_id: UUID) -> Person:
        person = self._repository.get_person(person_id)
        if person is None:
            raise SocialGraphNotFoundError(str(person_id))
        return person

    def create_relationship(self, payload: RelationshipCreate) -> GraphRelationship:
        return self._repository.create_relationship(payload)

    def mutual_connections(self, request: MutualConnectionsRequest) -> MutualConnectionsResponse:
        people = {person.id: person for person in self._repository.list_people()}
        relationships = self._repository.list_relationships()
        a_neighbors = _neighbor_map(relationships, request.person_a_id)
        b_neighbors = _neighbor_map(relationships, request.person_b_id)
        mutual_ids = set(a_neighbors) & set(b_neighbors)
        mutuals = []
        for person_id in mutual_ids:
            person = people.get(person_id)
            if person is None:
                continue
            rels = [a_neighbors[person_id], b_neighbors[person_id]]
            strength = sum(rel.strength for rel in rels) / len(rels)
            mutuals.append(
                MutualConnection(
                    person=person,
                    connection_strength=round(strength, 3),
                    via_relationships=[rel.relationship_type for rel in rels],
                )
            )
        return MutualConnectionsResponse(
            mutual_connections=sorted(
                mutuals,
                key=lambda item: item.connection_strength,
                reverse=True,
            )[: request.limit]
        )

    def career_paths(self, request: CareerPathRequest) -> CareerPathResponse:
        if hasattr(self._repository, "paths_to_role"):
            raw_paths = self._repository.paths_to_role(
                request.start_person_id,
                request.target_role,
                request.max_depth,
            )
        else:
            raw_paths = []
        paths = [
            CareerPath(
                people=people,
                relationships=[rel.relationship_type for rel in relationships],
                score=_career_path_score(people, relationships, request.required_skills),
                rationale=_career_path_rationale(people, request.required_skills),
            )
            for people, relationships in raw_paths
        ]
        return CareerPathResponse(
            paths=sorted(paths, key=lambda path: path.score, reverse=True)[: request.limit]
        )

    def discover_recruiters(self, request: RecruiterDiscoveryRequest) -> DiscoveryResponse:
        user = self.get_person(request.person_id)
        candidates = [
            person
            for person in self._repository.list_people()
            if person.role == PersonRole.recruiter and person.id != user.id
        ]
        ranked = [
            self._discovery_candidate(
                user,
                candidate,
                target_terms=[*request.target_skills, *user.skills, *user.goals],
                role_bonus=12,
                location_terms=request.locations,
            )
            for candidate in candidates
        ]
        return DiscoveryResponse(
            candidates=sorted(ranked, key=lambda item: item.score, reverse=True)[
                : request.limit
            ]
        )

    def discover_mentors(self, request: MentorDiscoveryRequest) -> DiscoveryResponse:
        user = self.get_person(request.person_id)
        mentor_roles = {PersonRole.professor, PersonRole.investor, PersonRole.founder}
        candidates = [
            person
            for person in self._repository.list_people()
            if person.role in mentor_roles and person.id != user.id
        ]
        ranked = [
            self._discovery_candidate(
                user,
                candidate,
                target_terms=[
                    *request.target_interests,
                    *request.target_skills,
                    *user.interests,
                    *user.skills,
                ],
                role_bonus=16 if candidate.role == PersonRole.professor else 10,
                location_terms=[],
            )
            for candidate in candidates
        ]
        return DiscoveryResponse(
            candidates=sorted(ranked, key=lambda item: item.score, reverse=True)[
                : request.limit
            ]
        )

    def form_team(self, request: TeamFormationRequest) -> TeamFormationResponse:
        seed = self.get_person(request.seed_person_id)
        candidates = [
            person for person in self._repository.list_people() if person.id != seed.id
        ]
        scored = [
            self._team_member(seed, candidate, request.required_roles, request.required_skills)
            for candidate in candidates
        ]
        selected = sorted(
            scored,
            key=lambda member: (
                len(member.skill_coverage),
                member.role_fit,
                -member.relationship_distance,
            ),
            reverse=True,
        )[: request.team_size]
        covered = sorted({skill for member in selected for skill in member.skill_coverage})
        missing = [
            skill
            for skill in request.required_skills
            if _normalize(skill) not in {_normalize(item) for item in covered}
        ]
        return TeamFormationResponse(
            members=selected,
            covered_skills=covered,
            missing_skills=missing,
        )

    def _discovery_candidate(
        self,
        user: Person,
        candidate: Person,
        *,
        target_terms: list[str],
        role_bonus: float,
        location_terms: list[str],
    ) -> DiscoveryCandidate:
        mutual_count = len(
            self.mutual_connections(
                MutualConnectionsRequest(
                    person_a_id=user.id,
                    person_b_id=candidate.id,
                    limit=100,
                )
            ).mutual_connections
        )
        overlap = _term_overlap(
            [*candidate.skills, *candidate.interests, *candidate.goals, candidate.headline or ""],
            target_terms,
        )
        location_bonus = (
            8
            if candidate.location
            and any(_normalize(loc) in _normalize(candidate.location) for loc in location_terms)
            else 0
        )
        score = min(100.0, overlap * 55 + mutual_count * 8 + role_bonus + location_bonus)
        reasons = []
        if overlap > 0:
            reasons.append("Matches target skills, interests, or goals.")
        if mutual_count:
            reasons.append(f"{mutual_count} mutual connection(s).")
        if location_bonus:
            reasons.append("Location preference match.")
        return DiscoveryCandidate(
            person=candidate,
            score=round(score, 2),
            mutual_connection_count=mutual_count,
            reasons=reasons or ["Relevant role in extended graph."],
        )

    def _team_member(
        self,
        seed: Person,
        candidate: Person,
        required_roles: list[PersonRole],
        required_skills: list[str],
    ) -> TeamMemberRecommendation:
        role_fit = 1.0 if not required_roles or candidate.role in required_roles else 0.35
        coverage = [
            skill
            for skill in required_skills
            if _normalize(skill) in {_normalize(item) for item in candidate.skills}
        ]
        distance = (
            self._repository.shortest_distance(seed.id, candidate.id, 4)
            if hasattr(self._repository, "shortest_distance")
            else None
        )
        relationship_distance = distance if distance is not None else 99
        reasons = []
        if coverage:
            reasons.append(f"Covers {', '.join(coverage)}.")
        if role_fit >= 1:
            reasons.append(f"Matches needed role {candidate.role}.")
        if relationship_distance <= 2:
            reasons.append("Close graph relationship.")
        return TeamMemberRecommendation(
            person=candidate,
            role_fit=role_fit,
            skill_coverage=coverage,
            relationship_distance=relationship_distance,
            reasons=reasons or ["Adds adjacent network value."],
        )


def create_social_graph_service(
    *,
    settings: Settings | None = None,
    repository: SocialGraphRepository | None = None,
) -> SocialGraphService:
    resolved_settings = settings or get_settings()
    resolved_repository = repository
    if resolved_repository is None:
        if resolved_settings.social_graph_env == "local":
            resolved_repository = InMemorySocialGraphRepository()
        else:
            resolved_repository = Neo4jSocialGraphRepository(resolved_settings)
    return SocialGraphService(settings=resolved_settings, repository=resolved_repository)


def _neighbor_map(
    relationships: list[GraphRelationship],
    person_id: UUID,
) -> dict[UUID, GraphRelationship]:
    neighbors = {}
    for relationship in relationships:
        if relationship.from_person_id == person_id:
            neighbors[relationship.to_person_id] = relationship
        elif relationship.to_person_id == person_id:
            neighbors[relationship.from_person_id] = relationship
    return neighbors


def _career_path_score(
    people: list[Person],
    relationships: list[GraphRelationship],
    required_skills: list[str],
) -> float:
    target = people[-1]
    skill_fit = _term_overlap(target.skills, required_skills) if required_skills else 0.6
    relationship_strength = (
        sum(relationship.strength for relationship in relationships) / len(relationships)
        if relationships
        else 0
    )
    shortness = max(0.0, 1 - (len(relationships) - 1) * 0.18)
    return round(100 * (skill_fit * 0.42 + relationship_strength * 0.34 + shortness * 0.24), 2)


def _career_path_rationale(people: list[Person], required_skills: list[str]) -> list[str]:
    target = people[-1]
    rationale = [f"Path reaches {target.name}, a {target.role}."]
    shared = [
        skill
        for skill in required_skills
        if _normalize(skill) in {_normalize(item) for item in target.skills}
    ]
    if shared:
        rationale.append(f"Target has relevant skills: {', '.join(shared)}.")
    rationale.append(f"Path length is {len(people) - 1}.")
    return rationale


def _term_overlap(left: list[str], right: list[str]) -> float:
    if not right:
        return 0.5
    left_terms = Counter(_normalize(item) for item in left if item)
    right_terms = {_normalize(item) for item in right if item}
    if not right_terms:
        return 0.5
    matches = sum(
        1
        for term in right_terms
        if term in left_terms
        or any(term in left_term or left_term in term for left_term in left_terms)
    )
    return min(1.0, matches / len(right_terms))


def _normalize(value: str) -> str:
    return value.lower().strip().replace("-", " ")
