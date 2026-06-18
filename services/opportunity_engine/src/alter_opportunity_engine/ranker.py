from __future__ import annotations

from datetime import UTC, date, datetime

from .schemas import (
    Opportunity,
    OpportunityCategory,
    RankedOpportunity,
    RankingBreakdown,
    UserOpportunityProfile,
)


class OpportunityRanker:
    def rank(
        self,
        opportunities: list[Opportunity],
        profile: UserOpportunityProfile,
    ) -> list[RankedOpportunity]:
        ranked = [self.score(opportunity, profile) for opportunity in opportunities]
        return sorted(ranked, key=lambda item: item.score, reverse=True)

    def score(
        self,
        opportunity: Opportunity,
        profile: UserOpportunityProfile,
    ) -> RankedOpportunity:
        user_fit = _overlap_score(
            [*opportunity.skills, *opportunity.tags, *opportunity.interests],
            [*profile.skills, *profile.goals, *profile.interests],
        )
        category_fit = (
            1.0
            if not profile.preferred_categories
            else 1.0
            if opportunity.category in profile.preferred_categories
            else 0.35
        )
        urgency = _urgency_score(opportunity.deadline)
        strategic_upside = _strategic_upside(opportunity.category, profile)
        breakdown = RankingBreakdown(
            source_quality=opportunity.source_quality,
            user_fit=user_fit,
            category_fit=category_fit,
            urgency=urgency,
            freshness=opportunity.freshness_score,
            strategic_upside=strategic_upside,
        )
        score = round(
            100
            * (
                breakdown.user_fit * 0.3
                + breakdown.category_fit * 0.16
                + breakdown.source_quality * 0.16
                + breakdown.urgency * 0.12
                + breakdown.freshness * 0.1
                + breakdown.strategic_upside * 0.16
            ),
            2,
        )
        return RankedOpportunity(
            opportunity=opportunity.model_copy(update={"status": "ranked"}),
            score=score,
            breakdown=breakdown,
            reasons=_reasons(opportunity, breakdown),
        )


def _overlap_score(left: list[str], right: list[str]) -> float:
    if not right:
        return 0.5
    left_terms = {_normalize(item) for item in left if item}
    right_terms = {_normalize(item) for item in right if item}
    if not right_terms:
        return 0.5
    exact = len(left_terms & right_terms) / len(right_terms)
    fuzzy = sum(
        1
        for right_term in right_terms
        if any(right_term in left_term or left_term in right_term for left_term in left_terms)
    ) / len(right_terms)
    return min(1.0, exact * 0.7 + fuzzy * 0.3)


def _urgency_score(deadline: date | None) -> float:
    if deadline is None:
        return 0.45
    days = (deadline - datetime.now(UTC).date()).days
    if days < 0:
        return 0.05
    if days <= 7:
        return 1.0
    if days <= 30:
        return 0.82
    if days <= 90:
        return 0.58
    return 0.35


def _strategic_upside(
    category: OpportunityCategory,
    profile: UserOpportunityProfile,
) -> float:
    high_upside = {
        OpportunityCategory.accelerator,
        OpportunityCategory.grant,
        OpportunityCategory.fellowship,
        OpportunityCategory.research,
        OpportunityCategory.hackathon,
    }
    base = 0.78 if category in high_upside else 0.56
    if "founder" in profile.career_stage.lower() and category in {
        OpportunityCategory.accelerator,
        OpportunityCategory.grant,
        OpportunityCategory.startup,
    }:
        base += 0.16
    return min(1.0, base + profile.risk_tolerance * 0.08)


def _reasons(
    opportunity: Opportunity,
    breakdown: RankingBreakdown,
) -> list[str]:
    reasons = []
    if breakdown.user_fit >= 0.55:
        reasons.append("Strong match with user skills, goals, or interests.")
    if breakdown.urgency >= 0.8:
        reasons.append("Deadline is time-sensitive.")
    if breakdown.source_quality >= 0.8:
        reasons.append("High-trust source.")
    if breakdown.strategic_upside >= 0.75:
        reasons.append(f"{opportunity.category} has strong strategic upside.")
    return reasons or ["Balanced opportunity with moderate fit."]


def _normalize(value: str) -> str:
    return value.lower().strip().replace("-", " ")

