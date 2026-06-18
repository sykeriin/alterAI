from __future__ import annotations

from .config import Settings, get_settings
from .crawlers import OpportunityCrawlerRouter
from .normalizer import OpportunityNormalizer, categorize_text
from .ranker import OpportunityRanker
from .recommender import OpportunityRecommender
from .repository import InMemoryOpportunityRepository, OpportunityRepository
from .schemas import (
    CategorizeRequest,
    CategorizeResponse,
    CrawlRequest,
    CrawlResponse,
    NormalizeRequest,
    NormalizeResponse,
    PipelineRequest,
    PipelineResponse,
    RankRequest,
    RankResponse,
    RecommendRequest,
    RecommendResponse,
)


class OpportunityService:
    def __init__(
        self,
        *,
        settings: Settings,
        crawler: OpportunityCrawlerRouter,
        repository: OpportunityRepository,
        normalizer: OpportunityNormalizer,
        ranker: OpportunityRanker,
        recommender: OpportunityRecommender,
    ) -> None:
        self._settings = settings
        self._crawler = crawler
        self._repository = repository
        self._normalizer = normalizer
        self._ranker = ranker
        self._recommender = recommender

    async def crawl(self, request: CrawlRequest) -> CrawlResponse:
        if not request.sources:
            request = request.model_copy(
                update={
                    "limit_per_source": request.limit_per_source
                    or self._settings.default_crawl_limit
                }
            )
        raw, notes = await self._crawler.crawl(request)
        return CrawlResponse(
            raw_opportunities=raw,
            source_count=len(request.sources) if request.sources else 9,
            notes=notes,
        )

    def normalize(self, request: NormalizeRequest) -> NormalizeResponse:
        opportunities = [
            self._normalizer.normalize(raw) for raw in request.raw_opportunities
        ]
        self._repository.upsert_many(opportunities)
        return NormalizeResponse(opportunities=opportunities)

    def categorize(self, request: CategorizeRequest) -> CategorizeResponse:
        opportunities = [
            opportunity.model_copy(
                update={
                    "category": categorize_text(
                        " ".join(
                            [
                                opportunity.title,
                                opportunity.description,
                                " ".join(opportunity.tags),
                            ]
                        )
                    ),
                    "status": "categorized",
                }
            )
            for opportunity in request.opportunities
        ]
        self._repository.upsert_many(opportunities)
        return CategorizeResponse(opportunities=opportunities)

    def rank(self, request: RankRequest) -> RankResponse:
        return RankResponse(
            ranked_opportunities=self._ranker.rank(request.opportunities, request.profile)
        )

    def recommend(self, request: RecommendRequest) -> RecommendResponse:
        return RecommendResponse(
            recommendations=self._recommender.recommend(
                profile=request.profile,
                opportunities=request.opportunities,
                ranked_opportunities=request.ranked_opportunities,
                limit=request.limit,
            )
        )

    async def pipeline(self, request: PipelineRequest) -> PipelineResponse:
        crawl = await self.crawl(request.crawl)
        normalized = self.normalize(
            NormalizeRequest(raw_opportunities=crawl.raw_opportunities)
        )
        categorized = self.categorize(
            CategorizeRequest(opportunities=normalized.opportunities)
        )
        ranked = self.rank(
            RankRequest(profile=request.profile, opportunities=categorized.opportunities)
        )
        recommendations = self.recommend(
            RecommendRequest(
                profile=request.profile,
                ranked_opportunities=ranked.ranked_opportunities,
                limit=request.limit,
            )
        )
        return PipelineResponse(
            crawl=crawl,
            normalized=normalized,
            categorized=categorized,
            ranked=ranked,
            recommendations=recommendations,
        )


def create_opportunity_service(
    *,
    settings: Settings | None = None,
    repository: OpportunityRepository | None = None,
) -> OpportunityService:
    resolved_settings = settings or get_settings()
    ranker = OpportunityRanker()
    return OpportunityService(
        settings=resolved_settings,
        crawler=OpportunityCrawlerRouter(resolved_settings),
        repository=repository or InMemoryOpportunityRepository(),
        normalizer=OpportunityNormalizer(),
        ranker=ranker,
        recommender=OpportunityRecommender(ranker),
    )
