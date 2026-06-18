from __future__ import annotations

import pytest

from alter_lens.config import Settings
from alter_lens.openai_client import DeterministicVisionAnalyzer
from alter_lens.schemas import LensScanInput, LensScanType
from alter_lens.service import AlterLensService, AlterLensValidationError


def _service(max_upload_mb: int = 1) -> AlterLensService:
    settings = Settings(
        ALTER_LENS_ENV="local",
        ALTER_LENS_MAX_UPLOAD_MB=max_upload_mb,
    )
    return AlterLensService(settings=settings, analyzer=DeterministicVisionAnalyzer())


def test_resume_scan_returns_structured_result() -> None:
    result = _service().analyze(
        LensScanInput(
            scan_type=LensScanType.resume,
            image_bytes=b"fake-jpeg-bytes",
            mime_type="image/jpeg",
            filename="resume.jpg",
        )
    )

    assert result.scan_type == LensScanType.resume
    assert result.summary
    assert result.insights
    assert result.opportunities
    assert result.recommendations
    assert 0 <= result.confidence <= 1


def test_rejects_non_image_upload() -> None:
    with pytest.raises(AlterLensValidationError):
        _service().analyze(
            LensScanInput(
                scan_type=LensScanType.product,
                image_bytes=b"not-image",
                mime_type="application/pdf",
                filename="paper.pdf",
            )
        )


def test_rejects_oversized_upload() -> None:
    with pytest.raises(AlterLensValidationError):
        _service(max_upload_mb=1).analyze(
            LensScanInput(
                scan_type=LensScanType.product,
                image_bytes=b"x" * (1024 * 1024 + 1),
                mime_type="image/jpeg",
                filename="huge.jpg",
            )
        )
