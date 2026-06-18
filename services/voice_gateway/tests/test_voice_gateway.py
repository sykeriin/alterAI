from __future__ import annotations

from fastapi.testclient import TestClient

from alter_voice_gateway.api import app
from alter_voice_gateway.config import Settings
from alter_voice_gateway.schemas import VoiceIntent, VoiceSessionRequest
from alter_voice_gateway.service import VoiceGatewayService


def test_detects_wake_phrase_and_future_intent() -> None:
    service = VoiceGatewayService(Settings(ALTER_WAKE_PHRASE="hey alter"))

    response = service.start_session(
        VoiceSessionRequest(transcript="Hey Alter, simulate my founder future")
    )

    assert response.wake_word_detected is True
    assert response.inferred_intent == VoiceIntent.future_decision
    assert "/v1/future-simulation/simulate" in response.route_targets


def test_api_session_returns_actions() -> None:
    client = TestClient(app)

    response = client.post(
        "/v1/voice/session",
        json={"transcript": "Hey Alter remember this mentor advice"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["inferred_intent"] == "memory_capture"
    assert payload["actions"]
