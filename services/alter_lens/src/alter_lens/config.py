from __future__ import annotations

from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    alter_lens_env: str = Field(default="local", alias="ALTER_LENS_ENV")
    openai_api_key: str | None = Field(
        default=None,
        validation_alias=AliasChoices("OPENAI_API_KEY", "ALTER_OPENAI_API_KEY"),
    )
    alter_lens_openai_model: str = Field(
        default="gpt-4.1-mini",
        validation_alias=AliasChoices("ALTER_LENS_OPENAI_MODEL", "ALTER_OPENAI_MODEL"),
    )
    alter_lens_max_upload_mb: int = Field(default=12, alias="ALTER_LENS_MAX_UPLOAD_MB")
    openai_max_retries: int = Field(
        default=2,
        ge=0,
        le=5,
        validation_alias=AliasChoices("ALTER_OPENAI_MAX_RETRIES", "OPENAI_MAX_RETRIES"),
    )
    request_timeout_seconds: int = Field(
        default=90,
        ge=10,
        le=240,
        validation_alias=AliasChoices(
            "ALTER_REQUEST_TIMEOUT_SECONDS",
            "REQUEST_TIMEOUT_SECONDS",
        ),
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
