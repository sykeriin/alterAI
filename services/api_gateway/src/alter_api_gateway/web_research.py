from __future__ import annotations

from typing import Any

import httpx

from .config import Settings


def _platform_query(platform: str, query: str) -> str:
    templates = {
        "amazon": "site:amazon.in {query}",
        "flipkart": "site:flipkart.com {query}",
        "facebook_marketplace": "site:facebook.com/marketplace {query}",
        "olx": "site:olx.in {query}",
    }
    template = templates.get(platform.lower(), query)
    return template.format(query=query)


async def firecrawl_search(
    settings: Settings,
    query: str,
    *,
    limit: int = 5,
) -> list[dict[str, str]]:
    if not settings.firecrawl_api_key:
        return _fallback_search_results(query, limit)
    payload = {
        "query": query,
        "limit": limit,
        "scrapeOptions": {"formats": ["markdown"]},
    }
    headers = {
        "Authorization": f"Bearer {settings.firecrawl_api_key}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=settings.web_research_timeout_seconds) as client:
        response = await client.post(
            f"{settings.firecrawl_base_url}/search",
            json=payload,
            headers=headers,
        )
        response.raise_for_status()
        body = response.json()
    data = body.get("data") if isinstance(body, dict) else body
    rows = data if isinstance(data, list) else []
    results: list[dict[str, str]] = []
    for row in rows[:limit]:
        if not isinstance(row, dict):
            continue
        markdown = row.get("markdown") or row.get("content") or ""
        snippet = str(markdown)[:400] if markdown else row.get("description", "")
        metadata = row.get("metadata")
        meta_title = metadata.get("title") if isinstance(metadata, dict) else ""
        results.append(
            {
                "title": str(row.get("title") or meta_title or query),
                "url": str(row.get("url") or row.get("metadata", {}).get("sourceURL") or ""),
                "snippet": str(snippet),
            }
        )
    return results or _fallback_search_results(query, limit)


async def firecrawl_scrape(settings: Settings, url: str) -> dict[str, str]:
    if not settings.firecrawl_api_key:
        return {
            "title": url,
            "url": url,
            "excerpt": "Firecrawl key not configured; cannot fetch page content.",
        }
    payload = {"url": url, "formats": ["markdown"]}
    headers = {
        "Authorization": f"Bearer {settings.firecrawl_api_key}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=settings.web_research_timeout_seconds) as client:
        response = await client.post(
            f"{settings.firecrawl_base_url}/scrape",
            json=payload,
            headers=headers,
        )
        response.raise_for_status()
        body = response.json()
    data = body.get("data") if isinstance(body, dict) else {}
    if not isinstance(data, dict):
        data = {}
    markdown = data.get("markdown") or data.get("content") or ""
    metadata = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
    return {
        "title": str(metadata.get("title") or url),
        "url": url,
        "excerpt": str(markdown)[:4000],
    }


async def search_marketplace(
    settings: Settings,
    *,
    query: str,
    platform: str,
    limit: int = 5,
) -> list[dict[str, str]]:
    scoped = _platform_query(platform, query)
    hits = await firecrawl_search(settings, scoped, limit=limit)
    listings: list[dict[str, str]] = []
    for hit in hits:
        listings.append(
            {
                "title": hit.get("title", ""),
                "price": _extract_price(hit.get("snippet", "")),
                "url": hit.get("url", ""),
                "snippet": hit.get("snippet", ""),
            }
        )
    return listings


def _extract_price(text: str) -> str:
    match = __import__("re").search(r"(₹|Rs\.?|INR|\$)\s?[\d,]+(?:\.\d+)?", text)
    return match.group(0) if match else ""


def _fallback_search_results(query: str, limit: int) -> list[dict[str, str]]:
    return [
        {
            "title": f"Search: {query}",
            "url": f"https://www.google.com/search?q={query.replace(' ', '+')}",
            "snippet": "Configure ALTER_FIRECRAWL_API_KEY for in-app research snippets.",
        }
    ][:limit]


async def query_opportunities(
    settings: Settings,
    *,
    query: str,
    limit: int = 5,
) -> list[dict[str, str]]:
    url = f"{settings.opportunity_engine_url.rstrip('/')}/v1/opportunities/recommend"
    payload: dict[str, Any] = {
        "query": query,
        "profile": {"interests": [query], "skills": [], "goals": []},
        "limit": limit,
    }
    try:
        async with httpx.AsyncClient(timeout=settings.web_research_timeout_seconds) as client:
            response = await client.post(url, json=payload)
            response.raise_for_status()
            body = response.json()
    except Exception:
        hits = await firecrawl_search(
            settings,
            f"internship OR fellowship OR hackathon {query}",
            limit=limit,
        )
        return [
            {
                "title": hit.get("title", query),
                "organization": "",
                "url": hit.get("url", ""),
                "summary": hit.get("snippet", ""),
            }
            for hit in hits
        ]

    recs = body.get("recommendations") if isinstance(body, dict) else []
    if not isinstance(recs, list):
        recs = []
    opportunities: list[dict[str, str]] = []
    for row in recs[:limit]:
        if not isinstance(row, dict):
            continue
        opp = row.get("opportunity") if isinstance(row.get("opportunity"), dict) else row
        opportunities.append(
            {
                "title": str(opp.get("title") or query),
                "organization": str(opp.get("organization") or opp.get("source") or ""),
                "url": str(opp.get("url") or ""),
                "summary": str(opp.get("summary") or opp.get("description") or ""),
            }
        )
    return opportunities
