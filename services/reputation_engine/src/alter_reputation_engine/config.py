from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    reputation_env: str = Field(default="local", alias="ALTER_REPUTATION_ENV")
    baseline_score: int = Field(default=600, alias="ALTER_REPUTATION_BASELINE_SCORE")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
