from __future__ import annotations

import math
from dataclasses import dataclass

from .archetypes import FutureArchetype
from .schemas import FutureSimulationRequest, GoalCategory, SkillCategory


@dataclass(frozen=True)
class SimulationSignals:
    average_skill: float
    target_skill_fit: float
    total_experience_years: float
    experience_depth: float
    goal_alignment: float
    goal_clarity: float
    interest_density: float
    learning_capacity: float
    network_base: int
    risk_tolerance: float
    salary_base: int


@dataclass(frozen=True)
class FutureScores:
    opportunity_score: float
    risk_score: float
    success_probability: float
    expected_value: float
    upside_value: float


def extract_signals(
    request: FutureSimulationRequest,
    archetype: FutureArchetype,
    default_currency_salary_floor: int = 60_000,
) -> SimulationSignals:
    skills = request.skills
    goals = request.goals
    experience = request.experience

    average_skill = sum(skill.level for skill in skills) / len(skills)
    matching_skills = [
        skill for skill in skills if skill.category in archetype.target_skill_categories
    ]
    target_skill_fit = (
        sum(skill.level for skill in matching_skills) / len(matching_skills)
        if matching_skills
        else average_skill * 0.72
    )

    total_experience_years = sum(item.years for item in experience)
    experience_depth = _clamp(total_experience_years / 10.0, 0.0, 1.0)

    goal_alignment = _goal_alignment(goals, archetype.preferred_goal_categories)
    goal_clarity = _goal_clarity(goals)
    interest_density = _clamp(len(request.interests) / 8.0, 0.0, 1.0)
    learning_capacity = _clamp(request.user_profile.weekly_learning_hours / 12.0, 0.0, 1.0)
    network_base = request.user_profile.current_network_size
    risk_tolerance = request.user_profile.risk_tolerance
    salary_base = int(request.user_profile.current_salary or default_currency_salary_floor)

    return SimulationSignals(
        average_skill=average_skill,
        target_skill_fit=target_skill_fit,
        total_experience_years=total_experience_years,
        experience_depth=experience_depth,
        goal_alignment=goal_alignment,
        goal_clarity=goal_clarity,
        interest_density=interest_density,
        learning_capacity=learning_capacity,
        network_base=network_base,
        risk_tolerance=risk_tolerance,
        salary_base=salary_base,
    )


def score_future(
    signals: SimulationSignals,
    archetype: FutureArchetype,
) -> FutureScores:
    readiness = (
        signals.target_skill_fit * 0.32
        + signals.experience_depth * 0.2
        + signals.goal_alignment * 0.22
        + signals.goal_clarity * 0.14
        + signals.learning_capacity * 0.12
    )
    opportunity = 100 * _clamp(
        readiness * archetype.upside_multiplier
        + signals.interest_density * 0.08
        + math.log10(max(signals.network_base, 10)) * 0.035,
        0.0,
        1.0,
    )

    risk_pressure = (
        (1 - signals.target_skill_fit) * 0.28
        + (1 - signals.goal_clarity) * 0.16
        + (1 - signals.experience_depth) * 0.16
        + archetype.risk_multiplier * 0.22
        + (1 - signals.risk_tolerance) * 0.18
    )
    risk = 100 * _clamp(risk_pressure / 1.36, 0.0, 1.0)
    probability = _clamp((opportunity / 100) * 0.72 + (1 - risk / 100) * 0.28, 0.05, 0.95)

    return FutureScores(
        opportunity_score=round(opportunity, 1),
        risk_score=round(risk, 1),
        success_probability=round(probability, 3),
        expected_value=round(opportunity * probability - risk * 0.36, 3),
        upside_value=round(opportunity * archetype.upside_multiplier, 3),
    )


def _goal_alignment(
    goals: list,
    preferred_categories: tuple[GoalCategory, ...],
) -> float:
    total_weight = sum(goal.priority for goal in goals)
    if total_weight == 0:
        return 0.5
    matched_weight = sum(
        goal.priority for goal in goals if goal.category in preferred_categories
    )
    return _clamp(matched_weight / total_weight, 0.0, 1.0)


def _goal_clarity(goals: list) -> float:
    if not goals:
        return 0.0
    priority_strength = sum(goal.priority for goal in goals) / (len(goals) * 5)
    horizon_focus = sum(1 for goal in goals if goal.horizon_months <= 36) / len(goals)
    return _clamp(priority_strength * 0.66 + horizon_focus * 0.34, 0.0, 1.0)


def category_level(
    request: FutureSimulationRequest,
    category: SkillCategory,
    fallback: float,
) -> float:
    skills = [skill for skill in request.skills if skill.category == category]
    if not skills:
        return fallback
    return sum(skill.level for skill in skills) / len(skills)


def _clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))

