from __future__ import annotations

import re
from typing import Protocol

import httpx
from bs4 import BeautifulSoup

from .config import Settings
from .schemas import CrawlMode, CrawlRequest, OpportunitySource, RawOpportunity, SourceDefinition
from .sources import selected_sources


class OpportunityCrawler(Protocol):
    async def crawl(self, request: CrawlRequest) -> tuple[list[RawOpportunity], list[str]]:
        ...


class OpportunityCrawlerRouter:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._firecrawl = FirecrawlCrawler(settings)
        self._public = PublicUrlCrawler(settings)
        self._seed = SeedCrawler()

    async def crawl(self, request: CrawlRequest) -> tuple[list[RawOpportunity], list[str]]:
        raw: list[RawOpportunity] = []
        notes: list[str] = []
        configured_urls = {
            **self._settings.allowed_source_urls,
            **{source.value: urls for source, urls in request.public_urls.items()},
        }

        for source_def in selected_sources(request.sources):
            source_urls = configured_urls.get(source_def.source.value, [])
            mode = request.mode or self._choose_mode(source_def, bool(source_urls))
            if mode == CrawlMode.public_feed and source_urls:
                source_raw, source_notes = await self._public.crawl_source(
                    source_def,
                    source_urls,
                    request.limit_per_source,
                )
            elif mode == CrawlMode.firecrawl_search and self._settings.has_firecrawl_api_key:
                source_raw, source_notes = await self._firecrawl.crawl_source(
                    source_def,
                    request.query or source_def.default_query,
                    request.limit_per_source,
                )
            else:
                source_raw, source_notes = await self._seed.crawl_source(
                    source_def,
                    request.query,
                    request.limit_per_source,
                )
            raw.extend(source_raw)
            notes.extend(source_notes)

        return raw, notes

    def _choose_mode(self, source_def: SourceDefinition, has_urls: bool) -> CrawlMode:
        if has_urls and CrawlMode.public_feed in source_def.allowed_modes:
            return CrawlMode.public_feed
        if (
            self._settings.has_firecrawl_api_key
            and CrawlMode.firecrawl_search in source_def.allowed_modes
        ):
            return CrawlMode.firecrawl_search
        return CrawlMode.seed


class FirecrawlCrawler:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def crawl_source(
        self,
        source_def: SourceDefinition,
        query: str,
        limit: int,
    ) -> tuple[list[RawOpportunity], list[str]]:
        if not self._settings.has_firecrawl_api_key:
            return [], [f"{source_def.display_name}: Firecrawl key not configured."]
        payload = {
            "query": query,
            "limit": limit,
            "scrapeOptions": {"formats": ["markdown"]},
        }
        headers = {
            "Authorization": f"Bearer {self._settings.firecrawl_api_key}",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=self._settings.crawl_timeout_seconds) as client:
            response = await client.post(
                f"{self._settings.firecrawl_base_url}/search",
                json=payload,
                headers=headers,
            )
            response.raise_for_status()
            body = response.json()

        items = body.get("data", []) if isinstance(body, dict) else []
        raw = [
            RawOpportunity(
                source=source_def.source,
                source_url=item.get("url"),
                title=item.get("title") or source_def.display_name,
                organization=item.get("metadata", {}).get("siteName")
                or item.get("siteName")
                or source_def.display_name,
                raw_text=item.get("markdown")
                or item.get("description")
                or item.get("title")
                or source_def.default_query,
                tags=[source_def.display_name],
                metadata={"crawler": "firecrawl_search", "raw": item},
            )
            for item in items[:limit]
            if isinstance(item, dict)
        ]
        return raw, [f"{source_def.display_name}: crawled {len(raw)} Firecrawl results."]


class PublicUrlCrawler:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def crawl_source(
        self,
        source_def: SourceDefinition,
        urls: list[str],
        limit: int,
    ) -> tuple[list[RawOpportunity], list[str]]:
        raw: list[RawOpportunity] = []
        async with httpx.AsyncClient(
            timeout=self._settings.crawl_timeout_seconds,
            follow_redirects=True,
            headers={"User-Agent": "ALTEROpportunityEngine/0.1 compliant crawler"},
        ) as client:
            for url in urls[:limit]:
                response = await client.get(url)
                response.raise_for_status()
                raw.append(_raw_from_html(source_def.source, url, response.text))
        return raw, [f"{source_def.display_name}: crawled {len(raw)} configured URL(s)."]


class SeedCrawler:
    async def crawl(self, request: CrawlRequest) -> tuple[list[RawOpportunity], list[str]]:
        raw: list[RawOpportunity] = []
        notes: list[str] = []
        for source_def in selected_sources(request.sources):
            source_raw, source_notes = await self.crawl_source(
                source_def,
                request.query,
                request.limit_per_source,
            )
            raw.extend(source_raw)
            notes.extend(source_notes)
        return raw, notes

    async def crawl_source(
        self,
        source_def: SourceDefinition,
        query: str | None,
        limit: int,
    ) -> tuple[list[RawOpportunity], list[str]]:
        return [], [
            f"{source_def.display_name}: no crawl source configured — "
            "set ALTER_FIRECRAWL_API_KEY or public source URLs."
        ]


def _raw_from_html(source: OpportunitySource, url: str, html: str) -> RawOpportunity:
    soup = BeautifulSoup(html, "html.parser")
    title = (
        _clean(soup.title.get_text(" ", strip=True)) if soup.title else "Untitled opportunity"
    )
    body = _clean(soup.get_text(" ", strip=True))
    organization = _domain_from_url(url)
    return RawOpportunity(
        source=source,
        source_url=url,
        title=title[:300],
        organization=organization,
        raw_text=body[:20000] or title,
        tags=[organization],
        metadata={"crawler": "public_url"},
    )


def _terms(text: str) -> list[str]:
    return [
        term
        for term in re.sub(r"[^a-z0-9 ]", " ", text.lower()).split()
        if len(term) > 2 and term not in _STOPWORDS
    ]


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _domain_from_url(url: str) -> str:
    match = re.match(r"https?://([^/]+)", url)
    return match.group(1) if match else "Unknown"


_STOPWORDS = {
    "and",
    "for",
    "the",
    "with",
    "from",
    "into",
    "your",
    "you",
    "are",
    "this",
    "that",
}
