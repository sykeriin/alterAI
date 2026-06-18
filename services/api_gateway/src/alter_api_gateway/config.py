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

    gateway_env: str = Field(default="local", alias="ALTER_GATEWAY_ENV")
    voice_gateway_url: str = Field(default="http://localhost:8070", alias="ALTER_VOICE_GATEWAY_URL")
    clone_council_url: str = Field(default="http://localhost:8080", alias="ALTER_CLONE_COUNCIL_URL")
    future_simulation_url: str = Field(
        default="http://localhost:8090",
        alias="ALTER_FUTURE_SIMULATION_URL",
    )
    memory_system_url: str = Field(default="http://localhost:8100", alias="ALTER_MEMORY_SYSTEM_URL")
    opportunity_engine_url: str = Field(
        default="http://localhost:8110",
        alias="ALTER_OPPORTUNITY_ENGINE_URL",
    )
    social_graph_url: str = Field(default="http://localhost:8120", alias="ALTER_SOCIAL_GRAPH_URL")
    alter_lens_url: str = Field(default="http://localhost:8130", alias="ALTER_LENS_URL")
    reputation_engine_url: str = Field(
        default="http://localhost:8140",
        alias="ALTER_REPUTATION_ENGINE_URL",
    )
    officekit_url: str = Field(default="http://localhost:8150", alias="ALTER_OFFICEKIT_URL")
    sarvam_api_key: str = Field(default="", alias="SARVAM_API_KEY")
    sarvam_chat_model: str = Field(default="sarvam-m", alias="ALTER_SARVAM_CHAT_MODEL")
    sarvam_translate_model: str = Field(
        default="sarvam-translate:v1",
        alias="ALTER_SARVAM_TRANSLATE_MODEL",
    )
    sarvam_stt_model: str = Field(default="saaras:v3", alias="ALTER_SARVAM_STT_MODEL")
    sarvam_tts_model: str = Field(default="bulbul:v3", alias="ALTER_SARVAM_TTS_MODEL")
    sarvam_tts_speaker: str = Field(default="shubh", alias="ALTER_SARVAM_TTS_SPEAKER")
    sarvam_base_url: str = Field(default="https://api.sarvam.ai", alias="ALTER_SARVAM_BASE_URL")
    rate_limit_per_minute: int = Field(default=120, alias="ALTER_RATE_LIMIT_PER_MINUTE")

    def service_urls(self) -> dict[str, str]:
        return {
            "voice_gateway": self.voice_gateway_url,
            "clone_council": self.clone_council_url,
            "future_simulation": self.future_simulation_url,
            "memory_system": self.memory_system_url,
            "opportunity_engine": self.opportunity_engine_url,
            "social_graph": self.social_graph_url,
            "alter_lens": self.alter_lens_url,
            "reputation_engine": self.reputation_engine_url,
            "officekit": self.officekit_url,
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
