from __future__ import annotations

from fastapi.testclient import TestClient

from alter_memory_system.api import app


def test_memory_api_create_and_search() -> None:
    client = TestClient(app)
    user_id = "11111111-1111-4111-8111-111111111111"

    create_response = client.post(
        "/v1/memory/items",
        json={
            "user_id": user_id,
            "memory_type": "project",
            "title": "ALTER Clone Council",
            "summary": "Built a multi-agent debate system.",
            "content": "The user created a LangGraph Clone Council service.",
            "confidence": 0.9,
            "importance": 0.82,
        },
    )
    assert create_response.status_code == 200

    search_response = client.post(
        "/v1/memory/search",
        json={
            "user_id": user_id,
            "query": "LangGraph agent council",
            "limit": 5,
        },
    )

    assert search_response.status_code == 200
    assert search_response.json()["hits"][0]["memory"]["title"] == "ALTER Clone Council"


def test_memory_api_ingest_and_governance() -> None:
    client = TestClient(app)
    user_id = "22222222-2222-4222-8222-222222222222"

    ingest_response = client.post(
        "/v1/memory/ingest",
        json={
            "user_id": user_id,
            "content": "Remind me tomorrow to prepare the ALTER demo.",
            "source": "voice",
        },
    )
    governance_response = client.get(f"/v1/memory/users/{user_id}/governance")

    assert ingest_response.status_code == 200
    assert ingest_response.json()["classification"]["retention"] == "expiring"
    assert ingest_response.json()["short_term_memory"] is not None
    assert governance_response.status_code == 200
    assert governance_response.json()["policy"]["default_retention"] == "ephemeral"

