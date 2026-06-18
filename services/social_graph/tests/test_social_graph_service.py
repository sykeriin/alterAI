from __future__ import annotations

from alter_social_graph.repository import InMemorySocialGraphRepository
from alter_social_graph.schemas import (
    CareerPathRequest,
    MentorDiscoveryRequest,
    MutualConnectionsRequest,
    PersonCreate,
    PersonRole,
    RecruiterDiscoveryRequest,
    RelationshipCreate,
    RelationshipType,
    TeamFormationRequest,
)
from alter_social_graph.service import create_social_graph_service


def _seed_service():
    repository = InMemorySocialGraphRepository()
    service = create_social_graph_service(repository=repository)

    user = service.upsert_person(
        PersonCreate(
            role=PersonRole.user,
            name="Aria",
            skills=["Python", "AI", "product"],
            interests=["AI agents", "startups"],
            goals=["startup", "fundraising"],
            location="Bangalore",
        )
    )
    founder = service.upsert_person(
        PersonCreate(
            role=PersonRole.founder,
            name="Maya Founder",
            skills=["product", "fundraising", "AI"],
            interests=["startups"],
            location="Bangalore",
        )
    )
    recruiter = service.upsert_person(
        PersonCreate(
            role=PersonRole.recruiter,
            name="Ravi Recruiter",
            skills=["AI hiring", "backend"],
            interests=["developer tools"],
            location="Bangalore",
        )
    )
    professor = service.upsert_person(
        PersonCreate(
            role=PersonRole.professor,
            name="Dr Sen",
            skills=["AI", "research", "mentorship"],
            interests=["AI agents", "students"],
        )
    )
    student = service.upsert_person(
        PersonCreate(
            role=PersonRole.student,
            name="Noor Student",
            skills=["Python", "open source"],
            interests=["GSoC", "AI"],
        )
    )
    investor = service.upsert_person(
        PersonCreate(
            role=PersonRole.investor,
            name="Isha Investor",
            skills=["fundraising", "marketplaces"],
            interests=["AI startups"],
        )
    )

    service.create_relationship(
        RelationshipCreate(
            from_person_id=user.id,
            to_person_id=founder.id,
            relationship_type=RelationshipType.knows,
            strength=0.9,
        )
    )
    service.create_relationship(
        RelationshipCreate(
            from_person_id=founder.id,
            to_person_id=recruiter.id,
            relationship_type=RelationshipType.worked_with,
            strength=0.8,
        )
    )
    service.create_relationship(
        RelationshipCreate(
            from_person_id=user.id,
            to_person_id=student.id,
            relationship_type=RelationshipType.studied_with,
            strength=0.7,
        )
    )
    service.create_relationship(
        RelationshipCreate(
            from_person_id=student.id,
            to_person_id=professor.id,
            relationship_type=RelationshipType.mentored_by,
            strength=0.85,
        )
    )
    service.create_relationship(
        RelationshipCreate(
            from_person_id=founder.id,
            to_person_id=investor.id,
            relationship_type=RelationshipType.interested_in,
            strength=0.78,
        )
    )
    service.create_relationship(
        RelationshipCreate(
            from_person_id=investor.id,
            to_person_id=recruiter.id,
            relationship_type=RelationshipType.knows,
            strength=0.6,
        )
    )
    return service, user, founder, recruiter, professor, student, investor


def test_mutual_connections() -> None:
    service, user, _founder, recruiter, *_rest = _seed_service()

    response = service.mutual_connections(
        MutualConnectionsRequest(person_a_id=user.id, person_b_id=recruiter.id)
    )

    assert response.mutual_connections
    assert response.mutual_connections[0].person.name == "Maya Founder"


def test_career_path_discovery() -> None:
    service, user, *_rest = _seed_service()

    response = service.career_paths(
        CareerPathRequest(
            start_person_id=user.id,
            target_role=PersonRole.investor,
            required_skills=["fundraising"],
        )
    )

    assert response.paths
    assert response.paths[0].people[-1].role == PersonRole.investor


def test_recruiter_and_mentor_discovery() -> None:
    service, user, *_rest = _seed_service()

    recruiters = service.discover_recruiters(
        RecruiterDiscoveryRequest(
            person_id=user.id,
            target_skills=["backend", "AI"],
            locations=["Bangalore"],
        )
    )
    mentors = service.discover_mentors(
        MentorDiscoveryRequest(
            person_id=user.id,
            target_interests=["AI agents"],
            target_skills=["AI"],
        )
    )

    assert recruiters.candidates[0].person.role == PersonRole.recruiter
    assert mentors.candidates[0].person.role in {
        PersonRole.professor,
        PersonRole.founder,
        PersonRole.investor,
    }


def test_team_formation_covers_skills() -> None:
    service, user, *_rest = _seed_service()

    response = service.form_team(
        TeamFormationRequest(
            seed_person_id=user.id,
            required_roles=[PersonRole.founder, PersonRole.student, PersonRole.investor],
            required_skills=["Python", "AI", "fundraising", "product"],
            team_size=4,
        )
    )

    assert response.members
    assert "AI" in response.covered_skills
    assert "fundraising" in response.covered_skills

