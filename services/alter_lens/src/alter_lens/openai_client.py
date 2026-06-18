from __future__ import annotations

import json
from base64 import b64encode
from typing import Any, Protocol
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field

from .config import Settings
from .prompts import build_lens_prompt
from .schemas import (
    LensInsight,
    LensOpportunity,
    LensPriority,
    LensRecommendation,
    LensScanInput,
    LensScanResponse,
    LensScanType,
    LensVisionOutput,
)


class _OpenAILensInsight(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str
    detail: str
    confidence: float = Field(ge=0, le=1)
    tags: list[str]


class _OpenAILensOpportunity(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str
    why_now: str
    next_step: str
    score: float = Field(ge=0, le=100)


class _OpenAILensRecommendation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action: str
    priority: LensPriority
    rationale: str


class _OpenAIEntityGroup(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    values: list[str]


class _OpenAILensVisionOutput(BaseModel):
    """OpenAI strict-schema shape; converted to ALTER's public response contract."""

    model_config = ConfigDict(extra="forbid")

    detected_type: str
    summary: str
    confidence: float = Field(ge=0, le=1)
    insights: list[_OpenAILensInsight]
    opportunities: list[_OpenAILensOpportunity]
    recommendations: list[_OpenAILensRecommendation]
    extracted_entities: list[_OpenAIEntityGroup]
    memory_candidates: list[str]


class VisionAnalyzer(Protocol):
    def analyze(self, scan_input: LensScanInput) -> LensScanResponse:
        ...


class OpenAIVisionAnalyzer:
    def __init__(self, settings: Settings) -> None:
        if not settings.openai_api_key:
            raise RuntimeError(
                "OPENAI_API_KEY is required when ALTER_LENS_ENV is not local."
            )
        self._settings = settings
        from openai import OpenAI

        self._client = OpenAI(
            api_key=settings.openai_api_key,
            max_retries=settings.openai_max_retries,
            timeout=settings.request_timeout_seconds,
        )

    def analyze(self, scan_input: LensScanInput) -> LensScanResponse:
        image_url = (
            f"data:{scan_input.mime_type};base64,"
            f"{b64encode(scan_input.image_bytes).decode('ascii')}"
        )
        response = self._client.responses.parse(
            model=self._settings.alter_lens_openai_model,
            input=[
                {
                    "role": "system",
                    "content": (
                        "You are ALTER Lens. Analyze the image for a future operating "
                        "system and return only the requested structured output."
                    ),
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": build_lens_prompt(scan_input)},
                        {"type": "input_image", "image_url": image_url},
                    ],
                },
            ],
            text_format=_OpenAILensVisionOutput,
            temperature=0.2,
        )
        payload: Any = getattr(response, "output_parsed", None)
        if isinstance(payload, _OpenAILensVisionOutput):
            output = _to_lens_vision_output(payload)
        elif isinstance(payload, dict):
            output = _to_lens_vision_output(
                _OpenAILensVisionOutput.model_validate(payload)
            )
        elif payload is None:
            output = _to_lens_vision_output(
                _OpenAILensVisionOutput.model_validate_json(
                    getattr(response, "output_text", "")
                )
            )
        else:
            output = _to_lens_vision_output(
                _OpenAILensVisionOutput.model_validate(json.loads(str(payload)))
            )
        return LensScanResponse(
            scan_type=scan_input.scan_type,
            **output.model_dump(),
        )


def _to_lens_vision_output(output: _OpenAILensVisionOutput) -> LensVisionOutput:
    return LensVisionOutput(
        detected_type=output.detected_type,
        summary=output.summary,
        confidence=output.confidence,
        insights=[
            LensInsight(
                title=insight.title,
                detail=insight.detail,
                confidence=insight.confidence,
                tags=insight.tags,
            )
            for insight in output.insights
        ],
        opportunities=[
            LensOpportunity(
                title=opportunity.title,
                why_now=opportunity.why_now,
                next_step=opportunity.next_step,
                score=opportunity.score,
            )
            for opportunity in output.opportunities
        ],
        recommendations=[
            LensRecommendation(
                action=recommendation.action,
                priority=recommendation.priority,
                rationale=recommendation.rationale,
            )
            for recommendation in output.recommendations
        ],
        extracted_entities={
            entity.name: entity.values for entity in output.extracted_entities
        },
        memory_candidates=output.memory_candidates,
    )


class DeterministicVisionAnalyzer:
    """Local analyzer for tests and offline development."""

    def analyze(self, scan_input: LensScanInput) -> LensScanResponse:
        template = _TEMPLATES[scan_input.scan_type]
        confidence = min(0.94, 0.68 + len(scan_input.image_bytes) / 120_000)
        return LensScanResponse(
            scan_id=uuid4(),
            scan_type=scan_input.scan_type,
            detected_type=template["detected_type"],
            summary=template["summary"],
            confidence=round(confidence, 2),
            insights=[
                LensInsight(
                    title=item["title"],
                    detail=item["detail"],
                    confidence=round(confidence - 0.04, 2),
                    tags=item["tags"],
                )
                for item in template["insights"]
            ],
            opportunities=[
                LensOpportunity(
                    title=item["title"],
                    why_now=item["why_now"],
                    next_step=item["next_step"],
                    score=item["score"],
                )
                for item in template["opportunities"]
            ],
            recommendations=[
                LensRecommendation(
                    action=item["action"],
                    priority=LensPriority(item["priority"]),
                    rationale=item["rationale"],
                )
                for item in template["recommendations"]
            ],
            extracted_entities=template["entities"],
            memory_candidates=template["memory_candidates"],
        )


_TEMPLATES = {
    LensScanType.resume: {
        "detected_type": "Resume",
        "summary": (
            "The image appears to be a career profile with skills, projects, "
            "and proof points."
        ),
        "insights": [
            {
                "title": "Skill cluster is visible",
                "detail": (
                    "The scan has enough structure to extract role, skills, "
                    "and project signals."
                ),
                "tags": ["skills", "career"],
            },
            {
                "title": "Portfolio follow-up is likely useful",
                "detail": "The document can become a memory-backed candidate brief.",
                "tags": ["resume", "memory"],
            },
        ],
        "opportunities": [
            {
                "title": "Recruiter-ready summary",
                "why_now": "The profile can be converted into a concise outreach packet.",
                "next_step": "Save key skills and ask Opportunity Engine for matching roles.",
                "score": 82,
            }
        ],
        "recommendations": [
            {
                "action": "Create a one-page positioning brief.",
                "priority": "high",
                "rationale": "A short brief improves recruiter and mentor routing.",
            }
        ],
        "entities": {"skills": ["AI", "product", "projects"], "people": []},
        "memory_candidates": ["career_profile", "skills", "projects"],
    },
    LensScanType.startup_deck: {
        "detected_type": "Startup deck",
        "summary": (
            "The scan looks like a founder narrative with market, product, "
            "and traction signals."
        ),
        "insights": [
            {
                "title": "Narrative can be sharpened",
                "detail": "The deck should separate pain, wedge, proof, and ask.",
                "tags": ["deck", "fundraising"],
            },
            {
                "title": "Investor path exists",
                "detail": "Visible deck structure can feed Clone Council and investor matching.",
                "tags": ["investor", "startup"],
            },
        ],
        "opportunities": [
            {
                "title": "Investor memo draft",
                "why_now": "Deck content is already structured enough for a memo.",
                "next_step": "Route through Clone Council for objections and investor fit.",
                "score": 88,
            }
        ],
        "recommendations": [
            {
                "action": "Extract the ask, traction metric, and sharpest customer pain.",
                "priority": "high",
                "rationale": "Those fields drive investor and design-partner matching.",
            }
        ],
        "entities": {"markets": ["AI", "software"], "metrics": []},
        "memory_candidates": ["startup_deck", "fundraising", "traction"],
    },
    LensScanType.event_poster: {
        "detected_type": "Event poster",
        "summary": "The scan appears to contain event context, audience, and timing.",
        "insights": [
            {
                "title": "Networking moment detected",
                "detail": "Event posters are useful triggers for warm-path and NFC planning.",
                "tags": ["event", "network"],
            }
        ],
        "opportunities": [
            {
                "title": "Pre-event target list",
                "why_now": "Event context can be matched against social graph interests.",
                "next_step": "Ask Social Graph Engine for attendees and mutual paths.",
                "score": 79,
            }
        ],
        "recommendations": [
            {
                "action": "Create an event memory and prepare three opener questions.",
                "priority": "medium",
                "rationale": "Prepared context improves follow-up quality.",
            }
        ],
        "entities": {"events": ["scanned event"], "topics": ["networking"]},
        "memory_candidates": ["event", "networking", "follow_up"],
    },
    LensScanType.research_paper: {
        "detected_type": "Research paper",
        "summary": "The scan appears to include academic or technical research content.",
        "insights": [
            {
                "title": "Research-to-product bridge",
                "detail": (
                    "The paper can be translated into applications, "
                    "limitations, and experiments."
                ),
                "tags": ["research", "product"],
            }
        ],
        "opportunities": [
            {
                "title": "Experiment backlog",
                "why_now": "The visible research can seed a practical validation plan.",
                "next_step": "Summarize method and create one prototype hypothesis.",
                "score": 84,
            }
        ],
        "recommendations": [
            {
                "action": "Extract thesis, method, limitation, and application.",
                "priority": "high",
                "rationale": "Those fields make the paper useful to Future Simulator.",
            }
        ],
        "entities": {"concepts": ["research", "method"], "authors": []},
        "memory_candidates": ["research_note", "learning_progress"],
    },
    LensScanType.product: {
        "detected_type": "Product",
        "summary": "The scan appears to show a product or product surface with positioning clues.",
        "insights": [
            {
                "title": "Buyer and use case can be inferred",
                "detail": "Product scans can identify category, wedge, and GTM hypotheses.",
                "tags": ["product", "gtm"],
            }
        ],
        "opportunities": [
            {
                "title": "Competitive teardown",
                "why_now": "A product image can become a positioning and differentiation brief.",
                "next_step": "Capture pricing, audience, and unique workflow clues.",
                "score": 81,
            }
        ],
        "recommendations": [
            {
                "action": "Save product insight and compare against current opportunity radar.",
                "priority": "medium",
                "rationale": "Product observations can reveal new market openings.",
            }
        ],
        "entities": {"products": ["scanned product"], "categories": ["software"]},
        "memory_candidates": ["product_scan", "market_signal"],
    },
}
