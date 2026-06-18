from __future__ import annotations

import json
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="ALTER_",
        extra="ignore",
    )

    opportunity_env: str = Field(default="local", alias="ALTER_OPPORTUNITY_ENV")
    firecrawl_api_key: str | None = Field(default=None, alias="ALTER_FIRECRAWL_API_KEY")
    firecrawl_base_url: str = Field(
        default="https://api.firecrawl.dev/v1",
        alias="ALTER_FIRECRAWL_BASE_URL",
    )
    crawl_timeout_seconds: int = Field(default=30, ge=5, le=180)
    default_crawl_limit: int = Field(default=20, ge=1, le=100)
    default_recommendation_limit: int = Field(default=10, ge=1, le=50)
    allowed_source_urls_json: str = Field(default="{}", alias="ALTER_ALLOWED_SOURCE_URLS_JSON")

    @property
    def has_firecrawl_api_key(self) -> bool:
        if not self.firecrawl_api_key:
            return False
        normalized = self.firecrawl_api_key.strip().lower()
        return normalized not in {"replace-me", "changeme", "dummy", "test"}

    @property
    def allowed_source_urls(self) -> dict[str, list[str]]:
        try:
            value = json.loads(self.allowed_source_urls_json)
        except json.JSONDecodeError:
            return {}
        if not isinstance(value, dict):
            return {}
        return {
            str(source): [str(url) for url in urls]
            for source, urls in value.items()
            if isinstance(urls, list)
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
