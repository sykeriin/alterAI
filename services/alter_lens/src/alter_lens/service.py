from __future__ import annotations

from .config import Settings, get_settings
from .openai_client import (
    DeterministicVisionAnalyzer,
    OpenAIVisionAnalyzer,
    VisionAnalyzer,
)
from .schemas import LensScanInput, LensScanResponse


class AlterLensValidationError(ValueError):
    pass


class AlterLensService:
    def __init__(self, *, settings: Settings, analyzer: VisionAnalyzer) -> None:
        self._settings = settings
        self._analyzer = analyzer

    def analyze(self, scan_input: LensScanInput) -> LensScanResponse:
        self._validate(scan_input)
        result = self._analyzer.analyze(scan_input)
        if result.scan_type != scan_input.scan_type:
            result.scan_type = scan_input.scan_type
        return result

    def _validate(self, scan_input: LensScanInput) -> None:
        if not scan_input.image_bytes:
            raise AlterLensValidationError("Image upload is empty.")
        max_bytes = self._settings.alter_lens_max_upload_mb * 1024 * 1024
        if len(scan_input.image_bytes) > max_bytes:
            raise AlterLensValidationError(
                f"Image exceeds {self._settings.alter_lens_max_upload_mb} MB limit."
            )
        if not scan_input.mime_type.startswith("image/"):
            raise AlterLensValidationError("Only image uploads are supported.")


def create_alter_lens_service(
    *,
    settings: Settings | None = None,
    analyzer: VisionAnalyzer | None = None,
) -> AlterLensService:
    resolved_settings = settings or get_settings()
    resolved_analyzer = analyzer
    if resolved_analyzer is None:
        if resolved_settings.alter_lens_env == "local":
            resolved_analyzer = DeterministicVisionAnalyzer()
        else:
            resolved_analyzer = OpenAIVisionAnalyzer(resolved_settings)
    return AlterLensService(settings=resolved_settings, analyzer=resolved_analyzer)
