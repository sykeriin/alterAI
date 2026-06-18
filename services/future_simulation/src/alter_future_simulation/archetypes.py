from __future__ import annotations

from dataclasses import dataclass

from .schemas import FutureId, GoalCategory, SkillCategory


@dataclass(frozen=True)
class FutureArchetype:
    future_id: FutureId
    name: str
    thesis_template: str
    salary_multiplier: float
    upside_multiplier: float
    risk_multiplier: float
    network_multiplier: float
    target_skill_categories: tuple[SkillCategory, ...]
    preferred_goal_categories: tuple[GoalCategory, ...]
    milestone_titles: tuple[str, str, str, str]


FUTURE_ARCHETYPES: tuple[FutureArchetype, ...] = (
    FutureArchetype(
        future_id=FutureId.future_a,
        name="Focused Mastery Path",
        thesis_template=(
            "Double down on the strongest existing skill cluster, become visibly excellent, "
            "and convert that excellence into senior compensation and reputation leverage."
        ),
        salary_multiplier=1.28,
        upside_multiplier=0.82,
        risk_multiplier=0.66,
        network_multiplier=0.82,
        target_skill_categories=(
            SkillCategory.technical,
            SkillCategory.domain,
            SkillCategory.communication,
        ),
        preferred_goal_categories=(
            GoalCategory.career,
            GoalCategory.learning,
            GoalCategory.reputation,
        ),
        milestone_titles=(
            "Define mastery wedge",
            "Ship proof of expertise",
            "Convert expertise into leverage",
            "Move into premium role or advisory lane",
        ),
    ),
    FutureArchetype(
        future_id=FutureId.future_b,
        name="Founder Builder Path",
        thesis_template=(
            "Turn the user's goals and interests into a focused venture thesis, validate fast, "
            "build distribution, and compound through ownership rather than only salary."
        ),
        salary_multiplier=1.08,
        upside_multiplier=1.48,
        risk_multiplier=1.36,
        network_multiplier=1.44,
        target_skill_categories=(
            SkillCategory.product,
            SkillCategory.business,
            SkillCategory.leadership,
            SkillCategory.communication,
        ),
        preferred_goal_categories=(
            GoalCategory.startup,
            GoalCategory.wealth,
            GoalCategory.leadership,
        ),
        milestone_titles=(
            "Choose venture wedge",
            "Validate painful demand",
            "Recruit early believers",
            "Scale product and capital options",
        ),
    ),
    FutureArchetype(
        future_id=FutureId.future_c,
        name="Networked Leadership Path",
        thesis_template=(
            "Use experience, communication, and relationship density to become a trusted operator "
            "with access to better roles, deals, mentors, and high-signal opportunities."
        ),
        salary_multiplier=1.2,
        upside_multiplier=1.12,
        risk_multiplier=0.86,
        network_multiplier=1.72,
        target_skill_categories=(
            SkillCategory.leadership,
            SkillCategory.communication,
            SkillCategory.business,
            SkillCategory.domain,
        ),
        preferred_goal_categories=(
            GoalCategory.leadership,
            GoalCategory.reputation,
            GoalCategory.career,
        ),
        milestone_titles=(
            "Map strategic network",
            "Create visible trust signals",
            "Enter higher-quality rooms",
            "Compound authority into opportunities",
        ),
    ),
)

