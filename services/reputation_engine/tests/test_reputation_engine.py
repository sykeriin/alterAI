from __future__ import annotations

from uuid import uuid4

from fastapi.testclient import TestClient

from alter_reputation_engine.api import app, get_service
from alter_reputation_engine.config import Settings
from alter_reputation_engine.repository import InMemoryReputationRepository
from alter_reputation_engine.schemas import ReputationEventCreate, ReputationEventType
from alter_reputation_engine.service import ReputationService


def test_reputation_score_uses_events() -> None:
    user_id = uuid4()
    service = ReputationService(
        settings=Settings(ALTER_REPUTATION_BASELINE_SCORE=600),
        repository=InMemoryReputationRepository(),
    )
    service.create_event(
        ReputationEventCreate(
            user_id=user_id,
            event_type=ReputationEventType.delivered,
            title="Delivered demo",
            impact_score=40,
        )
    )
    service.create_event(
        ReputationEventCreate(
            user_id=user_id,
            event_type=ReputationEventType.missed_reply,
            title="Missed mentor note",
            impact_score=-12,
        )
    )

    score = service.score(user_id)

    assert score.score == 628
    assert score.recent_delta == 28
    assert score.strengths
    assert score.risks


def test_api_creates_event_and_scores_user() -> None:
    get_service.cache_clear()
    user_id = str(uuid4())
    client = TestClient(app)

    response = client.post(
        "/v1/reputation/events",
        json={
            "user_id": user_id,
            "event_type": "follow_up",
            "title": "Sent follow-up",
            "impact_score": 18,
        },
    )
    assert response.status_code == 200

    score = client.get(f"/v1/reputation/users/{user_id}/score")
    assert score.status_code == 200
    assert score.json()["score"] == 618
