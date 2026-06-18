from __future__ import annotations

from .config import Settings, get_settings
from .repository import InMemoryOfficeKitRepository, OfficeKitRepository
from .schemas import (
    BriefingRequest,
    BriefingResponse,
    MemoryCandidate,
    OfficeActionItem,
    OfficeArtifact,
    OfficeArtifactCreate,
    ReputationSignal,
)


class OfficeKitService:
    def __init__(self, *, settings: Settings, repository: OfficeKitRepository) -> None:
        self._settings = settings
        self._repository = repository

    def create_artifact(self, payload: OfficeArtifactCreate) -> OfficeArtifact:
        return self._repository.create_artifact(payload)

    def briefing(self, request: BriefingRequest) -> BriefingResponse:
        stored = self._repository.get_artifacts(request.user_id, request.artifact_ids)
        inline = [OfficeArtifact(**item.model_dump()) for item in request.inline_artifacts]
        artifacts = [*stored, *inline]
        titles = [artifact.title for artifact in artifacts]
        participants = sorted({name for artifact in artifacts for name in artifact.participants})
        content = " ".join(artifact.content for artifact in artifacts).lower()
        action_items = _action_items(request, artifacts, content)
        return BriefingResponse(
            user_id=request.user_id,
            objective=request.objective,
            summary=_summary(request.objective, titles, participants),
            key_context=_key_context(artifacts, participants),
            decisions=_decisions(content),
            risks=_risks(content, artifacts),
            action_items=action_items,
            memory_candidates=_memory_candidates(request, artifacts),
            reputation_signals=_reputation_signals(action_items, content),
        )


def create_officekit_service(
    *,
    settings: Settings | None = None,
    repository: OfficeKitRepository | None = None,
) -> OfficeKitService:
    return OfficeKitService(
        settings=settings or get_settings(),
        repository=repository or InMemoryOfficeKitRepository(),
    )


def _summary(objective: str, titles: list[str], participants: list[str]) -> str:
    title_text = ", ".join(titles[:3]) if titles else "the provided artifacts"
    participant_text = ", ".join(participants[:4]) if participants else "the user"
    return (
        f"Mission briefing for '{objective}'. Context comes from {title_text}. "
        f"Key people in scope: {participant_text}."
    )


def _key_context(artifacts: list[OfficeArtifact], participants: list[str]) -> list[str]:
    context = [f"{len(artifacts)} artifact(s) included in the briefing."]
    if participants:
        context.append(f"Participants: {', '.join(participants[:6])}.")
    context.extend(f"{artifact.artifact_type}: {artifact.title}" for artifact in artifacts[:4])
    return context


def _decisions(content: str) -> list[str]:
    decisions = []
    if "approve" in content or "approved" in content:
        decisions.append("Approval language detected.")
    if "pilot" in content:
        decisions.append("Pilot path is under consideration.")
    if "pricing" in content:
        decisions.append("Pricing should be resolved before follow-up.")
    return decisions or ["No explicit decision found; clarify the next decision owner."]


def _risks(content: str, artifacts: list[OfficeArtifact]) -> list[str]:
    risks = []
    if "risk" in content or "blocked" in content:
        risks.append("Artifact language includes risk or blocker signals.")
    if not artifacts:
        risks.append("Briefing has no artifacts; confidence is limited.")
    if "deadline" in content:
        risks.append("Deadline language detected; confirm date and owner.")
    return risks or ["No acute operational risk detected."]


def _action_items(
    request: BriefingRequest,
    artifacts: list[OfficeArtifact],
    content: str,
) -> list[OfficeActionItem]:
    owner = artifacts[0].participants[0] if artifacts and artifacts[0].participants else "user"
    items = [
        OfficeActionItem(
            title=f"Send follow-up for {request.objective}",
            owner=owner,
            priority="high" if "deadline" in content or "investor" in content else "medium",
            due_hint="next 24 hours",
            rationale="Follow-up preserves momentum and reputation.",
        )
    ]
    if "deck" in content or any("deck" in artifact.title.lower() for artifact in artifacts):
        items.append(
            OfficeActionItem(
                title="Prepare a concise deck summary",
                owner="user",
                priority="high",
                due_hint="before next meeting",
                rationale="Deck context should be turned into a reusable briefing.",
            )
        )
    return items


def _memory_candidates(
    request: BriefingRequest,
    artifacts: list[OfficeArtifact],
) -> list[MemoryCandidate]:
    candidates = [
        MemoryCandidate(
            title=f"Office briefing: {request.objective}",
            memory_type="office_briefing",
            content=f"Briefing generated from {len(artifacts)} artifact(s).",
            confidence=0.82 if artifacts else 0.55,
        )
    ]
    candidates.extend(
        MemoryCandidate(
            title=artifact.title,
            memory_type=artifact.artifact_type,
            content=artifact.content[:600] or artifact.title,
            confidence=0.76,
        )
        for artifact in artifacts[:3]
    )
    return candidates


def _reputation_signals(
    action_items: list[OfficeActionItem],
    content: str,
) -> list[ReputationSignal]:
    impact = 16 if "follow-up" in action_items[0].title.lower() else 8
    if "missed" in content:
        impact = -8
    return [
        ReputationSignal(
            title="Follow-through opportunity",
            event_type="commitment_created",
            impact_score=impact,
            rationale="Completing the action item can improve trust momentum.",
        )
    ]
