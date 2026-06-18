from __future__ import annotations

from .config import Settings, get_settings
from .schemas import (
    VoiceAction,
    VoiceIntent,
    VoiceSessionRequest,
    VoiceSessionResponse,
)


class VoiceGatewayService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def start_session(self, request: VoiceSessionRequest) -> VoiceSessionResponse:
        text = request.transcript.lower()
        wake_word_detected = self._settings.wake_phrase.lower() in text
        normalized = text.replace(self._settings.wake_phrase.lower(), "").strip(" ,.")
        intent, confidence = _infer_intent(normalized or text)
        actions = _actions_for_intent(intent)
        return VoiceSessionResponse(
            user_id=request.user_id,
            wake_word_detected=wake_word_detected,
            normalized_text=normalized or request.transcript,
            inferred_intent=intent,
            confidence=confidence,
            route_targets=[action.route for action in actions],
            actions=actions,
        )


def create_voice_gateway_service(settings: Settings | None = None) -> VoiceGatewayService:
    return VoiceGatewayService(settings or get_settings())


def _infer_intent(text: str) -> tuple[VoiceIntent, float]:
    rules: list[tuple[VoiceIntent, float, tuple[str, ...]]] = [
        (
            VoiceIntent.call_contact,
            0.94,
            ("call my", "call dad", "call mom", "dial", "phone my", "ring my", "call "),
        ),
        (
            VoiceIntent.send_message,
            0.93,
            ("text my", "message my", "send a text", "send a message", "sms ", "whatsapp "),
        ),
        (
            VoiceIntent.future_decision,
            0.92,
            (
                "future",
                "simulate",
                "decision",
                "choose",
                "path",
                "career",
                "should i",
                "startup",
                "build",
                "today",
                "next move",
            ),
        ),
        (
            VoiceIntent.clone_council,
            0.9,
            ("council", "debate", "clones", "argue", "challenge"),
        ),
        (
            VoiceIntent.opportunity_search,
            0.88,
            ("opportunity", "internship", "grant", "fellowship", "program"),
        ),
        (
            VoiceIntent.memory_capture,
            0.84,
            ("remember", "save", "memory", "note", "log"),
        ),
        (
            VoiceIntent.lens_scan,
            0.86,
            ("scan", "camera", "resume", "deck", "poster", "paper", "product"),
        ),
        (VoiceIntent.nfc_exchange, 0.86, ("nfc", "tap", "exchange", "portfolio")),
        (VoiceIntent.office_briefing, 0.85, ("brief", "meeting", "calendar", "office")),
        (VoiceIntent.social_graph, 0.84, ("intro", "mentor", "recruiter", "network")),
        (VoiceIntent.reputation, 0.82, ("reputation", "trust", "follow up", "follow-up")),
    ]
    for intent, confidence, keywords in rules:
        if any(keyword in text for keyword in keywords):
            return intent, confidence
    return VoiceIntent.unknown, 0.42


def _actions_for_intent(intent: VoiceIntent) -> list[VoiceAction]:
    mapping = {
        VoiceIntent.future_decision: [
            VoiceAction(
                label="Simulate futures",
                route="/v1/future-simulation/simulate",
                reason="The user is exploring a life or career decision.",
                priority=5,
            ),
            VoiceAction(
                label="Ask Clone Council",
                route="/v1/clone-council/debate",
                reason="Council debate adds challenge and consensus.",
                priority=4,
            ),
        ],
        VoiceIntent.clone_council: [
            VoiceAction(
                label="Run council debate",
                route="/v1/clone-council/debate",
                reason="The request asks for multiple perspectives.",
                priority=5,
            )
        ],
        VoiceIntent.opportunity_search: [
            VoiceAction(
                label="Find opportunities",
                route="/v1/opportunities/pipeline",
                reason="The user is asking for external openings.",
                priority=5,
            )
        ],
        VoiceIntent.memory_capture: [
            VoiceAction(
                label="Create memory",
                route="/v1/memory/items",
                reason="The user explicitly asked ALTER to remember context.",
                priority=5,
            )
        ],
        VoiceIntent.lens_scan: [
            VoiceAction(
                label="Open Alter Lens",
                route="/v1/alter-lens/analyze",
                reason="The request depends on camera intelligence.",
                priority=5,
            )
        ],
        VoiceIntent.nfc_exchange: [
            VoiceAction(
                label="Start NFC networking",
                route="/v1/nfc/exchanges",
                reason="The user referenced tap-based profile exchange.",
                priority=5,
            )
        ],
        VoiceIntent.office_briefing: [
            VoiceAction(
                label="Create OfficeKit briefing",
                route="/v1/officekit/briefing",
                reason="The request asks for meeting or office context.",
                priority=5,
            )
        ],
        VoiceIntent.social_graph: [
            VoiceAction(
                label="Search Social Graph",
                route="/v1/social-graph/mutual-connections",
                reason="The user is asking for relationship intelligence.",
                priority=4,
            )
        ],
        VoiceIntent.reputation: [
            VoiceAction(
                label="Analyze reputation",
                route="/v1/reputation/users/{user_id}/score",
                reason="The user is asking about trust or follow-through.",
                priority=4,
            )
        ],
        VoiceIntent.call_contact: [
            VoiceAction(
                label="Find contact and open dialer",
                route="/v1/agent/plan",
                reason="The user asked to call someone.",
                priority=5,
            )
        ],
        VoiceIntent.send_message: [
            VoiceAction(
                label="Find contact and open message",
                route="/v1/agent/plan",
                reason="The user asked to text or message someone.",
                priority=5,
            )
        ],
        VoiceIntent.unknown: [
            VoiceAction(
                label="Ask clarifying question",
                route="/v1/voice/session",
                reason="The transcript does not map cleanly to a core workflow.",
                priority=2,
            )
        ],
    }
    return mapping[intent]
