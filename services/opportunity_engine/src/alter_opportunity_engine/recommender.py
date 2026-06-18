from __future__ import annotations

from .ranker import OpportunityRanker
from .schemas import (
    Opportunity,
    OpportunityCategory,
    OpportunityRecommendation,
    RankedOpportunity,
    UserOpportunityProfile,
)


class OpportunityRecommender:
    def __init__(self, ranker: OpportunityRanker | None = None) -> None:
        self._ranker = ranker or OpportunityRanker()

    def recommend(
        self,
        *,
        profile: UserOpportunityProfile,
        opportunities: list[Opportunity] | None = None,
        ranked_opportunities: list[RankedOpportunity] | None = None,
        limit: int,
    ) -> list[OpportunityRecommendation]:
        ranked = ranked_opportunities or self._ranker.rank(opportunities or [], profile)
        return [self._recommend_one(item) for item in ranked[:limit]]

    def _recommend_one(self, ranked: RankedOpportunity) -> OpportunityRecommendation:
        opportunity = ranked.opportunity.model_copy(update={"status": "recommended"})
        return OpportunityRecommendation(
            opportunity=opportunity,
            score=ranked.score,
            recommendation=_recommendation_text(ranked),
            next_actions=_next_actions(opportunity),
            why_now=_why_now(ranked),
            risks=_risks(opportunity),
        )


def _recommendation_text(ranked: RankedOpportunity) -> str:
    opportunity = ranked.opportunity
    return (
        f"Prioritize {opportunity.title}. It scores {ranked.score:.1f}/100 because "
        f"{'; '.join(ranked.reasons).lower()}"
    )


def _next_actions(opportunity: Opportunity) -> list[str]:
    actions = [
        "Open the source page and verify current deadline and eligibility.",
        "Prepare a tailored application note mapped to your strongest proof.",
    ]
    if opportunity.category in {OpportunityCategory.hackathon, OpportunityCategory.competition}:
        actions.append("Recruit one collaborator and define a build scope within 24 hours.")
    elif opportunity.category in {OpportunityCategory.grant, OpportunityCategory.accelerator}:
        actions.append("Draft the venture thesis, traction proof, and funding use case.")
    elif opportunity.category == OpportunityCategory.research:
        actions.append("Collect publications, projects, and a concise research statement.")
    else:
        actions.append("Send or save the application with a follow-up reminder.")
    return actions


def _why_now(ranked: RankedOpportunity) -> str:
    if ranked.breakdown.urgency >= 0.8:
        return "The application window appears time-sensitive."
    if ranked.breakdown.freshness >= 0.8:
        return "The opportunity appears fresh and worth checking before it gets crowded."
    return "The fit is good enough to validate eligibility now."


def _risks(opportunity: Opportunity) -> list[str]:
    risks = ["Listing details may change; verify on the official source before acting."]
    if opportunity.deadline is None:
        risks.append("Deadline is unknown, so urgency may be misestimated.")
    if opportunity.source_url is None:
        risks.append("No canonical URL was captured; source verification is required.")
    return risks

