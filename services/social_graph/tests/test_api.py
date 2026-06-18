from __future__ import annotations

from fastapi.testclient import TestClient

from alter_social_graph.api import app


def test_social_graph_api_can_create_people_and_relationships() -> None:
    client = TestClient(app)

    user = client.post(
        "/v1/social-graph/people",
        json={
            "role": "User",
            "name": "Aria",
            "skills": ["Python", "AI"],
            "interests": ["startups"],
        },
    ).json()
    founder = client.post(
        "/v1/social-graph/people",
        json={
            "role": "Founder",
            "name": "Maya",
            "skills": ["fundraising", "product"],
            "interests": ["AI startups"],
        },
    ).json()

    relationship = client.post(
        "/v1/social-graph/relationships",
        json={
            "from_person_id": user["id"],
            "to_person_id": founder["id"],
            "relationship_type": "KNOWS",
            "strength": 0.8,
        },
    )

    assert relationship.status_code == 200
    assert relationship.json()["relationship_type"] == "KNOWS"

