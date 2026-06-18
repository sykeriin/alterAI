from __future__ import annotations

from alter_future_simulation.schemas import (
    ExperienceInput,
    FutureSimulationRequest,
    GoalCategory,
    GoalInput,
    SkillCategory,
    SkillInput,
    UserProfile,
)
from alter_future_simulation.service import create_future_simulation_service


def _request() -> FutureSimulationRequest:
    return FutureSimulationRequest(
        user_profile=UserProfile(
            name="Aria",
            current_role="Senior product engineer",
            industry="AI productivity",
            current_salary=140000,
            current_network_size=420,
            risk_tolerance=0.62,
            weekly_learning_hours=9,
        ),
        skills=[
            SkillInput(name="Python", category=SkillCategory.technical, level=0.82, years=6),
            SkillInput(name="Product strategy", category=SkillCategory.product, level=0.7, years=4),
            SkillInput(name="Founder sales", category=SkillCategory.business, level=0.58, years=2),
            SkillInput(
                name="Team leadership",
                category=SkillCategory.leadership,
                level=0.64,
                years=3,
            ),
            SkillInput(name="Writing", category=SkillCategory.communication, level=0.76, years=5),
        ],
        goals=[
            GoalInput(
                title="Build a premium AI operating system",
                category=GoalCategory.startup,
                horizon_months=36,
                priority=5,
            ),
            GoalInput(
                title="Become known for future-of-work systems",
                category=GoalCategory.reputation,
                horizon_months=24,
                priority=4,
            ),
        ],
        experience=[
            ExperienceInput(
                title="Led AI workflow product",
                organization="Venture-backed startup",
                domain="AI",
                years=3,
                impact="Launched workflow automation used by 30 teams.",
            ),
            ExperienceInput(
                title="Built internal developer platform",
                organization="Scaleup",
                domain="Infrastructure",
                years=4,
                impact="Reduced release cycle time by 40 percent.",
            ),
        ],
        interests=["AI agents", "networking", "future of work"],
        horizon_months=36,
        currency="USD",
    )


def test_simulation_returns_three_structured_futures() -> None:
    service = create_future_simulation_service()
    response = service.simulate(_request())

    assert response.simulation_id.startswith("future_sim_")
    assert response.horizon_months == 36
    assert response.currency == "USD"
    assert len(response.futures) == 3
    assert {future.future_id for future in response.futures} == {
        "Future A",
        "Future B",
        "Future C",
    }

    for future in response.futures:
        assert future.timeline
        assert future.salary_trajectory
        assert future.skill_trajectory
        assert future.network_growth
        assert 0 <= future.opportunity_score <= 100
        assert 0 <= future.risk_score <= 100
        assert 0 <= future.success_probability <= 1


def test_service_caps_horizon_to_settings_limit() -> None:
    service = create_future_simulation_service()
    request = _request().model_copy(update={"horizon_months": 120})

    response = service.simulate(request)

    assert response.horizon_months == 60
    for future in response.futures:
        assert future.timeline[-1].month == 60
