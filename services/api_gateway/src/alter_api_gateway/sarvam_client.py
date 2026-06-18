from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import httpx

from .config import Settings


@dataclass(frozen=True)
class LanguageSpec:
    code: str
    name: str
    region: str
    sarvam_translate: bool = True
    sarvam_chat: bool = True


INDIAN_LANGUAGE_SPECS: tuple[LanguageSpec, ...] = (
    LanguageSpec("as-IN", "Assamese", "India"),
    LanguageSpec("bn-IN", "Bengali", "India"),
    LanguageSpec("brx-IN", "Bodo", "India"),
    LanguageSpec("doi-IN", "Dogri", "India"),
    LanguageSpec("en-IN", "English", "India"),
    LanguageSpec("gu-IN", "Gujarati", "India"),
    LanguageSpec("hi-IN", "Hindi", "India"),
    LanguageSpec("kn-IN", "Kannada", "India"),
    LanguageSpec("kok-IN", "Konkani", "India"),
    LanguageSpec("ks-IN", "Kashmiri", "India"),
    LanguageSpec("mai-IN", "Maithili", "India"),
    LanguageSpec("ml-IN", "Malayalam", "India"),
    LanguageSpec("mni-IN", "Manipuri", "India"),
    LanguageSpec("mr-IN", "Marathi", "India"),
    LanguageSpec("ne-IN", "Nepali", "India"),
    LanguageSpec("od-IN", "Odia", "India"),
    LanguageSpec("pa-IN", "Punjabi", "India"),
    LanguageSpec("sa-IN", "Sanskrit", "India"),
    LanguageSpec("sat-IN", "Santali", "India"),
    LanguageSpec("sd-IN", "Sindhi", "India"),
    LanguageSpec("ta-IN", "Tamil", "India"),
    LanguageSpec("te-IN", "Telugu", "India"),
    LanguageSpec("ur-IN", "Urdu", "India"),
)

MAJOR_FOREIGN_LANGUAGE_SPECS: tuple[LanguageSpec, ...] = (
    LanguageSpec("en-US", "English", "United States", sarvam_translate=False),
    LanguageSpec("es-ES", "Spanish", "Spain", sarvam_translate=False),
    LanguageSpec("fr-FR", "French", "France", sarvam_translate=False),
    LanguageSpec("de-DE", "German", "Germany", sarvam_translate=False),
    LanguageSpec("pt-BR", "Portuguese", "Brazil", sarvam_translate=False),
    LanguageSpec("ar-SA", "Arabic", "Saudi Arabia", sarvam_translate=False),
    LanguageSpec("ja-JP", "Japanese", "Japan", sarvam_translate=False),
    LanguageSpec("ko-KR", "Korean", "South Korea", sarvam_translate=False),
    LanguageSpec("zh-CN", "Chinese", "China", sarvam_translate=False),
    LanguageSpec("ru-RU", "Russian", "Russia", sarvam_translate=False),
)

LANGUAGE_SPECS: tuple[LanguageSpec, ...] = (
    *INDIAN_LANGUAGE_SPECS,
    *MAJOR_FOREIGN_LANGUAGE_SPECS,
)

LANGUAGE_BY_CODE = {language.code.lower(): language for language in LANGUAGE_SPECS}


class SarvamClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._base_url = settings.sarvam_base_url.rstrip("/")

    @property
    def enabled(self) -> bool:
        return bool(self._settings.sarvam_api_key.strip())

    def language_specs(self) -> list[dict[str, Any]]:
        return [
            {
                "code": language.code,
                "name": language.name,
                "region": language.region,
                "sarvam_translate": language.sarvam_translate,
                "sarvam_chat": language.sarvam_chat,
            }
            for language in LANGUAGE_SPECS
        ]

    async def chat(
        self,
        *,
        messages: list[dict[str, str]],
        target_language_code: str,
        temperature: float = 0.35,
        max_tokens: int = 900,
    ) -> dict[str, Any]:
        self._require_key()
        target = language_for_code(target_language_code)
        payload = {
            "model": self._settings.sarvam_chat_model,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You are ALTER, a multilingual Android intelligence system. "
                        f"Respond in {target.name}. Be concise, actionable, and safe. "
                        "Never claim you can bypass Android permissions."
                    ),
                },
                *messages,
            ],
        }
        data = await self._post_json("/v1/chat/completions", payload)
        content = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
        )
        return {
            "text": str(content).strip(),
            "provider": "sarvam",
            "model": data.get("model", self._settings.sarvam_chat_model),
            "usage": data.get("usage") or {},
            "target_language_code": target.code,
        }

    async def translate(
        self,
        *,
        text: str,
        target_language_code: str,
        source_language_code: str = "auto",
    ) -> dict[str, Any]:
        self._require_key()
        target = language_for_code(target_language_code)
        if not target.sarvam_translate:
            raise ValueError(f"Sarvam Translate does not support {target.code}.")
        # sarvam-translate:v1 rejects source_language_code="auto"; only the
        # mayura:v1 model auto-detects the source. Route accordingly so the
        # common "translate this to X" (unknown source) path actually works.
        if (source_language_code or "auto").lower() == "auto":
            model = "mayura:v1"
        else:
            model = self._settings.sarvam_translate_model
        payload = {
            "input": text[:2000],
            "source_language_code": source_language_code,
            "target_language_code": target.code,
            "model": model,
            "mode": "formal",
            "speaker_gender": "Male",
        }
        data = await self._post_json("/translate", payload)
        return {
            "text": str(data.get("translated_text", "")).strip(),
            "provider": "sarvam",
            "model": model,
            "source_language_code": data.get("source_language_code", source_language_code),
            "target_language_code": target.code,
            "request_id": data.get("request_id"),
        }

    async def detect_language(self, *, text: str) -> dict[str, Any]:
        self._require_key()
        payload = {"input": text[:1000]}
        data = await self._post_json("/text-lid", payload)
        return {
            "provider": "sarvam",
            "request_id": data.get("request_id"),
            "language_code": data.get("language_code"),
            "script_code": data.get("script_code"),
        }

    async def text_to_speech(
        self,
        *,
        text: str,
        target_language_code: str,
        speaker: str | None = None,
        pace: float = 1.0,
        speech_sample_rate: int = 24000,
    ) -> dict[str, Any]:
        self._require_key()
        target = language_for_code(target_language_code)
        payload = {
            "text": text[:2500],
            "target_language_code": target.code,
            "speaker": (speaker or self._settings.sarvam_tts_speaker).strip().lower(),
            "pace": pace,
            "speech_sample_rate": speech_sample_rate,
            "model": self._settings.sarvam_tts_model,
        }
        data = await self._post_json("/text-to-speech", payload)
        audios = data.get("audios")
        if not isinstance(audios, list):
            audios = []
        audio = audios[0] if audios and isinstance(audios[0], str) else ""
        return {
            "audio_base64": audio,
            "audio_count": len(audios),
            "provider": "sarvam",
            "model": self._settings.sarvam_tts_model,
            "request_id": data.get("request_id"),
            "target_language_code": target.code,
            "language_display_name": target.name,
            "speaker": payload["speaker"],
            "speech_sample_rate": speech_sample_rate,
        }

    async def speech_to_text(
        self,
        *,
        audio_bytes: bytes,
        filename: str,
        content_type: str,
        language_code: str = "unknown",
        mode: str = "transcribe",
    ) -> dict[str, Any]:
        self._require_key()
        headers = {
            "api-subscription-key": self._settings.sarvam_api_key,
            "accept": "application/json",
        }
        data = {
            "model": self._settings.sarvam_stt_model,
            "language_code": language_code or "unknown",
            "mode": mode or "transcribe",
        }
        files = {
            "file": (
                filename or "audio.wav",
                audio_bytes,
                content_type or "application/octet-stream",
            )
        }
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                f"{self._base_url}/speech-to-text",
                data=data,
                files=files,
                headers=headers,
            )
            response.raise_for_status()
            payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("Sarvam returned invalid JSON.")
        return {
            "transcript": str(payload.get("transcript", "")).strip(),
            "provider": "sarvam",
            "model": self._settings.sarvam_stt_model,
            "request_id": payload.get("request_id"),
            "language_code": payload.get("language_code"),
            "language_probability": payload.get("language_probability"),
            "timestamps": payload.get("timestamps"),
            "diarized_transcript": payload.get("diarized_transcript"),
        }

    async def _post_json(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        headers = {
            "api-subscription-key": self._settings.sarvam_api_key,
            "content-type": "application/json",
            "accept": "application/json",
        }
        async with httpx.AsyncClient(timeout=18.0) as client:
            response = await client.post(f"{self._base_url}{path}", json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
        if not isinstance(data, dict):
            raise ValueError("Sarvam returned invalid JSON.")
        return data

    def _require_key(self) -> None:
        if not self.enabled:
            raise RuntimeError("SARVAM_API_KEY is not configured.")


def language_for_code(code: str) -> LanguageSpec:
    normalized = _normalize_language_code(code)
    return LANGUAGE_BY_CODE.get(normalized.lower(), LANGUAGE_BY_CODE["en-in"])


def _normalize_language_code(code: str) -> str:
    value = (code or "en-IN").strip()
    if value.lower().startswith("en-"):
        return "en-IN" if value.lower() in {"en-in", "en-us", "en-gb"} else value
    return value
