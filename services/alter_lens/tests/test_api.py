from __future__ import annotations

from fastapi.testclient import TestClient

from alter_lens.api import app, get_service


def test_analyze_endpoint_accepts_camera_image() -> None:
    get_service.cache_clear()
    client = TestClient(app)

    response = client.post(
        "/v1/alter-lens/analyze",
        data={"scan_type": "event_poster", "user_context": "AI meetup"},
        files={"image": ("poster.jpg", b"fake-image", "image/jpeg")},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["scan_type"] == "event_poster"
    assert payload["summary"]
    assert payload["insights"]
    assert payload["opportunities"]
    assert payload["recommendations"]


def test_analyze_endpoint_rejects_non_image() -> None:
    get_service.cache_clear()
    client = TestClient(app)

    response = client.post(
        "/v1/alter-lens/analyze",
        data={"scan_type": "resume"},
        files={"image": ("resume.txt", b"plain text", "text/plain")},
    )

    assert response.status_code == 400
