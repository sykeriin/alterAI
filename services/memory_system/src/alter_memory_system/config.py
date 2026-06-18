from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="ALTER_",
        extra="ignore",
    )

    memory_env: str = Field(default="local", alias="ALTER_MEMORY_ENV")
    database_url: str = Field(
        default="postgresql://alter:alter@localhost:5432/alter",
        alias="ALTER_DATABASE_URL",
    )
    embedding_dimensions: int = Field(default=1536, ge=128, le=4096)
    short_term_ttl_minutes: int = Field(default=240, ge=5, le=43200)
    default_retrieval_limit: int = Field(default=12, ge=1, le=50)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

