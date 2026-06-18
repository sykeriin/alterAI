from __future__ import annotations

from .schemas import CrawlMode, OpportunitySource, SourceDefinition

SOURCE_DEFINITIONS: dict[OpportunitySource, SourceDefinition] = {
    OpportunitySource.linkedin: SourceDefinition(
        source=OpportunitySource.linkedin,
        display_name="LinkedIn",
        allowed_modes=[
            CrawlMode.official_api,
            CrawlMode.manual_import,
            CrawlMode.public_feed,
        ],
        default_query="site:linkedin.com/jobs internships fellowships startup programs",
        source_quality=0.72,
        compliance_note=(
            "Use official APIs, approved partner feeds, user exports, "
            "or configured public URLs only."
        ),
    ),
    OpportunitySource.internshala: SourceDefinition(
        source=OpportunitySource.internshala,
        display_name="Internshala",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Internshala internships AI software startup remote",
        source_quality=0.7,
        compliance_note="Use public listings or approved feeds; respect robots and rate limits.",
    ),
    OpportunitySource.unstop: SourceDefinition(
        source=OpportunitySource.unstop,
        display_name="Unstop",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Unstop competitions hackathons fellowships students startups",
        source_quality=0.74,
        compliance_note="Use public listings or approved feeds; respect robots and rate limits.",
    ),
    OpportunitySource.devpost: SourceDefinition(
        source=OpportunitySource.devpost,
        display_name="Devpost",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Devpost hackathons AI developer challenge",
        source_quality=0.78,
        compliance_note="Use public hackathon pages and configured source URLs.",
    ),
    OpportunitySource.yc: SourceDefinition(
        source=OpportunitySource.yc,
        display_name="Y Combinator",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Y Combinator startup program application funding founders",
        source_quality=0.92,
        compliance_note="Use public YC pages and official announcements.",
    ),
    OpportunitySource.gsoc: SourceDefinition(
        source=OpportunitySource.gsoc,
        display_name="Google Summer of Code",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Google Summer of Code open source contributor program",
        source_quality=0.88,
        compliance_note="Use official GSoC public pages and feeds.",
    ),
    OpportunitySource.google_programs: SourceDefinition(
        source=OpportunitySource.google_programs,
        display_name="Google Programs",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="Google student developer programs fellowships scholarships startup",
        source_quality=0.86,
        compliance_note="Use official Google public program pages.",
    ),
    OpportunitySource.research_fellowships: SourceDefinition(
        source=OpportunitySource.research_fellowships,
        display_name="Research Fellowships",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="research fellowships AI computer science students grants",
        source_quality=0.82,
        compliance_note="Use official university, lab, nonprofit, or grant pages.",
    ),
    OpportunitySource.startup_grants: SourceDefinition(
        source=OpportunitySource.startup_grants,
        display_name="Startup Grants",
        allowed_modes=[CrawlMode.public_feed, CrawlMode.firecrawl_search, CrawlMode.manual_import],
        default_query="startup grants founders accelerators non dilutive funding",
        source_quality=0.8,
        compliance_note="Use official grant pages, public databases, and approved feeds.",
    ),
}


def selected_sources(sources: list[OpportunitySource] | None = None) -> list[SourceDefinition]:
    if not sources:
        return list(SOURCE_DEFINITIONS.values())
    return [SOURCE_DEFINITIONS[source] for source in sources]
