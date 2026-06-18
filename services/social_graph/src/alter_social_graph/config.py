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

    social_graph_env: str = Field(default="local", alias="ALTER_SOCIAL_GRAPH_ENV")
    neo4j_uri: str = Field(default="neo4j://localhost:7687", alias="ALTER_NEO4J_URI")
    neo4j_user: str = Field(default="neo4j", alias="ALTER_NEO4J_USER")
    neo4j_password: str = Field(default="password", alias="ALTER_NEO4J_PASSWORD")
    neo4j_database: str = Field(default="neo4j", alias="ALTER_NEO4J_DATABASE")
    default_discovery_limit: int = Field(default=10, ge=1, le=100)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

