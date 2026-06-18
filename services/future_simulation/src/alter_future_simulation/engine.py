from __future__ import annotations

from .archetypes import FUTURE_ARCHETYPES, FutureArchetype
from .schemas import (
    FutureProjection,
    FutureSimulationRequest,
    FutureSimulationResponse,
    NetworkGrowthPoint,
    SalaryPoint,
    SimulationSummary,
    SkillTrajectoryPoint,
    TimelineEvent,
)
from .scoring import SimulationSignals, category_level, extract_signals, score_future


class FutureSimulationEngine:
    """Deterministic trajectory simulation engine."""

    def simulate(
        self,
        request: FutureSimulationRequest,
        *,
        horizon_months: int,
        currency: str,
    ) -> FutureSimulationResponse:
        futures = [
            self._project_future(request, archetype, horizon_months, currency)
            for archetype in FUTURE_ARCHETYPES
        ]
        return FutureSimulationResponse(
            simulation_id=request.simulation_id,
            input_digest=request.input_digest,
            horizon_months=horizon_months,
            currency=currency,
            futures=futures,
            summary=self._summarize(futures),
        )

    def _project_future(
        self,
        request: FutureSimulationRequest,
        archetype: FutureArchetype,
        horizon_months: int,
        currency: str,
    ) -> FutureProjection:
        signals = extract_signals(request, archetype)
        scores = score_future(signals, archetype)
        checkpoints = _checkpoints(horizon_months)

        return FutureProjection(
            future_id=archetype.future_id,
            name=archetype.name,
            thesis=self._thesis(request, archetype, signals),
            timeline=self._timeline(archetype, checkpoints, request),
            salary_trajectory=self._salary_trajectory(
                archetype,
                signals,
                checkpoints,
                currency,
            ),
            skill_trajectory=self._skill_trajectory(
                request,
                archetype,
                signals,
                checkpoints,
            ),
            network_growth=self._network_growth(
                archetype,
                signals,
                checkpoints,
            ),
            opportunity_score=scores.opportunity_score,
            risk_score=scores.risk_score,
            success_probability=scores.success_probability,
            assumptions=self._assumptions(request, archetype, signals),
            key_risks=self._risks(archetype),
            key_opportunities=self._opportunities(archetype),
            recommended_next_actions=self._next_actions(archetype),
        )

    def _thesis(
        self,
        request: FutureSimulationRequest,
        archetype: FutureArchetype,
        signals: SimulationSignals,
    ) -> str:
        role = request.user_profile.current_role
        strongest_skill = max(request.skills, key=lambda skill: skill.level).name
        top_goal = max(request.goals, key=lambda goal: goal.priority).title
        return (
            f"{archetype.thesis_template} Starting from {role}, the strongest lever is "
            f"{strongest_skill}. The main strategic goal is {top_goal}. Current readiness "
            f"is supported by {signals.total_experience_years:.1f} years of mapped experience."
        )

    def _timeline(
        self,
        archetype: FutureArchetype,
        checkpoints: list[int],
        request: FutureSimulationRequest,
    ) -> list[TimelineEvent]:
        top_interest = request.interests[0] if request.interests else "high-signal work"
        descriptions = (
            f"Translate current profile into a focused wedge around {top_interest}.",
            "Create visible proof through a portfolio artifact, shipped project, "
            "or validated offer.",
            "Use proof to unlock better rooms, sharper feedback, and higher-value opportunities.",
            "Consolidate gains into a durable role, company, advisory lane, or platform advantage.",
        )
        milestone_types = ("strategy", "proof", "distribution", "leverage")
        return [
            TimelineEvent(
                month=month,
                title=archetype.milestone_titles[index],
                description=descriptions[index],
                milestone_type=milestone_types[index],
            )
            for index, month in enumerate(checkpoints)
        ]

    def _salary_trajectory(
        self,
        archetype: FutureArchetype,
        signals: SimulationSignals,
        checkpoints: list[int],
        currency: str,
    ) -> list[SalaryPoint]:
        points = []
        for index, month in enumerate(checkpoints):
            progress = index / max(len(checkpoints) - 1, 1)
            growth = 1 + progress * (
                archetype.salary_multiplier
                + signals.target_skill_fit * 0.42
                + signals.goal_alignment * 0.18
                - 1
            )
            expected = int(round(signals.salary_base * growth, -3))
            spread = 0.14 + archetype.risk_multiplier * 0.045 + progress * 0.07
            points.append(
                SalaryPoint(
                    month=month,
                    low=int(round(expected * (1 - spread), -3)),
                    expected=expected,
                    high=int(
                        round(
                            expected
                            * (1 + spread + archetype.upside_multiplier * 0.05),
                            -3,
                        )
                    ),
                    currency=currency,
                )
            )
        return points

    def _skill_trajectory(
        self,
        request: FutureSimulationRequest,
        archetype: FutureArchetype,
        signals: SimulationSignals,
        checkpoints: list[int],
    ) -> list[SkillTrajectoryPoint]:
        trajectory = []
        for category in archetype.target_skill_categories[:4]:
            baseline = category_level(request, category, signals.average_skill * 0.82)
            for month in checkpoints:
                progress = month / max(checkpoints[-1], 1)
                lift = 0.1 + signals.learning_capacity * 0.2 + progress * 0.18
                projected = min(1.0, baseline + lift * progress)
                trajectory.append(
                    SkillTrajectoryPoint(
                        month=month,
                        skill=category.value,
                        projected_level=round(projected, 3),
                        reason=(
                            f"{archetype.name} requires compounding {category.value} capability."
                        ),
                    )
                )
        return trajectory

    def _network_growth(
        self,
        archetype: FutureArchetype,
        signals: SimulationSignals,
        checkpoints: list[int],
    ) -> list[NetworkGrowthPoint]:
        points = []
        for index, month in enumerate(checkpoints):
            progress = index / max(len(checkpoints) - 1, 1)
            growth = 1 + progress * (
                archetype.network_multiplier
                + signals.goal_alignment * 0.22
                + signals.interest_density * 0.14
                - 1
            )
            projected = int(signals.network_base * growth)
            high_value = int(projected * (0.06 + progress * 0.08))
            points.append(
                NetworkGrowthPoint(
                    month=month,
                    projected_network_size=projected,
                    high_value_connections=high_value,
                    narrative=(
                        "Network expands through visible proof, targeted asks, "
                        "and compounding trust."
                    ),
                )
            )
        return points

    def _assumptions(
        self,
        request: FutureSimulationRequest,
        archetype: FutureArchetype,
        signals: SimulationSignals,
    ) -> list[str]:
        return [
            "The user can sustain "
            f"{request.user_profile.weekly_learning_hours} learning hours weekly.",
            "Goals remain directionally stable for the next two quarters.",
            f"{archetype.name} receives enough market feedback to update decisions quickly.",
            f"Current mapped experience is {signals.total_experience_years:.1f} years.",
        ]

    def _risks(self, archetype: FutureArchetype) -> list[str]:
        shared = [
            "Weak feedback loops could make the path look better than reality.",
            "Skill growth may lag if weekly practice is not protected.",
        ]
        by_future = {
            "Future A": "Over-specialization can reduce optionality if the market shifts.",
            "Future B": "Founder path has higher variance, delayed salary, and execution pressure.",
            "Future C": "Network-led growth can become shallow without clear proof of value.",
        }
        return [*shared, by_future[archetype.future_id.value]]

    def _opportunities(self, archetype: FutureArchetype) -> list[str]:
        by_future = {
            "Future A": [
                "Premium compensation through visible expertise.",
                "Advisory, consulting, or senior individual contributor leverage.",
            ],
            "Future B": [
                "Ownership upside if validation converts into distribution.",
                "Recruiting and investor leverage from a clear venture wedge.",
            ],
            "Future C": [
                "Better rooms, stronger mentors, and higher-signal opportunities.",
                "Leadership credibility that compounds across roles and deals.",
            ],
        }
        return by_future[archetype.future_id.value]

    def _next_actions(self, archetype: FutureArchetype) -> list[str]:
        by_future = {
            "Future A": [
                "Pick one mastery wedge and publish a proof artifact within 14 days.",
                "Ask three senior operators what proof would change their mind.",
                "Block two weekly deep-work sessions for skill compounding.",
            ],
            "Future B": [
                "Interview ten target users before building more product.",
                "Define one painful problem and one paid validation offer.",
                "Map five potential early believers or design partners.",
            ],
            "Future C": [
                "Create a relationship map of 30 high-signal people.",
                "Send five useful follow-ups with a clear value exchange.",
                "Join or host one room where the desired future already exists.",
            ],
        }
        return by_future[archetype.future_id.value]

    def _summarize(self, futures: list[FutureProjection]) -> SimulationSummary:
        expected_values = {
            future.future_id: future.opportunity_score * future.success_probability
            - future.risk_score * 0.28
            for future in futures
        }
        best_expected = max(expected_values, key=expected_values.get)
        highest_upside = max(futures, key=lambda future: future.opportunity_score).future_id
        safest = min(futures, key=lambda future: future.risk_score).future_id
        return SimulationSummary(
            best_expected_value_future=best_expected,
            highest_upside_future=highest_upside,
            safest_future=safest,
            recommendation=(
                f"Prioritize {best_expected}. It has the strongest blend of opportunity, "
                "risk-adjusted probability, and near-term actionability. Keep the other futures "
                "as option paths and rerun the simulation after new evidence arrives."
            ),
        )


def _checkpoints(horizon_months: int) -> list[int]:
    return [
        0,
        max(3, round(horizon_months * 0.25)),
        max(6, round(horizon_months * 0.55)),
        horizon_months,
    ]
