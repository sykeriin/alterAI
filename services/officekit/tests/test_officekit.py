from __future__ import annotations

from uuid import uuid4

from fastapi.testclient import TestClient

from alter_officekit.api import app, get_service
from alter_officekit.schemas import BriefingRequest, OfficeArtifactCreate, OfficeArtifactType
from alter_officekit.service import create_officekit_service


def test_briefing_generates_actions_and_memory_candidates() -> None:
    user_id = uuid4()
    service = create_officekit_service()
    artifact = OfficeArtifactCreate(
        user_id=user_id,
        artifact_type=OfficeArtifactType.meeting,
        title="Investor demo prep",
        content="Need deck summary and follow-up before deadline.",
        participants=["Aria", "Maya"],
    )

    response = service.briefing(
        BriefingRequest(
            user_id=user_id,
            objective="Prepare investor demo",
            inline_artifacts=[artifact],
        )
    )

    assert response.summary
    assert response.action_items
    assert response.memory_candidates
    assert response.reputation_signals


def test_api_briefing_accepts_inline_artifact() -> None:
    get_service.cache_clear()
    client = TestClient(app)

    response = client.post(
        "/v1/officekit/briefing",
        json={
            "objective": "Close pilot loop",
            "inline_artifacts": [
                {
                    "artifact_type": "email",
                    "title": "Pilot follow-up",
                    "content": "Customer asked for pricing and pilot deadline.",
                    "participants": ["Aria", "Nora"],
                }
            ],
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["action_items"]
    assert payload["risks"]
