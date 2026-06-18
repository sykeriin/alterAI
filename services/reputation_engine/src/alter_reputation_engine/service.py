from __future__ import annotations

from collections import Counter
from uuid import UUID

from .config import Settings, get_settings
from .repository import InMemoryReputationRepository, ReputationRepository
from .schemas import (
    ReputationEvent,
    ReputationEventCreate,
    ReputationEventType,
    ReputationScoreResponse,
)


class ReputationService:
    def __init__(self, *, settings: Settings, repository: ReputationRepository) -> None:
        self._settings = settings
        self._repository = repository

    def create_event(self, payload: ReputationEventCreate) -> ReputationEvent:
        return self._repository.create_event(payload)

    def list_events(self, user_id: UUID) -> list[ReputationEvent]:
        return self._repository.list_events(user_id)

    def score(self, user_id: UUID) -> ReputationScoreResponse:
        events = self.list_events(user_id)
        total_delta = sum(event.impact_score for event in events)
        score = max(0, min(1000, self._settings.baseline_score + total_delta))
        recent_delta = sum(event.impact_score for event in events[:5])
        event_counts = Counter(event.event_type for event in events)
        return ReputationScoreResponse(
            user_id=user_id,
            score=score,
            trust_level=_trust_level(score),
            recent_delta=recent_delta,
            event_count=len(events),
            strengths=_strengths(event_counts),
            risks=_risks(event_counts),
            recommendations=_recommendations(event_counts, score),
        )


def create_reputation_service(
    *,
    settings: Settings | None = None,
    repository: ReputationRepository | None = None,
) -> ReputationService:
    return ReputationService(
        settings=settings or get_settings(),
        repository=repository or InMemoryReputationRepository(),
    )


def _trust_level(score: int) -> str:
    if score >= 780:
        return "excellent"
    if score >= 680:
        return "strong"
    if score >= 560:
        return "stable"
    if score >= 420:
        return "watch"
    return "at_risk"


def _strengths(event_counts: Counter[ReputationEventType]) -> list[str]:
    strengths = []
    if event_counts[ReputationEventType.delivered]:
        strengths.append("Consistent delivery signals.")
    if event_counts[ReputationEventType.follow_up]:
        strengths.append("Follow-up behavior is visible.")
    if event_counts[ReputationEventType.intro_made]:
        strengths.append("Creates value for the network through introductions.")
    if event_counts[ReputationEventType.endorsement]:
        strengths.append("Receives external trust signals.")
    return strengths or ["Reputation baseline is established."]


def _risks(event_counts: Counter[ReputationEventType]) -> list[str]:
    risks = []
    missed = event_counts[ReputationEventType.missed_reply]
    commitments = event_counts[ReputationEventType.commitment_created]
    delivered = event_counts[ReputationEventType.delivered]
    if missed:
        risks.append("Missed replies are creating trust drag.")
    if commitments > delivered + 2:
        risks.append("Open commitments exceed completed delivery signals.")
    return risks or ["No acute reputation risk detected."]


def _recommendations(event_counts: Counter[ReputationEventType], score: int) -> list[str]:
    recommendations = []
    if event_counts[ReputationEventType.missed_reply]:
        recommendations.append("Send concise recovery follow-ups for missed replies.")
    if score < 680:
        recommendations.append("Close one visible commitment this week.")
    recommendations.append("Log completed follow-through to keep the ledger accurate.")
    return recommendations
