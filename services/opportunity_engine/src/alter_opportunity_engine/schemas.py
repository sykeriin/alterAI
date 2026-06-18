from __future__ import annotations

from datetime import UTC, date, datetime
from enum import StrEnum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, field_validator


class OpportunitySource(StrEnum):
    linkedin = "linkedin"
    internshala = "internshala"
    unstop = "unstop"
    devpost = "devpost"
    yc = "yc"
    gsoc = "gsoc"
    google_programs = "google_programs"
    research_fellowships = "research_fellowships"
    startup_grants = "startup_grants"
    manual = "manual"


class CrawlMode(StrEnum):
    firecrawl_search = "firecrawl_search"
    firecrawl_scrape = "firecrawl_scrape"
    public_feed = "public_feed"
    official_api = "official_api"
    manual_import = "manual_import"
    seed = "seed"


class OpportunityCategory(StrEnum):
    internship = "internship"
    fellowship = "fellowship"
    hackathon = "hackathon"
    accelerator = "accelerator"
    grant = "grant"
    research = "research"
    job = "job"
    competition = "competition"
    program = "program"
    scholarship = "scholarship"
    startup = "startup"
    unknown = "unknown"


class OpportunityStatus(StrEnum):
    discovered = "discovered"
    normalized = "normalized"
    categorized = "categorized"
    ranked = "ranked"
    recommended = "recommended"
    archived = "archived"


class SourceDefinition(BaseModel):
    source: OpportunitySource
    display_name: str
    allowed_modes: list[CrawlMode]
    default_query: str
    source_quality: float = Field(ge=0.0, le=1.0)
    compliance_note: str


class RawOpportunity(BaseModel):
    source: OpportunitySource
    source_url: str | None = None
    external_id: str | None = None
    title: str = Field(min_length=2, max_length=300)
    organization: str | None = Field(default=None, max_length=220)
    raw_text: str = Field(min_length=2, max_length=20000)
    location: str | None = Field(default=None, max_length=160)
    deadline_text: str | None = Field(default=None, max_length=160)
    tags: list[str] = Field(default_factory=list, max_length=40)
    captured_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    metadata: dict[str, Any] = Field(default_factory=dict)


class Opportunity(BaseModel):
    model_config = ConfigDict(use_enum_values=True)

    id: UUID = Field(default_factory=uuid4)
    source: OpportunitySource
    source_url: str | None = None
    external_id: str | None = None
    title: str = Field(min_length=2, max_length=300)
    organization: str = Field(default="Unknown", max_length=220)
    description: str = Field(min_length=2, max_length=4000)
    category: OpportunityCategory = OpportunityCategory.unknown
    status: OpportunityStatus = OpportunityStatus.normalized
    location: str | None = Field(default=None, max_length=160)
    deadline: date | None = None
    skills: list[str] = Field(default_factory=list, max_length=40)
    interests: list[str] = Field(default_factory=list, max_length=40)
    tags: list[str] = Field(default_factory=list, max_length=50)
    eligibility: list[str] = Field(default_factory=list, max_length=20)
    benefits: list[str] = Field(default_factory=list, max_length=20)
    source_quality: float = Field(default=0.5, ge=0.0, le=1.0)
    freshness_score: float = Field(default=0.5, ge=0.0, le=1.0)
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class UserOpportunityProfile(BaseModel):
    user_id: UUID | None = None
    career_stage: str = Field(default="early", max_length=80)
    skills: list[str] = Field(default_factory=list, max_length=80)
    goals: list[str] = Field(default_factory=list, max_length=40)
    interests: list[str] = Field(default_factory=list, max_length=80)
    preferred_locations: list[str] = Field(default_factory=list, max_length=20)
    preferred_categories: list[OpportunityCategory] = Field(default_factory=list, max_length=20)
    risk_tolerance: float = Field(default=0.5, ge=0.0, le=1.0)


class CrawlRequest(BaseModel):
    sources: list[OpportunitySource] = Field(default_factory=list)
    query: str | None = Field(default=None, max_length=500)
    limit_per_source: int = Field(default=20, ge=1, le=100)
    mode: CrawlMode | None = None
    public_urls: dict[OpportunitySource, list[str]] = Field(default_factory=dict)


class CrawlResponse(BaseModel):
    raw_opportunities: list[RawOpportunity]
    source_count: int
    notes: list[str]


class NormalizeRequest(BaseModel):
    raw_opportunities: list[RawOpportunity] = Field(min_length=1, max_length=500)


class NormalizeResponse(BaseModel):
    opportunities: list[Opportunity]


class CategorizeRequest(BaseModel):
    opportunities: list[Opportunity] = Field(min_length=1, max_length=500)


class CategorizeResponse(BaseModel):
    opportunities: list[Opportunity]


class RankingBreakdown(BaseModel):
    source_quality: float = Field(ge=0.0, le=1.0)
    user_fit: float = Field(ge=0.0, le=1.0)
    category_fit: float = Field(ge=0.0, le=1.0)
    urgency: float = Field(ge=0.0, le=1.0)
    freshness: float = Field(ge=0.0, le=1.0)
    strategic_upside: float = Field(ge=0.0, le=1.0)


class RankedOpportunity(BaseModel):
    opportunity: Opportunity
    score: float = Field(ge=0.0, le=100.0)
    breakdown: RankingBreakdown
    reasons: list[str] = Field(default_factory=list)


class RankRequest(BaseModel):
    profile: UserOpportunityProfile
    opportunities: list[Opportunity] = Field(min_length=1, max_length=500)


class RankResponse(BaseModel):
    ranked_opportunities: list[RankedOpportunity]


class OpportunityRecommendation(BaseModel):
    opportunity: Opportunity
    score: float = Field(ge=0.0, le=100.0)
    recommendation: str
    next_actions: list[str]
    why_now: str
    risks: list[str]


class RecommendRequest(BaseModel):
    profile: UserOpportunityProfile
    opportunities: list[Opportunity] = Field(default_factory=list, max_length=500)
    ranked_opportunities: list[RankedOpportunity] = Field(default_factory=list, max_length=500)
    limit: int = Field(default=10, ge=1, le=50)

    @field_validator("ranked_opportunities")
    @classmethod
    def require_inputs(
        cls,
        value: list[RankedOpportunity],
        info,
    ) -> list[RankedOpportunity]:
        opportunities = info.data.get("opportunities", [])
        if not value and not opportunities:
            raise ValueError("provide opportunities or ranked_opportunities")
        return value


class RecommendResponse(BaseModel):
    recommendations: list[OpportunityRecommendation]


class PipelineRequest(BaseModel):
    profile: UserOpportunityProfile
    crawl: CrawlRequest = Field(default_factory=CrawlRequest)
    limit: int = Field(default=10, ge=1, le=50)


class PipelineResponse(BaseModel):
    crawl: CrawlResponse
    normalized: NormalizeResponse
    categorized: CategorizeResponse
    ranked: RankResponse
    recommendations: RecommendResponse


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str

