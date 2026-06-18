from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for the Future Simulation Engine."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="ALTER_",
        extra="ignore",
    )

    future_simulation_env: str = Field(default="local", alias="ALTER_FUTURE_SIMULATION_ENV")
    default_horizon_months: int = Field(default=36, ge=12, le=120)
    max_horizon_months: int = Field(default=60, ge=12, le=120)
    default_currency: str = Field(default="USD", min_length=3, max_length=3)
    request_timeout_seconds: int = Field(default=30, ge=5, le=120)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

