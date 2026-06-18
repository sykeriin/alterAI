from __future__ import annotations

from collections import defaultdict, deque
from functools import lru_cache
import time

from uuid import UUID

import httpx
from fastapi import FastAPI, File, Form, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

from .config import get_settings
from .schemas import (
    ArchitectureResponse,
    AgentPlannerRequest,
    AgentPlannerResponse,
    ConsentGrant,
    ConsentGrantRequest,
    ConsentLedgerResponse,
    DataIngestionRequest,
    DataIngestionResponse,
    DemoRunRequest,
    DemoRunResponse,
    FutureTwinRequest,
    FutureTwinResponse,
    HealthResponse,
    IntegrationsResponse,
    IntelligenceDecisionRequest,
    IntelligenceDecisionResponse,
    LanguageDetectRequest,
    LanguageDetectResponse,
    LifeFeedResponse,
    MissionBriefingRequest,
    MissionBriefingResponse,
    MultilingualChatRequest,
    MultilingualChatResponse,
    MultilingualLanguageResponse,
    MultilingualTranslateRequest,
    MultilingualTranslateResponse,
    OutcomeUpdateRequest,
    OutcomeUpdateResponse,
    PrivacyDeleteRequest,
    PrivacyDeleteResponse,
    PrivacyExportResponse,
    ProofCaptureRequest,
    ProofCaptureResponse,
    SarvamSttResponse,
    SarvamTtsRequest,
    SarvamTtsResponse,
    ServiceRoute,
    SystemHealthResponse,
    UserSettingsPatch,
    UserSettingsResponse,
    VoiceActionRuntimeRequest,
    VoiceActionRuntimeResponse,
)
from .service import ApiGatewayService, create_api_gateway_service

_rate_windows: dict[str, deque[float]] = defaultdict(deque)

_SERVICE_PROXY_PREFIXES = {
    "voice": "voice_gateway",
    "clone-council": "clone_council",
    "future-simulation": "future_simulation",
    "memory": "memory_system",
    "opportunities": "opportunity_engine",
    "social-graph": "social_graph",
    "alter-lens": "alter_lens",
    "reputation": "reputation_engine",
    "officekit": "officekit",
}
_HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}

app = FastAPI(
    title="ALTER API Gateway",
    version="0.1.0",
    description="Client-facing API gateway for ALTER.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    if request.url.path in {"/healthz", "/v1/gateway/routes"}:
        return await call_next(request)
    settings = get_settings()
    limit = max(settings.rate_limit_per_minute, 10)
    key = request.client.host if request.client else "unknown"
    now = time.time()
    window = _rate_windows[key]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= limit:
        return JSONResponse(
            status_code=429,
            content={
                "detail": "Rate limit exceeded. Slow down and retry shortly.",
            },
        )
    window.append(now)
    return await call_next(request)


@lru_cache(maxsize=1)
def get_service() -> ApiGatewayService:
    return create_api_gateway_service()


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        service="alter-api-gateway",
        environment=settings.gateway_env,
    )


@app.get("/v1/gateway/architecture", response_model=ArchitectureResponse)
async def architecture() -> ArchitectureResponse:
    return ArchitectureResponse(
        service="alter-api-gateway",
        components=[
            "service registry",
            "health aggregator",
            "mission briefing composer",
            "intelligence kernel orchestrator",
            "outcome learning loop",
            "future twin engine",
            "action compiler",
            "evidence engine",
            "opportunity arbitrage engine",
            "proof capture os",
            "daily briefing engine",
            "voice action runtime",
            "Sarvam multilingual AI bridge",
            "Sarvam speech-to-text and text-to-speech bridge",
            "consent ledger and privacy controls",
            "safe data ingestion intake",
            "agent planner to tool executor policy layer",
            "client route discovery",
        ],
        data_flow=[
            "Clients call the gateway as the edge entrypoint.",
            "Gateway exposes route discovery for feature services.",
            "Gateway checks downstream service health.",
            "Mission briefing composes the phone and laptop execution sequence.",
            "Decision Intelligence retrieves memory, simulates futures, debates the council, ranks opportunities, and writes back durable memory.",
            "Outcome Learning turns recommendations into experiments, captures reality, writes outcome memory, and updates reputation.",
            "Future Twin compares stated ambition with evidence, predicts trajectory drift, compiles the next action, and surfaces opportunity arbitrage.",
            "Proof Capture OS turns real-world artifacts into memory, reputation, graph edges, daily briefings, and Future Twin deltas.",
            "Voice Action Runtime turns Hey Alter transcripts into intent, reasoning, action graph, spoken response, and follow-up.",
            "Sarvam bridge localizes chat, voice responses, and translation across Indian languages when SARVAM_API_KEY is configured.",
            "Sarvam speech endpoints transcribe uploaded audio and synthesize localized voice when SARVAM_API_KEY is configured.",
            "Consent, ingestion, planner, and privacy endpoints keep sensitive phone data explicit, auditable, and reversible.",
        ],
        output_contract={
            "SystemHealthResponse": ["status", "services", "checked_at"],
            "MissionBriefingResponse": [
                "command_summary",
                "phone_layer",
                "laptop_layer",
                "recommended_sequence",
                "route_targets",
            ],
            "DemoRunResponse": [
                "headline",
                "executive_summary",
                "steps",
                "key_metrics",
                "next_actions",
            ],
            "IntelligenceDecisionResponse": [
                "recommendation",
                "confidence_score",
                "experiment_plan",
                "future_options",
                "memory_context",
                "opportunity_matches",
                "next_actions",
                "signals",
            ],
            "OutcomeUpdateResponse": [
                "execution_score",
                "confidence_delta",
                "memory_id",
                "reputation_event_id",
                "profile_updates",
                "next_recommendation",
            ],
            "FutureTwinResponse": [
                "trajectory",
                "action",
                "evidence_signals",
                "opportunity_arbitrage",
                "daily_question",
                "model_updates",
            ],
            "ProofCaptureResponse": [
                "evidence_records",
                "graph_nodes",
                "graph_edges",
                "daily_briefing",
                "trust_profile",
                "future_twin_delta",
            ],
            "VoiceActionRuntimeResponse": [
                "wake_word_detected",
                "inferred_intent",
                "ai_provider",
                "response_language_code",
                "spoken_response",
                "action_graph",
                "experiment_plan",
                "follow_up_questions",
            ],
            "MultilingualChatResponse": [
                "text",
                "provider",
                "target_language_code",
                "sarvam_enabled",
            ],
            "SarvamSttResponse": ["transcript", "language_code", "provider", "fallback"],
            "SarvamTtsResponse": ["audio_base64", "speaker", "provider", "fallback"],
            "ConsentLedgerResponse": ["grants", "required_for_full_assistant", "audit_note"],
            "DataIngestionResponse": ["accepted", "memory_candidates", "audit_events"],
            "AgentPlannerResponse": ["steps", "policy_warnings", "ready_to_execute"],
            "PrivacyExportResponse": ["included_sections", "summary", "download_ready"],
        },
    )


@app.get("/v1/gateway/routes", response_model=list[ServiceRoute])
async def routes() -> list[ServiceRoute]:
    return get_service().routes()


@app.get("/v1/system/health", response_model=SystemHealthResponse)
async def system_health() -> SystemHealthResponse:
    return await get_service().system_health()


@app.post("/v1/mission/briefing", response_model=MissionBriefingResponse)
async def mission_briefing(request: MissionBriefingRequest) -> MissionBriefingResponse:
    return get_service().mission_briefing(request)


@app.get("/v1/life-feed", response_model=LifeFeedResponse)
async def life_feed(user_id: UUID = Query(...)) -> LifeFeedResponse:
    return get_service().life_feed(user_id)


@app.get("/v1/user/settings", response_model=UserSettingsResponse)
async def user_settings(user_id: UUID = Query(...)) -> UserSettingsResponse:
    return get_service().user_settings(user_id)


@app.patch("/v1/user/settings", response_model=UserSettingsResponse)
async def patch_user_settings(
    patch: UserSettingsPatch,
    user_id: UUID = Query(...),
) -> UserSettingsResponse:
    return get_service().patch_user_settings(user_id, patch)


@app.get("/v1/integrations", response_model=IntegrationsResponse)
async def integrations(user_id: UUID = Query(...)) -> IntegrationsResponse:
    return get_service().integrations(user_id)


@app.get("/v1/multilingual/languages", response_model=MultilingualLanguageResponse)
async def multilingual_languages() -> MultilingualLanguageResponse:
    return get_service().multilingual_languages()


@app.post("/v1/multilingual/chat", response_model=MultilingualChatResponse)
async def multilingual_chat(request: MultilingualChatRequest) -> MultilingualChatResponse:
    return await get_service().multilingual_chat(request)


@app.post("/v1/multilingual/translate", response_model=MultilingualTranslateResponse)
async def multilingual_translate(
    request: MultilingualTranslateRequest,
) -> MultilingualTranslateResponse:
    return await get_service().multilingual_translate(request)


@app.post("/v1/multilingual/detect-language", response_model=LanguageDetectResponse)
async def detect_language(request: LanguageDetectRequest) -> LanguageDetectResponse:
    return await get_service().detect_language(request)


@app.post("/v1/multilingual/text-to-speech", response_model=SarvamTtsResponse)
async def text_to_speech(request: SarvamTtsRequest) -> SarvamTtsResponse:
    return await get_service().text_to_speech(request)


@app.post("/v1/multilingual/speech-to-text", response_model=SarvamSttResponse)
async def speech_to_text(
    file: UploadFile = File(...),
    language_code: str = Form("unknown"),
    mode: str = Form("transcribe"),
) -> SarvamSttResponse:
    audio_bytes = await file.read()
    return await get_service().speech_to_text(
        audio_bytes=audio_bytes,
        filename=file.filename or "audio.wav",
        content_type=file.content_type or "application/octet-stream",
        language_code=language_code,
        mode=mode,
    )


@app.get("/v1/security/consent-ledger", response_model=ConsentLedgerResponse)
async def consent_ledger(user_id: UUID = Query(...)) -> ConsentLedgerResponse:
    return get_service().consent_ledger(user_id)


@app.post("/v1/security/consent", response_model=ConsentGrant)
async def record_consent(request: ConsentGrantRequest) -> ConsentGrant:
    return get_service().record_consent(request)


@app.post("/v1/data-ingestion/import", response_model=DataIngestionResponse)
async def ingest_data(request: DataIngestionRequest) -> DataIngestionResponse:
    return get_service().ingest_data(request)


@app.post("/v1/agent/plan", response_model=AgentPlannerResponse)
async def plan_agent(request: AgentPlannerRequest) -> AgentPlannerResponse:
    return get_service().plan_agent(request)


@app.get("/v1/privacy/export", response_model=PrivacyExportResponse)
async def privacy_export(user_id: UUID = Query(...)) -> PrivacyExportResponse:
    return get_service().privacy_export(user_id)


@app.post("/v1/privacy/delete", response_model=PrivacyDeleteResponse)
async def privacy_delete(request: PrivacyDeleteRequest) -> PrivacyDeleteResponse:
    return get_service().privacy_delete(request)


@app.post("/v1/orchestration/future-os", response_model=DemoRunResponse)
async def future_os_orchestration(request: DemoRunRequest) -> DemoRunResponse:
    return await get_service().future_os_demo(request)


@app.post("/v1/demo/future-os", response_model=DemoRunResponse)
async def future_os_demo(request: DemoRunRequest) -> DemoRunResponse:
    return await get_service().future_os_demo(request)


@app.post("/v1/intelligence/decide", response_model=IntelligenceDecisionResponse)
async def decide(request: IntelligenceDecisionRequest) -> IntelligenceDecisionResponse:
    return await get_service().decide(request)


@app.post("/v1/intelligence/outcomes", response_model=OutcomeUpdateResponse)
async def record_outcome(request: OutcomeUpdateRequest) -> OutcomeUpdateResponse:
    return await get_service().record_outcome(request)


@app.post("/v1/intelligence/future-twin", response_model=FutureTwinResponse)
async def future_twin(request: FutureTwinRequest) -> FutureTwinResponse:
    return await get_service().future_twin(request)


@app.post("/v1/proof/capture", response_model=ProofCaptureResponse)
async def capture_proof(request: ProofCaptureRequest) -> ProofCaptureResponse:
    return await get_service().capture_proof(request)


@app.post("/v1/voice/action-runtime", response_model=VoiceActionRuntimeResponse)
async def voice_action_runtime(
    request: VoiceActionRuntimeRequest,
) -> VoiceActionRuntimeResponse:
    return await get_service().voice_action_runtime(request)


@app.api_route(
    "/v1/{proxied_path:path}",
    methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
)
async def proxy_feature_service(proxied_path: str, request: Request) -> Response:
    prefix = proxied_path.split("/", 1)[0]
    service_name = _SERVICE_PROXY_PREFIXES.get(prefix)
    if service_name is None:
        return JSONResponse(
            status_code=404,
            content={
                "detail": f"No API gateway route is registered for /v1/{proxied_path}.",
            },
        )

    routes_by_name = {
        route.name: route.base_url.rstrip("/") for route in get_service().routes()
    }
    base_url = routes_by_name.get(service_name, "")
    if not base_url:
        return JSONResponse(
            status_code=502,
            content={"detail": f"Service route is not configured: {service_name}."},
        )

    target_url = f"{base_url}/v1/{proxied_path}"
    if request.url.query:
        target_url = f"{target_url}?{request.url.query}"
    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() not in _HOP_BY_HOP_HEADERS
    }
    body = await request.body()
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            proxied = await client.request(
                request.method,
                target_url,
                content=body if body else None,
                headers=headers,
            )
    except httpx.HTTPError as error:
        return JSONResponse(
            status_code=502,
            content={
                "detail": f"{service_name} unavailable: {error}",
                "service": service_name,
            },
        )

    content_type = proxied.headers.get("content-type")
    return Response(
        content=proxied.content,
        status_code=proxied.status_code,
        media_type=content_type,
    )
