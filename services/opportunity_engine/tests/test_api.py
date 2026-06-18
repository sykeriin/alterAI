from __future__ import annotations

from fastapi.testclient import TestClient

from alter_opportunity_engine.api import app


def test_pipeline_api_returns_recommendations() -> None:
    client = TestClient(app)
    response = client.post(
        "/v1/opportunities/pipeline",
        json={
            "profile": {
                "career_stage": "student founder",
                "skills": ["Python", "AI", "backend"],
                "goals": ["startup", "funding"],
                "interests": ["AI agents", "developer tools"],
                "preferred_categories": ["hackathon", "grant", "accelerator"],
                "risk_tolerance": 0.7,
            },
            "crawl": {
                "sources": ["devpost", "startup_grants"],
                "query": "AI startup",
                "limit_per_source": 1,
            },
            "limit": 2,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["recommendations"]["recommendations"]
    assert body["ranked"]["ranked_opportunities"][0]["score"] > 0

