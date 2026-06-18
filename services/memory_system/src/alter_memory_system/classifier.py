from __future__ import annotations

import re

from .schemas import (
    MemoryClassification,
    MemoryIngestRequest,
    MemoryRetention,
    MemorySensitivity,
    MemoryType,
)

_RESTRICTED = re.compile(
    r"\b(otp|one[- ]time password|cvv|pin|password|passcode|verification code|"
    r"bank account|credit card)\b",
    re.IGNORECASE,
)
_SENSITIVE = re.compile(
    r"\b(health|diagnos|therapy|salary|income|debt|address|relationship|private)\b",
    re.IGNORECASE,
)
_EXPIRING = re.compile(
    r"\b(today|tomorrow|tonight|this week|deadline|due|appointment|meeting|"
    r"remind|at \d{1,2}(?::\d{2})?\s?(?:am|pm)?)\b",
    re.IGNORECASE,
)
_PREFERENCE = re.compile(r"\b(i prefer|i like|i dislike|i hate|my favorite)\b", re.IGNORECASE)
_GOAL = re.compile(r"\b(my goal|i want to|i plan to|i am trying to|i'm trying to)\b", re.IGNORECASE)
_DECISION = re.compile(r"\b(i decided|i chose|i will choose|decision)\b", re.IGNORECASE)
_PERSON = re.compile(r"\b(friend|mentor|manager|partner|mom|dad|brother|sister)\b", re.IGNORECASE)
_TRIVIAL = re.compile(r"^\s*(hi|hello|thanks|thank you|ok|okay|yes|no|bye)[.! ]*$", re.IGNORECASE)


class MemoryClassifier:
    """Fast local-first policy classifier. Uncertainty defaults to forgetting."""

    def classify(self, request: MemoryIngestRequest) -> MemoryClassification:
        text = request.content.strip()
        rationale: list[str] = []

        if _RESTRICTED.search(text):
            return MemoryClassification(
                should_store=False,
                retention=MemoryRetention.ephemeral,
                sensitivity=MemorySensitivity.restricted,
                memory_type=MemoryType.note,
                importance=0.0,
                confidence=0.99,
                requires_confirmation=False,
                rationale=["Restricted secret detected; raw content must be deleted."],
            )

        if len(text) < 12 or _TRIVIAL.match(text):
            return MemoryClassification(
                should_store=False,
                retention=MemoryRetention.ephemeral,
                sensitivity=MemorySensitivity.normal,
                memory_type=MemoryType.conversation,
                importance=0.05,
                confidence=0.92,
                requires_confirmation=False,
                rationale=["Low-information interaction."],
            )

        sensitivity = (
            MemorySensitivity.sensitive if _SENSITIVE.search(text) else MemorySensitivity.normal
        )
        memory_type = MemoryType.note
        retention = MemoryRetention.session
        importance = 0.35

        if _GOAL.search(text):
            memory_type = MemoryType.goal
            retention = MemoryRetention.durable
            importance = 0.8
            rationale.append("Long-term goal signal detected.")
        elif _DECISION.search(text):
            memory_type = MemoryType.decision
            retention = MemoryRetention.durable
            importance = 0.82
            rationale.append("Decision signal detected.")
        elif _PREFERENCE.search(text):
            retention = MemoryRetention.durable
            importance = 0.68
            rationale.append("Persistent preference signal detected.")
        elif _PERSON.search(text):
            memory_type = MemoryType.friend
            retention = MemoryRetention.durable
            importance = 0.65
            rationale.append("Relationship signal detected.")
        elif _EXPIRING.search(text):
            retention = MemoryRetention.expiring
            importance = 0.58
            rationale.append("Time-bound commitment or event detected.")
        else:
            rationale.append("Potentially useful session context; no durable signal detected.")

        requires_confirmation = not request.user_confirmed and (
            sensitivity == MemorySensitivity.sensitive
            or retention == MemoryRetention.durable
        )
        should_store = not requires_confirmation
        if request.user_confirmed:
            rationale.append("User explicitly confirmed storage.")
        elif requires_confirmation:
            rationale.append("Storage requires user confirmation.")

        return MemoryClassification(
            should_store=should_store,
            retention=retention,
            sensitivity=sensitivity,
            memory_type=memory_type,
            importance=importance,
            confidence=0.86 if retention != MemoryRetention.session else 0.72,
            requires_confirmation=requires_confirmation,
            rationale=rationale,
            expires_in_minutes=1440 if retention == MemoryRetention.expiring else None,
        )
