from __future__ import annotations

import re
from datetime import UTC, date, datetime, timedelta

from .schemas import Opportunity, OpportunityCategory, OpportunityStatus, RawOpportunity
from .sources import SOURCE_DEFINITIONS


class OpportunityNormalizer:
    def normalize(self, raw: RawOpportunity) -> Opportunity:
        text = _clean(raw.raw_text)
        category = categorize_text(" ".join([raw.title, text, " ".join(raw.tags)]))
        skills = _extract_keywords(text, _SKILL_KEYWORDS)
        interests = _extract_keywords(text, _INTEREST_KEYWORDS)
        benefits = _extract_keywords(text, _BENEFIT_KEYWORDS)
        eligibility = _extract_eligibility(text)
        source_quality = SOURCE_DEFINITIONS.get(raw.source).source_quality
        return Opportunity(
            source=raw.source,
            source_url=raw.source_url,
            external_id=raw.external_id,
            title=_clean(raw.title),
            organization=raw.organization or "Unknown",
            description=text[:4000],
            category=category,
            status=OpportunityStatus.categorized,
            location=raw.location,
            deadline=_parse_deadline(raw.deadline_text),
            skills=skills,
            interests=interests,
            tags=_dedupe([*raw.tags, category.value, *skills, *interests]),
            eligibility=eligibility,
            benefits=benefits,
            source_quality=source_quality,
            freshness_score=_freshness(raw.captured_at),
            metadata={**raw.metadata, "deadline_text": raw.deadline_text},
        )


def categorize_text(text: str) -> OpportunityCategory:
    lowered = text.lower()
    rules = [
        (OpportunityCategory.internship, ["internship", "intern ", "interns"]),
        (OpportunityCategory.hackathon, ["hackathon", "buildathon", "devpost"]),
        (OpportunityCategory.grant, ["grant", "non-dilutive", "funding"]),
        (OpportunityCategory.accelerator, ["accelerator", "yc", "founder program"]),
        (OpportunityCategory.fellowship, ["fellowship", "fellow"]),
        (OpportunityCategory.research, ["research", "lab", "publication"]),
        (OpportunityCategory.competition, ["competition", "challenge", "prize"]),
        (OpportunityCategory.scholarship, ["scholarship", "tuition"]),
        (OpportunityCategory.job, ["job", "role", "hiring", "full-time"]),
        (OpportunityCategory.program, ["program", "cohort", "student"]),
        (OpportunityCategory.startup, ["startup", "founder", "venture"]),
    ]
    for category, needles in rules:
        if any(needle in lowered for needle in needles):
            return category
    return OpportunityCategory.unknown


def _parse_deadline(value: str | None) -> date | None:
    if not value:
        return None
    iso = re.search(r"\b(20\d{2})-(\d{2})-(\d{2})\b", value)
    if iso:
        return date(int(iso.group(1)), int(iso.group(2)), int(iso.group(3)))
    days = re.search(r"within\s+(\d{1,3})\s+days", value.lower())
    if days:
        return (datetime.now(UTC) + timedelta(days=int(days.group(1)))).date()
    return None


def _freshness(captured_at: datetime) -> float:
    age_days = max(0, (datetime.now(UTC) - captured_at).days)
    return max(0.1, 1 - age_days / 45)


def _extract_keywords(text: str, keywords: list[str]) -> list[str]:
    lowered = text.lower()
    return [keyword for keyword in keywords if keyword.lower() in lowered][:12]


def _extract_eligibility(text: str) -> list[str]:
    lowered = text.lower()
    matches = []
    if "student" in lowered:
        matches.append("student")
    if "founder" in lowered:
        matches.append("founder")
    if "open source" in lowered:
        matches.append("open source contributor")
    if "remote" in lowered:
        matches.append("remote eligible")
    return matches


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _dedupe(values: list[str]) -> list[str]:
    seen = set()
    result = []
    for value in values:
        clean = value.strip()
        key = clean.lower()
        if clean and key not in seen:
            result.append(clean)
            seen.add(key)
    return result[:50]


_SKILL_KEYWORDS = [
    "Python",
    "FastAPI",
    "AI",
    "machine learning",
    "open source",
    "cloud",
    "Android",
    "product",
    "analytics",
    "backend",
    "design",
    "research",
    "sales",
]

_INTEREST_KEYWORDS = [
    "startup",
    "founder",
    "AI agents",
    "developer tools",
    "productivity",
    "education",
    "healthcare",
    "climate",
    "automation",
    "leadership",
]

_BENEFIT_KEYWORDS = [
    "mentorship",
    "prizes",
    "funding",
    "grant",
    "hiring access",
    "network",
    "scholarship",
]

