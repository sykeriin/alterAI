from __future__ import annotations

from fastapi.testclient import TestClient

from alter_future_simulation.api import app


def test_simulate_endpoint_returns_structured_json() -> None:
    client = TestClient(app)
    payload = {
        "user_profile": {
            "current_role": "Product engineer",
            "current_salary": 120000,
            "current_network_size": 250,
            "risk_tolerance": 0.55,
            "weekly_learning_hours": 8,
        },
        "skills": [
            {"name": "Python", "category": "technical", "level": 0.8, "years": 5},
            {"name": "Product", "category": "product", "level": 0.7, "years": 3},
        ],
        "goals": [
            {
                "title": "Launch an AI product",
                "category": "startup",
                "horizon_months": 24,
                "priority": 5,
            }
        ],
        "experience": [
            {
                "title": "Built automation platform",
                "years": 4,
                "impact": "Improved operational efficiency.",
            }
        ],
        "interests": ["AI agents", "future of work"],
        "horizon_months": 36,
        "currency": "USD",
    }

    response = client.post("/v1/future-simulation/simulate", json=payload)

    assert response.status_code == 200
    body = response.json()
    assert body["simulation_id"].startswith("future_sim_")
    assert len(body["futures"]) == 3
    assert {
        "timeline",
        "salary_trajectory",
        "skill_trajectory",
        "network_growth",
        "opportunity_score",
        "risk_score",
        "success_probability",
    }.issubset(body["futures"][0])

