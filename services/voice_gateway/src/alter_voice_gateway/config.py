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

    voice_env: str = Field(default="local", alias="ALTER_VOICE_ENV")
    wake_phrase: str = Field(default="hey alter", alias="ALTER_WAKE_PHRASE")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
