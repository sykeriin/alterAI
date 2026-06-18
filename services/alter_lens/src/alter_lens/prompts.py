from __future__ import annotations

from .schemas import LensScanInput, LensScanType

SCAN_GUIDANCE = {
    LensScanType.resume: (
        "Extract candidate positioning, skills, projects, seniority signals, gaps, "
        "and concrete career opportunities."
    ),
    LensScanType.startup_deck: (
        "Extract company narrative, market, product, traction, risks, fundraising "
        "signals, and partnership or investor opportunities."
    ),
    LensScanType.event_poster: (
        "Extract event details, audience, topic clusters, timing, networking angles, "
        "and high-leverage follow-up opportunities."
    ),
    LensScanType.research_paper: (
        "Extract thesis, method, novelty, evidence, limitations, applications, and "
        "research or startup opportunities."
    ),
    LensScanType.product: (
        "Extract product category, differentiators, likely users, buying triggers, "
        "risks, and go-to-market opportunities."
    ),
}


def build_lens_prompt(scan_input: LensScanInput) -> str:
    context = scan_input.user_context.strip() or "No extra user context was provided."
    guidance = SCAN_GUIDANCE[scan_input.scan_type]
    return f"""
You are ALTER Lens, a camera intelligence layer inside a personal AI future OS.

Analyze the attached image as scan_type={scan_input.scan_type.value}.
Guidance: {guidance}
User context: {context}

Return concise, decision-grade output. Prefer direct evidence from the image.
If a field cannot be inferred, say so briefly instead of hallucinating.
Recommendations must be actionable next steps for the user.
""".strip()
