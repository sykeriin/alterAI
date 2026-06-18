from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    HealthResponse,
    LensScanInput,
    LensScanResponse,
    LensScanType,
)
from .service import (
    AlterLensService,
    AlterLensValidationError,
    create_alter_lens_service,
)

app = FastAPI(
    title="ALTER Lens",
    version="0.1.0",
    description="Camera intelligence service for ALTER powered by OpenAI vision models.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@lru_cache(maxsize=1)
def get_service() -> AlterLensService:
    return create_alter_lens_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-lens",
        environment=settings.alter_lens_env,
        model=settings.alter_lens_openai_model,
    )


@app.get("/v1/alter-lens/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-lens",
        components=[
            "Flutter camera capture",
            "Multipart image upload",
            "FastAPI validation",
            "OpenAI vision analyzer",
            "Structured JSON response contract",
            "Insight, opportunity, and recommendation renderer",
        ],
        data_flow=[
            "User selects scan type: resume, startup deck, event poster, "
            "research paper, or product.",
            "Flutter captures a camera image and uploads it to ALTER Lens.",
            "Backend validates image type and size.",
            "OpenAI receives inline image bytes plus scan-specific prompt guidance.",
            "OpenAI returns structured JSON: summary, insights, opportunities, recommendations.",
            "Flutter renders the result and can route memory candidates to Memory Graph.",
        ],
        supported_scan_types=list(LensScanType),
        output_contract={
            "LensScanResponse": [
                "summary",
                "confidence",
                "insights",
                "opportunities",
                "recommendations",
                "extracted_entities",
                "memory_candidates",
            ]
        },
    )


@app.post("/v1/alter-lens/analyze", response_model=LensScanResponse)
async def analyze(
    scan_type: Annotated[LensScanType, Form()],
    image: Annotated[UploadFile, File()],
    user_context: Annotated[str, Form()] = "",
) -> LensScanResponse:
    image_bytes = await image.read()
    mime_type = image.content_type or "image/jpeg"
    filename = image.filename or "camera-capture.jpg"
    try:
        return get_service().analyze(
            LensScanInput(
                scan_type=scan_type,
                image_bytes=image_bytes,
                mime_type=mime_type,
                filename=filename,
                user_context=user_context,
            )
        )
    except AlterLensValidationError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
