from __future__ import annotations

from fastapi.testclient import TestClient

import alter_api_gateway.api as gateway_api
from alter_api_gateway.api import app
from alter_api_gateway.config import Settings
from alter_api_gateway.schemas import MissionBriefingRequest
from alter_api_gateway.service import ApiGatewayService


def test_routes_include_core_services() -> None:
    service = ApiGatewayService(Settings())

    routes = {route.name for route in service.routes()}

    assert "voice_gateway" in routes
    assert "future_simulation" in routes
    assert "officekit" in routes


def test_mission_briefing_returns_cross_device_sequence() -> None:
    service = ApiGatewayService(Settings())

    response = service.mission_briefing(
        MissionBriefingRequest(objective="Choose between startup and research")
    )

    assert "voice_gateway" in response.phone_layer
    assert "clone_council" in response.laptop_layer
    assert response.recommended_sequence
    assert response.route_targets


def test_api_routes_endpoint() -> None:
    client = TestClient(app)

    response = client.get("/v1/gateway/routes")

    assert response.status_code == 200
    assert any(item["name"] == "alter_lens" for item in response.json())


def test_gateway_registers_feature_service_proxy() -> None:
    route_paths = {route.path for route in app.routes}

    assert "/v1/{proxied_path:path}" in route_paths


def test_gateway_proxy_rejects_unknown_feature_prefix() -> None:
    client = TestClient(app)

    response = client.get("/v1/not-a-service/example")

    assert response.status_code == 404
    assert "No API gateway route" in response.json()["detail"]


def test_gateway_proxy_forwards_known_feature_prefix(monkeypatch) -> None:
    calls: dict[str, object] = {}

    class _Route:
        name = "clone_council"
        base_url = "http://clone-council.local"

    class _Service:
        def routes(self):
            return [_Route()]

    class _Response:
        content = b'{"agents":[]}'
        status_code = 200
        headers = {"content-type": "application/json"}

    class _Client:
        def __init__(self, timeout: float):
            calls["timeout"] = timeout

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def request(self, method, url, content=None, headers=None):
            calls["method"] = method
            calls["url"] = url
            calls["content"] = content
            calls["headers"] = headers
            return _Response()

    monkeypatch.setattr(gateway_api, "get_service", lambda: _Service())
    monkeypatch.setattr(gateway_api.httpx, "AsyncClient", _Client)

    response = TestClient(app).get("/v1/clone-council/agents?limit=1")

    assert response.status_code == 200
    assert response.json() == {"agents": []}
    assert calls["method"] == "GET"
    assert calls["url"] == "http://clone-council.local/v1/clone-council/agents?limit=1"


def test_multilingual_languages_include_all_indian_languages() -> None:
    client = TestClient(app)

    response = client.get("/v1/multilingual/languages")

    assert response.status_code == 200
    payload = response.json()
    assert payload["sarvam_enabled"] is False
    assert len(payload["indian_languages"]) == 23
    assert any(item["code"] == "hi-IN" for item in payload["indian_languages"])
    assert any(item["code"] == "es-ES" for item in payload["major_foreign_languages"])


def test_multilingual_chat_falls_back_without_sarvam_key() -> None:
    client = TestClient(app)

    response = client.post(
        "/v1/multilingual/chat",
        json={
            "target_language_code": "hi-IN",
            "messages": [{"role": "user", "content": "Plan my day"}],
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["provider"] == "alter-local"
    assert payload["fallback"] is True
    assert payload["target_language_code"] == "hi-IN"


def test_sarvam_speech_and_language_endpoints_fallback_without_key() -> None:
    client = TestClient(app)

    detect = client.post(
        "/v1/multilingual/detect-language",
        json={"text": "Namaste, plan my day"},
    )
    assert detect.status_code == 200
    assert detect.json()["provider"] == "alter-local"
    assert detect.json()["fallback"] is True

    tts = client.post(
        "/v1/multilingual/text-to-speech",
        json={"text": "Namaste", "target_language_code": "hi-IN"},
    )
    assert tts.status_code == 200
    assert tts.json()["provider"] == "alter-local"
    assert tts.json()["fallback"] is True

    stt = client.post(
        "/v1/multilingual/speech-to-text",
        files={"file": ("sample.wav", b"not-real-audio", "audio/wav")},
        data={"language_code": "unknown", "mode": "transcribe"},
    )
    assert stt.status_code == 200
    assert stt.json()["provider"] == "alter-local"
    assert stt.json()["fallback"] is True


def test_consent_ingestion_planner_privacy_surfaces() -> None:
    client = TestClient(app)
    user_id = "11111111-1111-4111-8111-111111111111"

    ledger = client.get(f"/v1/security/consent-ledger?user_id={user_id}")
    assert ledger.status_code == 200
    assert ledger.json()["grants"]

    ingestion = client.post(
        "/v1/data-ingestion/import",
        json={
            "user_id": user_id,
            "source": "notes",
            "items": [{"title": "Launch note", "summary": "Build ALTER end to end"}],
        },
    )
    assert ingestion.status_code == 200
    assert ingestion.json()["accepted"] is True
    assert ingestion.json()["memory_candidates"]

    blocked = client.post(
        "/v1/data-ingestion/import",
        json={
            "user_id": user_id,
            "source": "whatsapp",
            "import_mode": "silent_scrape",
            "items": [{"title": "Private chat"}],
        },
    )
    assert blocked.status_code == 200
    assert blocked.json()["accepted"] is False

    plan = client.post(
        "/v1/agent/plan",
        json={"user_id": user_id, "goal": "Open WhatsApp and draft a reply"},
    )
    assert plan.status_code == 200
    assert plan.json()["steps"]
    assert any(step["requires_confirmation"] for step in plan.json()["steps"])

    export = client.get(f"/v1/privacy/export?user_id={user_id}")
    assert export.status_code == 200
    assert export.json()["download_ready"] is True


def test_orchestration_endpoint_returns_story_even_when_services_are_unavailable() -> None:
    client = TestClient(app)

    response = client.post(
        "/v1/orchestration/future-os",
        json={"objective": "Choose the best hackathon launch path"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["headline"]
    assert payload["steps"]
    assert "systems" in payload["key_metrics"]
