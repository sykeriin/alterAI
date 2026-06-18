from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from hashlib import sha256
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator


class FutureId(StrEnum):
    future_a = "Future A"
    future_b = "Future B"
    future_c = "Future C"


class GoalCategory(StrEnum):
    career = "career"
    startup = "startup"
    wealth = "wealth"
    learning = "learning"
    leadership = "leadership"
    lifestyle = "lifestyle"
    reputation = "reputation"


class SkillCategory(StrEnum):
    technical = "technical"
    product = "product"
    business = "business"
    design = "design"
    leadership = "leadership"
    communication = "communication"
    domain = "domain"


class UserProfile(BaseModel):
    name: str | None = Field(default=None, max_length=120)
    current_role: str = Field(min_length=2, max_length=160)
    location: str | None = Field(default=None, max_length=120)
    industry: str | None = Field(default=None, max_length=120)
    current_salary: float | None = Field(default=None, ge=0)
    current_network_size: int = Field(default=120, ge=0, le=1_000_000)
    risk_tolerance: float = Field(default=0.5, ge=0.0, le=1.0)
    weekly_learning_hours: int = Field(default=6, ge=0, le=80)


class SkillInput(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    category: SkillCategory = SkillCategory.domain
    level: float = Field(ge=0.0, le=1.0)
    years: float = Field(default=0.0, ge=0.0, le=60.0)


class GoalInput(BaseModel):
    title: str = Field(min_length=2, max_length=220)
    category: GoalCategory = GoalCategory.career
    horizon_months: int = Field(default=36, ge=1, le=120)
    priority: int = Field(default=3, ge=1, le=5)


class ExperienceInput(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    organization: str | None = Field(default=None, max_length=160)
    domain: str | None = Field(default=None, max_length=120)
    years: float = Field(default=0.0, ge=0.0, le=60.0)
    impact: str | None = Field(default=None, max_length=500)


class FutureSimulationRequest(BaseModel):
    user_profile: UserProfile
    skills: list[SkillInput] = Field(min_length=1, max_length=80)
    goals: list[GoalInput] = Field(min_length=1, max_length=30)
    experience: list[ExperienceInput] = Field(default_factory=list, max_length=60)
    interests: list[str] = Field(default_factory=list, max_length=50)
    horizon_months: int | None = Field(default=None, ge=12, le=120)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    simulation_id: str = Field(default_factory=lambda: f"future_sim_{uuid4().hex}")

    @field_validator("interests")
    @classmethod
    def normalize_interests(cls, values: list[str]) -> list[str]:
        normalized = []
        seen = set()
        for value in values:
            item = " ".join(value.strip().split())
            key = item.lower()
            if item and key not in seen:
                normalized.append(item)
                seen.add(key)
        return normalized

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str | None) -> str | None:
        return value.upper() if value else value

    @property
    def input_digest(self) -> str:
        payload = self.model_dump_json(exclude={"simulation_id"}, exclude_none=True)
        return sha256(payload.encode("utf-8")).hexdigest()


class TimelineEvent(BaseModel):
    month: int = Field(ge=0, le=120)
    title: str = Field(min_length=2, max_length=180)
    description: str = Field(min_length=2, max_length=600)
    milestone_type: str = Field(min_length=2, max_length=80)


class SalaryPoint(BaseModel):
    month: int = Field(ge=0, le=120)
    low: int = Field(ge=0)
    expected: int = Field(ge=0)
    high: int = Field(ge=0)
    currency: str = Field(min_length=3, max_length=3)


class SkillTrajectoryPoint(BaseModel):
    month: int = Field(ge=0, le=120)
    skill: str = Field(min_length=1, max_length=100)
    projected_level: float = Field(ge=0.0, le=1.0)
    reason: str = Field(min_length=2, max_length=300)


class NetworkGrowthPoint(BaseModel):
    month: int = Field(ge=0, le=120)
    projected_network_size: int = Field(ge=0)
    high_value_connections: int = Field(ge=0)
    narrative: str = Field(min_length=2, max_length=320)


class FutureProjection(BaseModel):
    future_id: FutureId
    name: str = Field(min_length=2, max_length=160)
    thesis: str = Field(min_length=10, max_length=900)
    timeline: list[TimelineEvent] = Field(min_length=4, max_length=10)
    salary_trajectory: list[SalaryPoint] = Field(min_length=4, max_length=10)
    skill_trajectory: list[SkillTrajectoryPoint] = Field(min_length=4, max_length=24)
    network_growth: list[NetworkGrowthPoint] = Field(min_length=4, max_length=10)
    opportunity_score: float = Field(ge=0.0, le=100.0)
    risk_score: float = Field(ge=0.0, le=100.0)
    success_probability: float = Field(ge=0.0, le=1.0)
    assumptions: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    key_risks: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    key_opportunities: list[str] = Field(default_factory=list, min_length=1, max_length=10)
    recommended_next_actions: list[str] = Field(default_factory=list, min_length=1, max_length=8)


class SimulationSummary(BaseModel):
    best_expected_value_future: FutureId
    highest_upside_future: FutureId
    safest_future: FutureId
    recommendation: str = Field(min_length=10, max_length=1000)


class FutureSimulationResponse(BaseModel):
    model_config = ConfigDict(use_enum_values=True)

    simulation_id: str
    input_digest: str
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    horizon_months: int
    currency: str
    futures: list[FutureProjection] = Field(min_length=3, max_length=3)
    summary: SimulationSummary


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    output_contract: dict[str, Any]
