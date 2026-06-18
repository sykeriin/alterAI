from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
import time
from typing import Any
from uuid import UUID

import httpx

from .config import Settings, get_settings
from .schemas import (
    DemoRunRequest,
    DemoRunResponse,
    DemoStep,
    CompiledAction,
    ConsentGrant,
    ConsentGrantRequest,
    ConsentLedgerResponse,
    DataIngestionRequest,
    DataIngestionResponse,
    EvidenceSignal,
    ExperimentPlan,
    FutureOption,
    FutureTwinRequest,
    FutureTwinResponse,
    FutureTwinTrajectory,
    IntegrationsResponse,
    IntelligenceDecisionRequest,
    IntelligenceDecisionResponse,
    IntelligenceSignal,
    LanguageDetectRequest,
    LanguageDetectResponse,
    LifeFeedResponse,
    MissionBriefingRequest,
    MissionBriefingResponse,
    MultilingualChatRequest,
    MultilingualChatResponse,
    MultilingualLanguage,
    MultilingualLanguageResponse,
    MultilingualTranslateRequest,
    MultilingualTranslateResponse,
    OutcomeUpdateRequest,
    OutcomeUpdateResponse,
    OpportunityArbitrageMove,
    PlatformIntegration,
    PrivacyDeleteRequest,
    PrivacyDeleteResponse,
    PrivacyExportResponse,
    ProofCaptureRequest,
    ProofCaptureResponse,
    ProofEvidenceRecord,
    ProofGraphEdge,
    ProofGraphNode,
    AgentPlanStep,
    AgentPlannerRequest,
    AgentPlannerResponse,
    ContextItem,
    ServiceHealth,
    ServiceRoute,
    SarvamSttResponse,
    SarvamTtsRequest,
    SarvamTtsResponse,
    SystemHealthResponse,
    DailyProofBriefing,
    FutureTwinDelta,
    TrajectoryPoint,
    TrustExecutionProfile,
    UserSettingsPatch,
    UserSettingsResponse,
    VoiceActionRuntimeRequest,
    VoiceActionRuntimeResponse,
)
from .sarvam_client import (
    INDIAN_LANGUAGE_SPECS,
    MAJOR_FOREIGN_LANGUAGE_SPECS,
    SarvamClient,
    language_for_code,
)


class ApiGatewayService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._sarvam = SarvamClient(settings)

    def routes(self) -> list[ServiceRoute]:
        return [
            ServiceRoute(
                name=name,
                base_url=url,
                health_url=f"{url.rstrip('/')}/healthz",
            )
            for name, url in self._settings.service_urls().items()
        ]

    async def system_health(self) -> SystemHealthResponse:
        async with httpx.AsyncClient(timeout=1.5) as client:
            services = await asyncio.gather(
                *(_check_service(client, route) for route in self.routes())
            )
        status = "ok" if all(service.status == "ok" for service in services) else "degraded"
        return SystemHealthResponse(status=status, services=services)

    def mission_briefing(self, request: MissionBriefingRequest) -> MissionBriefingResponse:
        phone = ["voice_gateway", "alter_lens", "nfc"]
        laptop = [
            "future_simulation",
            "clone_council",
            "opportunity_engine",
            "social_graph",
            "reputation_engine",
        ]
        requested = request.include_services or [*phone, *laptop, "memory_system", "officekit"]
        route_map = {route.name: route.base_url for route in self.routes()}
        return MissionBriefingResponse(
            user_id=request.user_id,
            objective=request.objective,
            command_summary=(
                f"Mission objective '{request.objective}' is ready for cross-device execution "
                f"from {request.device_context}."
            ),
            phone_layer=phone,
            laptop_layer=laptop,
            recommended_sequence=[
                "Capture intent with Voice Gateway.",
                "Retrieve memory context.",
                "Simulate futures and run Clone Council.",
                "Find opportunities and warm paths.",
                "Write decision, follow-up, and reputation events.",
            ],
            route_targets=[route_map[name] for name in requested if name in route_map],
        )

    def life_feed(self, user_id: UUID) -> LifeFeedResponse:
        now = datetime.now(UTC)
        weekday = now.strftime("%A")
        month = now.strftime("%B")
        return LifeFeedResponse(
            user_id=user_id,
            greeting="ALTER is ready.",
            date_summary=f"{weekday}, {now.day} {month} - no live feed items available yet",
            focus_title="",
            focus_rationale="",
            items_needing_attention=0,
            tasks=[],
            opportunities=[],
        )

    def user_settings(self, user_id: UUID) -> UserSettingsResponse:
        return UserSettingsResponse(
            user_id=user_id,
            languages=[],
            role="",
            permissions={
                "wake": False,
                "calendar": False,
                "resume": False,
                "location": False,
                "notif": False,
                "comm": False,
            },
        )

    def patch_user_settings(
        self, user_id: UUID, patch: UserSettingsPatch
    ) -> UserSettingsResponse:
        current = self.user_settings(user_id)
        merged = {**current.permissions, **patch.permissions}
        return UserSettingsResponse(
            user_id=user_id,
            languages=patch.languages or current.languages,
            role=patch.role or current.role,
            permissions=merged,
        )

    def integrations(self, user_id: UUID) -> IntegrationsResponse:
        return IntegrationsResponse(
            user_id=user_id,
            platforms=[
                PlatformIntegration(
                    id="notion",
                    name="Notion",
                    connected=False,
                    status="Not connected",
                ),
                PlatformIntegration(
                    id="github",
                    name="GitHub",
                    connected=False,
                    status="Not connected",
                ),
            ],
        )

    def multilingual_languages(self) -> MultilingualLanguageResponse:
        return MultilingualLanguageResponse(
            sarvam_enabled=self._sarvam.enabled,
            indian_languages=[
                MultilingualLanguage(
                    code=language.code,
                    name=language.name,
                    region=language.region,
                    sarvam_translate=language.sarvam_translate,
                    sarvam_chat=language.sarvam_chat,
                )
                for language in INDIAN_LANGUAGE_SPECS
            ],
            major_foreign_languages=[
                MultilingualLanguage(
                    code=language.code,
                    name=language.name,
                    region=language.region,
                    sarvam_translate=language.sarvam_translate,
                    sarvam_chat=language.sarvam_chat,
                )
                for language in MAJOR_FOREIGN_LANGUAGE_SPECS
            ],
        )

    async def multilingual_chat(
        self,
        request: MultilingualChatRequest,
    ) -> MultilingualChatResponse:
        language = language_for_code(request.target_language_code)
        if self._sarvam.enabled:
            try:
                result = await self._sarvam.chat(
                    messages=[
                        {"role": message.role, "content": message.content}
                        for message in request.messages
                    ],
                    target_language_code=language.code,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens,
                )
                return MultilingualChatResponse(
                    text=result["text"],
                    provider=result["provider"],
                    model=str(result["model"]),
                    target_language_code=language.code,
                    language_display_name=language.name,
                    sarvam_enabled=True,
                    usage=dict(result.get("usage") or {}),
                )
            except Exception as error:
                return MultilingualChatResponse(
                    text=_local_multilingual_fallback(request.messages[-1].content, language.name),
                    provider="alter-local",
                    model="deterministic-fallback",
                    target_language_code=language.code,
                    language_display_name=language.name,
                    sarvam_enabled=True,
                    fallback=True,
                    usage={"error": str(error)},
                )
        return MultilingualChatResponse(
            text=_local_multilingual_fallback(request.messages[-1].content, language.name),
            provider="alter-local",
            model="deterministic-fallback",
            target_language_code=language.code,
            language_display_name=language.name,
            sarvam_enabled=False,
            fallback=True,
        )

    async def multilingual_translate(
        self,
        request: MultilingualTranslateRequest,
    ) -> MultilingualTranslateResponse:
        language = language_for_code(request.target_language_code)
        if self._sarvam.enabled and language.sarvam_translate:
            try:
                result = await self._sarvam.translate(
                    text=request.text,
                    source_language_code=request.source_language_code,
                    target_language_code=language.code,
                )
                return MultilingualTranslateResponse(
                    text=result["text"],
                    provider=result["provider"],
                    model=str(result["model"]),
                    source_language_code=str(result["source_language_code"]),
                    target_language_code=language.code,
                    language_display_name=language.name,
                    sarvam_enabled=True,
                    request_id=(
                        str(result["request_id"]) if result.get("request_id") is not None else None
                    ),
                )
            except Exception as error:
                return MultilingualTranslateResponse(
                    text=request.text,
                    provider="alter-local",
                    model="deterministic-fallback",
                    source_language_code=request.source_language_code,
                    target_language_code=language.code,
                    language_display_name=language.name,
                    sarvam_enabled=True,
                    fallback=True,
                    request_id=None,
                    error=str(error),
                )
        return MultilingualTranslateResponse(
            text=request.text,
            provider="alter-local",
            model="deterministic-fallback",
            source_language_code=request.source_language_code,
            target_language_code=language.code,
            language_display_name=language.name,
            sarvam_enabled=self._sarvam.enabled,
            fallback=True,
            request_id=None,
        )

    async def detect_language(
        self,
        request: LanguageDetectRequest,
    ) -> LanguageDetectResponse:
        if self._sarvam.enabled:
            try:
                result = await self._sarvam.detect_language(text=request.text)
                return LanguageDetectResponse(
                    provider="sarvam",
                    sarvam_enabled=True,
                    language_code=str(result.get("language_code") or "unknown"),
                    script_code=str(result.get("script_code") or ""),
                    request_id=(
                        str(result["request_id"]) if result.get("request_id") is not None else None
                    ),
                )
            except Exception as error:
                return LanguageDetectResponse(
                    provider="alter-local",
                    sarvam_enabled=True,
                    language_code=_infer_language_code(request.text),
                    script_code="",
                    fallback=True,
                    error=str(error),
                )
        return LanguageDetectResponse(
            provider="alter-local",
            sarvam_enabled=False,
            language_code=_infer_language_code(request.text),
            script_code="",
            fallback=True,
        )

    async def text_to_speech(self, request: SarvamTtsRequest) -> SarvamTtsResponse:
        language = language_for_code(request.target_language_code)
        if self._sarvam.enabled:
            try:
                result = await self._sarvam.text_to_speech(
                    text=request.text,
                    target_language_code=language.code,
                    speaker=request.speaker,
                    pace=request.pace,
                    speech_sample_rate=request.speech_sample_rate,
                )
                return SarvamTtsResponse(
                    provider="sarvam",
                    model=str(result["model"]),
                    sarvam_enabled=True,
                    target_language_code=language.code,
                    language_display_name=language.name,
                    speaker=str(result["speaker"]),
                    speech_sample_rate=int(result["speech_sample_rate"]),
                    audio_base64=str(result.get("audio_base64") or ""),
                    audio_count=int(result.get("audio_count") or 0),
                    request_id=(
                        str(result["request_id"]) if result.get("request_id") is not None else None
                    ),
                )
            except Exception as error:
                return SarvamTtsResponse(
                    provider="alter-local",
                    model="deterministic-fallback",
                    sarvam_enabled=True,
                    target_language_code=language.code,
                    language_display_name=language.name,
                    speaker=request.speaker,
                    speech_sample_rate=request.speech_sample_rate,
                    fallback=True,
                    error=str(error),
                )
        return SarvamTtsResponse(
            provider="alter-local",
            model="deterministic-fallback",
            sarvam_enabled=False,
            target_language_code=language.code,
            language_display_name=language.name,
            speaker=request.speaker,
            speech_sample_rate=request.speech_sample_rate,
            fallback=True,
            error="SARVAM_API_KEY is not configured.",
        )

    async def speech_to_text(
        self,
        *,
        audio_bytes: bytes,
        filename: str,
        content_type: str,
        language_code: str = "unknown",
        mode: str = "transcribe",
    ) -> SarvamSttResponse:
        if not audio_bytes:
            return SarvamSttResponse(
                provider="alter-local",
                model="deterministic-fallback",
                sarvam_enabled=self._sarvam.enabled,
                transcript="",
                fallback=True,
                error="No audio bytes were uploaded.",
            )
        if self._sarvam.enabled:
            try:
                result = await self._sarvam.speech_to_text(
                    audio_bytes=audio_bytes,
                    filename=filename,
                    content_type=content_type,
                    language_code=language_code,
                    mode=mode,
                )
                return SarvamSttResponse(
                    provider="sarvam",
                    model=str(result["model"]),
                    sarvam_enabled=True,
                    transcript=str(result.get("transcript") or ""),
                    language_code=str(result.get("language_code") or ""),
                    language_probability=(
                        float(result["language_probability"])
                        if result.get("language_probability") is not None
                        else None
                    ),
                    request_id=(
                        str(result["request_id"]) if result.get("request_id") is not None else None
                    ),
                    timestamps=(
                        result["timestamps"] if isinstance(result.get("timestamps"), dict) else None
                    ),
                    diarized_transcript=(
                        result["diarized_transcript"]
                        if isinstance(result.get("diarized_transcript"), dict)
                        else None
                    ),
                )
            except Exception as error:
                return SarvamSttResponse(
                    provider="alter-local",
                    model="deterministic-fallback",
                    sarvam_enabled=True,
                    transcript="",
                    language_code="",
                    fallback=True,
                    error=str(error),
                )
        return SarvamSttResponse(
            provider="alter-local",
            model="deterministic-fallback",
            sarvam_enabled=False,
            transcript="",
            fallback=True,
            error="SARVAM_API_KEY is not configured.",
        )

    def consent_ledger(self, user_id: UUID) -> ConsentLedgerResponse:
        grants = [
            ConsentGrant(
                user_id=user_id,
                source="notifications",
                access_level="visible_notification_text",
                granted=False,
                retention_days=30,
                reason="Enable Android Notification Listener to read incoming notification snippets.",
            ),
            ConsentGrant(
                user_id=user_id,
                source="screen_accessibility",
                access_level="visible_screen_only",
                granted=False,
                retention_days=7,
                reason="Enable Accessibility Service to read visible text and perform user-approved actions.",
            ),
            ConsentGrant(
                user_id=user_id,
                source="manual_imports",
                access_level="user_selected_files",
                granted=True,
                retention_days=90,
                reason="User-selected exports and share-sheet imports can be indexed with consent.",
            ),
        ]
        return ConsentLedgerResponse(
            user_id=user_id,
            grants=grants,
            required_for_full_assistant=[
                "Microphone foreground service",
                "Notification Listener",
                "Accessibility Service",
                "Contacts/phone/SMS runtime permissions when actions need them",
                "Backend URL reachable from the phone",
            ],
            audit_note=(
                "ALTER does not silently scrape chats or bypass Android permission gates; "
                "each source is explicit and reversible."
            ),
        )

    def record_consent(self, request: ConsentGrantRequest) -> ConsentGrant:
        return ConsentGrant(
            user_id=request.user_id,
            source=request.source,
            access_level=request.access_level,
            granted=request.granted,
            retention_days=request.retention_days,
            reason=request.reason or "Updated from Permission Hub or backend API.",
        )

    def ingest_data(self, request: DataIngestionRequest) -> DataIngestionResponse:
        blocked = _ingestion_blockers(request)
        accepted = not blocked
        candidates = _memory_candidates_from_items(request.items, request.source) if accepted else []
        return DataIngestionResponse(
            user_id=request.user_id,
            source=request.source,
            accepted=accepted,
            imported_count=len(candidates),
            memory_candidates=candidates,
            blocked_reasons=blocked,
            audit_events=[
                f"source={request.source}",
                f"mode={request.import_mode}",
                f"metadata_only={request.metadata_only}",
                "manual_or_android-approved_surface_only",
            ],
        )

    def plan_agent(self, request: AgentPlannerRequest) -> AgentPlannerResponse:
        steps, warnings = _planner_steps(request)
        return AgentPlannerResponse(
            user_id=request.user_id,
            goal=request.goal,
            autonomy_level=request.autonomy_level,
            ready_to_execute=bool(steps) and not any(step.blocked_reason for step in steps),
            steps=steps,
            policy_warnings=warnings,
            decision_context_pack=_build_context_pack(request),
        )

    def privacy_export(self, user_id: UUID) -> PrivacyExportResponse:
        return PrivacyExportResponse(
            user_id=user_id,
            included_sections=[
                "consent_ledger",
                "manual_import_manifest",
                "agent_action_audit",
                "memory_index_summary",
                "backend_settings",
            ],
            download_ready=True,
            summary={
                "format": "json",
                "contains_raw_private_messages": False,
                "note": "Raw chat exports are only present if the user manually imported them.",
            },
        )

    def privacy_delete(self, request: PrivacyDeleteRequest) -> PrivacyDeleteResponse:
        if not request.confirm:
            return PrivacyDeleteResponse(
                user_id=request.user_id,
                accepted=False,
                deleted_scopes=[],
                blocked_reasons=["Set confirm=true to delete selected privacy scopes."],
                audit_event="privacy_delete_rejected_missing_confirmation",
            )
        scopes = request.scopes or ["manual_imports", "memory_candidates", "agent_action_audit"]
        return PrivacyDeleteResponse(
            user_id=request.user_id,
            accepted=True,
            deleted_scopes=scopes,
            blocked_reasons=[],
            audit_event=f"privacy_delete_accepted:{','.join(scopes)}",
        )

    async def future_os_demo(self, request: DemoRunRequest) -> DemoRunResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        objective = request.objective
        user_id = str(request.user_id)

        async with httpx.AsyncClient(timeout=6.0) as client:
            voice = await _run_step(
                client,
                name="voice_gateway",
                title="Wake Word + Intent",
                base_url=routes["voice_gateway"],
                path="/v1/voice/session",
                payload={
                    "transcript": f"Hey Alter, simulate my future for this decision: {objective}",
                    "locale": "en-US",
                },
                summary_builder=lambda data: (
                    f"Wake word={data.get('wake_word_detected')} "
                    f"intent={data.get('inferred_intent')}."
                ),
            )
            future = await _run_step(
                client,
                name="future_simulation",
                title="Future Simulation",
                base_url=routes["future_simulation"],
                path="/v1/future-simulation/simulate",
                payload=_future_payload(request),
                summary_builder=lambda data: _future_summary(data),
            )
            council = await _run_step(
                client,
                name="clone_council",
                title="Clone Council Debate",
                base_url=routes["clone_council"],
                path="/v1/clone-council/debate",
                payload={
                    "question": f"What is the highest-leverage next move for: {objective}?",
                    "context": {
                        "device_context": request.device_context,
                    },
                },
                summary_builder=lambda data: (
                    f"7-agent debate reached {round(float(data.get('confidence_score', 0)) * 100)}% "
                    "confidence."
                ),
            )
            opportunities = await _run_step(
                client,
                name="opportunity_engine",
                title="Opportunity Radar",
                base_url=routes["opportunity_engine"],
                path="/v1/opportunities/pipeline",
                payload=_opportunity_payload(request),
                summary_builder=lambda data: _opportunity_summary(data),
            )
            memory = await _run_memory_step(client, routes["memory_system"], user_id, objective)
            social = await _run_social_step(client, routes["social_graph"], request)
            reputation = await _run_step(
                client,
                name="reputation_engine",
                title="Reputation Ledger",
                base_url=routes["reputation_engine"],
                path="/v1/reputation/events",
                payload={
                    "user_id": user_id,
                    "event_type": "follow_up",
                    "title": "Ran ALTER end-to-end decision loop",
                    "impact_score": 24,
                },
                summary_builder=lambda data: (
                    f"Logged reputation event '{data.get('event_type', 'follow_up')}'."
                ),
            )
            score = await _run_step(
                client,
                name="reputation_score",
                title="Trust Score",
                base_url=routes["reputation_engine"],
                path=f"/v1/reputation/users/{user_id}/score",
                payload=None,
                summary_builder=lambda data: f"Trust score is {data.get('score', 'ready')}.",
            )
            office = await _run_step(
                client,
                name="officekit",
                title="OfficeKit Briefing",
                base_url=routes["officekit"],
                path="/v1/officekit/briefing",
                payload={
                    "user_id": user_id,
                    "objective": objective,
                    "inline_artifacts": [
                        {
                            "user_id": user_id,
                            "artifact_type": "meeting",
                            "title": "Mission control decision brief",
                            "content": (
                                f"The user is evaluating this objective: {objective}"
                            ),
                            "participants": ["ALTER", "User"],
                        }
                    ],
                },
                summary_builder=lambda data: (
                    f"Created {len(data.get('action_items', []))} action item(s)."
                ),
            )

        steps = [voice, future, council, opportunities, memory, social, reputation, score, office]
        ok_steps = [step for step in steps if step.status == "ok"]
        future_data = future.data
        council_data = council.data
        opportunity_data = opportunities.data
        office_data = office.data

        return DemoRunResponse(
            user_id=request.user_id,
            objective=objective,
            headline=(
                f"ALTER ran {len(ok_steps)}/{len(steps)} systems and produced a decision plan."
            ),
            executive_summary=_executive_summary(
                objective=objective,
                future_data=future_data,
                council_data=council_data,
                opportunity_data=opportunity_data,
            ),
            steps=steps,
            key_metrics={
                "systems": f"{len(ok_steps)}/{len(steps)}",
                "futures": str(len(future_data.get("futures", []))),
                "council": f"{round(float(council_data.get('confidence_score', 0)) * 100)}%",
                "opportunities": str(
                    len(
                        opportunity_data.get("recommendations", {}).get(
                            "recommendations",
                            [],
                        )
                    )
                ),
                "trust": str(score.data.get("score", "ready")),
            },
            next_actions=_next_actions(council_data, office_data),
            risks=_risks(council_data, office_data),
            opportunities=_opportunities(council_data, opportunity_data),
        )

    async def decide(
        self,
        request: IntelligenceDecisionRequest,
    ) -> IntelligenceDecisionResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        question = request.question.strip()
        user_id = str(request.user_id)

        async with httpx.AsyncClient(timeout=8.0) as client:
            memory = await _run_step(
                client,
                name="memory_retrieval",
                title="Personal Memory Retrieval",
                base_url=routes["memory_system"],
                path="/v1/memory/retrieve",
                payload={
                    "user_id": user_id,
                    "task": question,
                    "limit": 8,
                    "include_private": False,
                },
                summary_builder=lambda data: (
                    f"Retrieved {len(data.get('context', []))} durable memory signal(s)."
                ),
            )

            future = await _run_step(
                client,
                name="future_simulation",
                title="Future Simulation Engine",
                base_url=routes["future_simulation"],
                path="/v1/future-simulation/simulate",
                payload=_decision_future_payload(request),
                summary_builder=lambda data: _future_summary(data),
            )
            opportunities = await _run_step(
                client,
                name="opportunity_engine",
                title="Opportunity Discovery",
                base_url=routes["opportunity_engine"],
                path="/v1/opportunities/pipeline",
                payload=_decision_opportunity_payload(request),
                summary_builder=lambda data: _opportunity_summary(data),
            )

            memory_context = _memory_context(memory.data)
            future_options = _future_options(future.data)
            opportunity_matches = _opportunity_titles(opportunities.data)
            council = await _run_step(
                client,
                name="clone_council",
                title="Clone Council Deliberation",
                base_url=routes["clone_council"],
                path="/v1/clone-council/debate",
                payload={
                    "user_id": user_id,
                    "question": (
                        "Give a decisive recommendation for this life or career decision: "
                        f"{question}"
                    ),
                    "context": {
                        "kernel": "alter_intelligence_v1",
                        "user_profile": request.user_profile,
                        "skills": request.skills,
                        "goals": request.goals,
                        "interests": request.interests,
                        "memory_context": memory_context,
                        "future_options": [
                            option.model_dump() for option in future_options
                        ],
                        "opportunity_matches": opportunity_matches,
                        "external_context": request.context,
                    },
                },
                summary_builder=lambda data: (
                    f"Council confidence is "
                    f"{round(float(data.get('confidence_score', 0)) * 100)}%."
                ),
            )
            office = await _run_step(
                client,
                name="officekit",
                title="Execution Briefing",
                base_url=routes["officekit"],
                path="/v1/officekit/briefing",
                payload={
                    "user_id": user_id,
                    "objective": question[:600],
                    "inline_artifacts": [
                        {
                            "user_id": user_id,
                            "artifact_type": "document",
                            "title": "ALTER Decision Intelligence Report",
                            "content": _decision_artifact_content(
                                question=question,
                                future_options=future_options,
                                opportunity_matches=opportunity_matches,
                                memory_context=memory_context,
                            ),
                            "participants": ["ALTER", "User"],
                        }
                    ],
                },
                summary_builder=lambda data: (
                    f"Created {len(data.get('action_items', []))} execution action(s)."
                ),
            )

            recommendation = _decision_recommendation(council.data, future.data)
            actions = _next_actions(council.data, office.data)
            risks = _risks(council.data, office.data)
            opportunities_list = _opportunities(council.data, opportunities.data)
            writeback = (
                await _run_step(
                    client,
                    name="memory_writeback",
                    title="Decision Memory Writeback",
                    base_url=routes["memory_system"],
                    path="/v1/memory/items",
                    payload={
                        "user_id": user_id,
                        "memory_type": "decision",
                        "title": _truncate(question, 120),
                        "summary": _truncate(recommendation, 900),
                        "content": _memory_writeback_content(
                            question=question,
                            recommendation=recommendation,
                            actions=actions,
                            risks=risks,
                            opportunities=opportunities_list,
                        ),
                        "source": "alter_intelligence_kernel",
                        "confidence": _decision_confidence(
                            council.data,
                            future_options,
                            opportunity_matches,
                            [memory, future, opportunities, council, office],
                        ),
                        "importance": 0.88,
                        "metadata": {
                            "kernel": "alter_intelligence_v1",
                            "recommended_future": _recommended_future(
                                future.data,
                                future_options,
                            ),
                        },
                    },
                    summary_builder=lambda data: (
                        f"Saved decision memory {data.get('id', 'ready')}."
                    ),
                )
                if request.write_memory
                else DemoStep(
                    name="memory_writeback",
                    title="Decision Memory Writeback",
                    status="skipped",
                    summary="Memory writeback was disabled for this request.",
                )
            )

        steps = [memory, future, opportunities, council, office, writeback]
        confidence = _decision_confidence(
            council.data,
            future_options,
            opportunity_matches,
            steps,
        )
        recommended_future = _recommended_future(future.data, future_options)
        experiment_plan = _experiment_plan(
            question=question,
            recommendation=recommendation,
            actions=actions,
            opportunities=opportunities_list,
            future_options=future_options,
        )

        return IntelligenceDecisionResponse(
            user_id=request.user_id,
            question=question,
            recommendation=recommendation,
            confidence_score=confidence,
            decision_summary=_decision_summary(
                question=question,
                recommended_future=recommended_future,
                memory_context=memory_context,
                opportunity_matches=opportunity_matches,
                steps=steps,
            ),
            recommended_future=recommended_future,
            experiment_plan=experiment_plan,
            future_options=future_options,
            memory_context=memory_context,
            opportunity_matches=opportunity_matches,
            next_actions=actions,
            risks=risks,
            opportunities=opportunities_list,
            signals=[_to_signal(step) for step in steps],
            created_memory_id=_created_memory_id(writeback.data),
        )

    async def record_outcome(
        self,
        request: OutcomeUpdateRequest,
    ) -> OutcomeUpdateResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        user_id = str(request.user_id)
        execution_score = _execution_score(request)
        confidence_delta = _confidence_delta(request)
        impact_score = _reputation_impact_score(request)
        memory_summary = _outcome_summary(request, execution_score, confidence_delta)

        async with httpx.AsyncClient(timeout=8.0) as client:
            memory = await _run_step(
                client,
                name="outcome_memory",
                title="Outcome Memory Writeback",
                base_url=routes["memory_system"],
                path="/v1/memory/items",
                payload={
                    "user_id": user_id,
                    "memory_type": "learning_progress",
                    "title": _truncate(
                        f"Outcome: {request.experiment_plan.action}",
                        120,
                    ),
                    "summary": _truncate(memory_summary, 900),
                    "content": _outcome_memory_content(
                        request,
                        execution_score=execution_score,
                        confidence_delta=confidence_delta,
                    ),
                    "source": "alter_outcome_loop",
                    "confidence": 0.86 if request.did_it else 0.74,
                    "importance": _outcome_importance(request),
                    "metadata": {
                        "decision_id": str(request.decision_id or ""),
                        "experiment_id": str(request.experiment_plan.experiment_id),
                        "outcome_score": request.outcome_score,
                        "execution_score": execution_score,
                        "confidence_delta": confidence_delta,
                    },
                },
                summary_builder=lambda data: (
                    f"Saved outcome memory {data.get('id', 'ready')}."
                ),
            )
            reputation = await _run_step(
                client,
                name="reputation_event",
                title="Execution Reputation Event",
                base_url=routes["reputation_engine"],
                path="/v1/reputation/events",
                payload={
                    "user_id": user_id,
                    "event_type": "delivered" if request.did_it else "missed_reply",
                    "title": _truncate(
                        "Completed ALTER experiment"
                        if request.did_it
                        else "Missed ALTER experiment",
                        180,
                    ),
                    "description": _truncate(memory_summary, 800),
                    "impact_score": impact_score,
                    "source": "alter_outcome_loop",
                    "metadata": {
                        "decision_id": str(request.decision_id or ""),
                        "experiment_id": str(request.experiment_plan.experiment_id),
                        "outcome_score": f"{request.outcome_score:.2f}",
                        "execution_score": f"{execution_score:.1f}",
                    },
                },
                summary_builder=lambda data: (
                    f"Logged {data.get('event_type', 'execution')} reputation event."
                ),
            )
            score = await _run_step(
                client,
                name="reputation_score",
                title="Updated Execution Score",
                base_url=routes["reputation_engine"],
                path=f"/v1/reputation/users/{user_id}/score",
                payload=None,
                summary_builder=lambda data: (
                    f"Trust score is {data.get('score', 'ready')}."
                ),
            )

        steps = [memory, reputation, score]
        return OutcomeUpdateResponse(
            user_id=request.user_id,
            decision_id=request.decision_id,
            execution_score=execution_score,
            confidence_delta=confidence_delta,
            memory_id=_created_memory_id(memory.data),
            reputation_event_id=_created_memory_id(reputation.data),
            reputation_score=_optional_int(score.data.get("score")),
            trust_level=str(score.data.get("trust_level") or ""),
            profile_updates=_profile_updates(request, execution_score, confidence_delta),
            next_recommendation=_outcome_next_recommendation(request, execution_score),
            memory_summary=memory_summary,
            signals=[_to_signal(step) for step in steps],
        )

    async def future_twin(
        self,
        request: FutureTwinRequest,
    ) -> FutureTwinResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        user_id = str(request.user_id)
        objective = request.objective.strip()
        horizon_months = max(12, min(120, round(request.horizon_days / 30)))

        decision = await self.decide(
            IntelligenceDecisionRequest(
                user_id=request.user_id,
                question=(
                    "Build a Future Twin for this objective. Compare stated ambition "
                    f"with real evidence and choose the highest-leverage action: {objective}"
                ),
                user_profile=request.user_profile,
                skills=request.skills,
                goals=_dedupe_strings([*request.goals, objective])[:40],
                experience=request.experience,
                interests=request.interests,
                context={
                    "runtime": "future_twin",
                    "horizon_days": request.horizon_days,
                    "recent_evidence_count": len(request.recent_evidence),
                },
                decision_horizon_months=horizon_months,
                write_memory=request.write_memory,
            )
        )

        async with httpx.AsyncClient(timeout=8.0) as client:
            memory = await _run_step(
                client,
                name="future_twin_memory",
                title="Future Twin Memory Retrieval",
                base_url=routes["memory_system"],
                path="/v1/memory/retrieve",
                payload={
                    "user_id": user_id,
                    "task": f"Find evidence, goals, decisions, outcomes, and mentors for: {objective}",
                    "limit": 12,
                    "include_private": False,
                },
                summary_builder=lambda data: (
                    f"Retrieved {len(data.get('context', []))} trajectory evidence signal(s)."
                ),
            )
            reputation = await _run_step(
                client,
                name="future_twin_reputation",
                title="Execution Reputation Read",
                base_url=routes["reputation_engine"],
                path=f"/v1/reputation/users/{user_id}/score",
                payload=None,
                summary_builder=lambda data: (
                    f"Execution trust level is {data.get('trust_level', 'ready')} "
                    f"with score {data.get('score', 'baseline')}."
                ),
            )
            evidence_steps: list[DemoStep] = []
            for evidence in request.recent_evidence:
                if not request.write_memory:
                    evidence_steps.append(
                        DemoStep(
                            name="future_twin_evidence",
                            title="Evidence Memory Writeback",
                            status="skipped",
                            summary="Evidence writeback was disabled for this request.",
                        )
                    )
                    continue
                evidence_steps.append(
                    await _run_step(
                        client,
                        name="future_twin_evidence",
                        title="Evidence Memory Writeback",
                        base_url=routes["memory_system"],
                        path="/v1/memory/items",
                        payload={
                            "user_id": user_id,
                            "memory_type": _evidence_memory_type(evidence.evidence_type),
                            "title": _truncate(evidence.title, 180),
                            "summary": _truncate(evidence.summary, 900),
                            "content": _evidence_memory_content(objective, evidence),
                            "source": "alter_future_twin",
                            "confidence": evidence.confidence,
                            "importance": _evidence_importance(evidence.evidence_type),
                            "metadata": {
                                "objective": objective,
                                "evidence_type": evidence.evidence_type,
                                "source": evidence.source,
                                "url": evidence.url or "",
                            },
                        },
                        summary_builder=lambda data: (
                            f"Saved evidence memory {data.get('id', 'ready')}."
                        ),
                    )
                )

            evidence_signals = _future_twin_evidence_signals(
                request=request,
                decision=decision,
                memory_data=memory.data,
                evidence_steps=evidence_steps,
            )
            trajectory = _future_twin_trajectory(
                request=request,
                decision=decision,
                evidence_signals=evidence_signals,
                reputation_data=reputation.data,
            )
            action = _compiled_action(
                request=request,
                decision=decision,
                trajectory=trajectory,
                evidence_signals=evidence_signals,
            )
            arbitrage = _opportunity_arbitrage(
                request=request,
                decision=decision,
                trajectory=trajectory,
                action=action,
            )
            model_updates = _future_twin_model_updates(
                trajectory=trajectory,
                evidence_signals=evidence_signals,
                action=action,
                reputation_data=reputation.data,
            )
            identity_summary = _future_twin_identity_summary(
                request=request,
                decision=decision,
                trajectory=trajectory,
                evidence_signals=evidence_signals,
            )
            daily_question = _future_twin_daily_question(
                request=request,
                decision=decision,
                trajectory=trajectory,
            )
            twin_memory = (
                await _run_step(
                    client,
                    name="future_twin_snapshot",
                    title="Future Twin Snapshot Memory",
                    base_url=routes["memory_system"],
                    path="/v1/memory/items",
                    payload={
                        "user_id": user_id,
                        "memory_type": "decision",
                        "title": _truncate(f"Future Twin: {objective}", 180),
                        "summary": _truncate(identity_summary, 900),
                        "content": _future_twin_memory_content(
                            objective=objective,
                            trajectory=trajectory,
                            action=action,
                            arbitrage=arbitrage,
                            model_updates=model_updates,
                        ),
                        "source": "alter_future_twin",
                        "confidence": _future_twin_confidence(
                            decision=decision,
                            evidence_signals=evidence_signals,
                            steps=[memory, reputation, *evidence_steps],
                        ),
                        "importance": 0.92,
                        "metadata": {
                            "alignment_score": trajectory.alignment_score,
                            "execution_velocity": trajectory.execution_velocity,
                            "drift_risk": trajectory.drift_risk,
                            "compiled_action_id": str(action.action_id),
                        },
                    },
                    summary_builder=lambda data: (
                        f"Saved Future Twin snapshot {data.get('id', 'ready')}."
                    ),
                )
                if request.write_memory
                else DemoStep(
                    name="future_twin_snapshot",
                    title="Future Twin Snapshot Memory",
                    status="skipped",
                    summary="Future Twin snapshot writeback was disabled.",
                )
            )

        steps = [memory, reputation, *evidence_steps, twin_memory]
        return FutureTwinResponse(
            user_id=request.user_id,
            objective=objective,
            identity_summary=identity_summary,
            daily_question=daily_question,
            trajectory=trajectory,
            action=action,
            future_options=decision.future_options,
            evidence_signals=evidence_signals,
            opportunity_arbitrage=arbitrage,
            model_updates=model_updates,
            confidence_score=_future_twin_confidence(
                decision=decision,
                evidence_signals=evidence_signals,
                steps=steps,
            ),
            decision_report=decision,
            signals=[*decision.signals, *[_to_signal(step) for step in steps]],
            created_memory_id=_created_memory_id(twin_memory.data),
        )

    async def capture_proof(
        self,
        request: ProofCaptureRequest,
    ) -> ProofCaptureResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        user_id = str(request.user_id)
        objective = request.objective.strip()
        linked_goal = request.linked_goal.strip() or objective
        linked_action = request.linked_action.strip() or "Create proof that changes the Future Twin."
        memory_steps: list[DemoStep] = []
        reputation_steps: list[DemoStep] = []
        evidence_records: list[ProofEvidenceRecord] = []

        async with httpx.AsyncClient(timeout=8.0) as client:
            for evidence in request.evidence:
                impact_score = _evidence_impact_score(
                    evidence.evidence_type,
                    evidence.summary,
                    evidence.confidence,
                )
                memory_step = (
                    await _run_step(
                        client,
                        name="proof_memory",
                        title="Proof Memory Writeback",
                        base_url=routes["memory_system"],
                        path="/v1/memory/items",
                        payload={
                            "user_id": user_id,
                            "memory_type": _evidence_memory_type(evidence.evidence_type),
                            "title": _truncate(evidence.title, 180),
                            "summary": _truncate(evidence.summary, 900),
                            "content": _proof_memory_content(
                                objective=objective,
                                linked_goal=linked_goal,
                                linked_action=linked_action,
                                source_surface=request.source_surface,
                                evidence=evidence,
                                impact_score=impact_score,
                            ),
                            "source": "alter_proof_capture_os",
                            "confidence": evidence.confidence,
                            "importance": _proof_importance(impact_score),
                            "metadata": {
                                "objective": objective,
                                "linked_goal": linked_goal,
                                "linked_action": linked_action,
                                "evidence_type": evidence.evidence_type,
                                "source": evidence.source,
                                "source_surface": request.source_surface,
                                "impact_score": impact_score,
                                "url": evidence.url or "",
                            },
                        },
                        summary_builder=lambda data: (
                            f"Saved proof memory {data.get('id', 'ready')}."
                        ),
                    )
                    if request.write_memory
                    else DemoStep(
                        name="proof_memory",
                        title="Proof Memory Writeback",
                        status="skipped",
                        summary="Proof memory writeback was disabled.",
                    )
                )
                memory_steps.append(memory_step)
                reputation_step = (
                    await _run_step(
                        client,
                        name="proof_reputation",
                        title="Proof Reputation Event",
                        base_url=routes["reputation_engine"],
                        path="/v1/reputation/events",
                        payload={
                            "user_id": user_id,
                            "event_type": _proof_reputation_event_type(
                                evidence.evidence_type,
                                impact_score,
                            ),
                            "title": _truncate(evidence.title, 180),
                            "description": _truncate(evidence.summary, 800),
                            "impact_score": _proof_reputation_impact(impact_score),
                            "source": "alter_proof_capture_os",
                            "metadata": {
                                "objective": objective,
                                "linked_goal": linked_goal,
                                "linked_action": linked_action,
                                "evidence_type": evidence.evidence_type,
                                "impact_score": f"{impact_score:.1f}",
                            },
                        },
                        summary_builder=lambda data: (
                            f"Logged proof reputation event {data.get('id', 'ready')}."
                        ),
                    )
                    if request.update_reputation
                    else DemoStep(
                        name="proof_reputation",
                        title="Proof Reputation Event",
                        status="skipped",
                        summary="Proof reputation update was disabled.",
                    )
                )
                reputation_steps.append(reputation_step)
                evidence_records.append(
                    ProofEvidenceRecord(
                        evidence_type=evidence.evidence_type,
                        title=evidence.title,
                        summary=evidence.summary,
                        source=evidence.source,
                        linked_goal=linked_goal,
                        linked_action=linked_action,
                        impact_score=impact_score,
                        confidence=evidence.confidence,
                        trajectory_effect=_proof_trajectory_effect(
                            evidence.evidence_type,
                            impact_score,
                        ),
                        memory_id=_created_memory_id(memory_step.data),
                        reputation_event_id=_created_memory_id(reputation_step.data),
                    )
                )

            reputation = await _run_step(
                client,
                name="proof_trust_profile",
                title="Execution Trust Profile",
                base_url=routes["reputation_engine"],
                path=f"/v1/reputation/users/{user_id}/score",
                payload=None,
                summary_builder=lambda data: (
                    f"Trust profile is {data.get('trust_level', 'ready')} "
                    f"with score {data.get('score', 'baseline')}."
                ),
            )

        graph_nodes, graph_edges = _proof_graph(
            objective=objective,
            linked_goal=linked_goal,
            linked_action=linked_action,
            evidence_records=evidence_records,
        )
        trust_profile = _proof_trust_profile(evidence_records, reputation.data)
        future_delta = _proof_future_twin_delta(evidence_records, trust_profile)
        daily_briefing = _daily_proof_briefing(
            objective=objective,
            linked_goal=linked_goal,
            linked_action=linked_action,
            evidence_records=evidence_records,
            future_delta=future_delta,
        )
        graph_step = DemoStep(
            name="proof_graph",
            title="Proof Graph Compiler",
            status="ok",
            summary=(
                f"Built {len(graph_nodes)} proof node(s) and "
                f"{len(graph_edges)} trajectory edge(s)."
            ),
            data={
                "node_count": len(graph_nodes),
                "edge_count": len(graph_edges),
            },
        )
        briefing_step = DemoStep(
            name="daily_briefing",
            title="Daily Proof Briefing",
            status="ok",
            summary="Generated morning and evening proof prompts.",
            data={
                "recommended_proof": daily_briefing.recommended_proof,
                "drift_alert": daily_briefing.drift_alert,
            },
        )
        steps = [*memory_steps, *reputation_steps, reputation, graph_step, briefing_step]
        return ProofCaptureResponse(
            user_id=request.user_id,
            objective=objective,
            evidence_records=evidence_records,
            graph_nodes=graph_nodes,
            graph_edges=graph_edges,
            daily_briefing=daily_briefing,
            trust_profile=trust_profile,
            future_twin_delta=future_delta,
            next_actions=_proof_next_actions(
                linked_action=linked_action,
                daily_briefing=daily_briefing,
                evidence_records=evidence_records,
            ),
            signals=[_to_signal(step) for step in steps],
        )

    async def voice_action_runtime(
        self,
        request: VoiceActionRuntimeRequest,
    ) -> VoiceActionRuntimeResponse:
        routes = {route.name: route.base_url.rstrip("/") for route in self.routes()}
        user_id = str(request.user_id)

        async with httpx.AsyncClient(timeout=8.0) as client:
            voice = await _run_step(
                client,
                name="voice_gateway",
                title="Wake Word + Intent Runtime",
                base_url=routes["voice_gateway"],
                path="/v1/voice/session",
                payload={
                    "user_id": user_id,
                    "transcript": request.transcript,
                    "locale": request.locale,
                    "device_surface": request.device_surface,
                    "context": {
                        "runtime": "voice_action",
                        **{key: str(value) for key, value in request.context.items()},
                    },
                },
                summary_builder=lambda data: (
                    f"Intent={data.get('inferred_intent', 'unknown')} "
                    f"wake={data.get('wake_word_detected', False)}."
                ),
            )

        normalized = str(voice.data.get("normalized_text") or request.transcript).strip()
        intent = str(voice.data.get("inferred_intent") or "unknown")
        intent_confidence = _bounded_float(voice.data.get("confidence"), 0.42)
        decision: IntelligenceDecisionResponse | None = None
        memory_signal: DemoStep | None = None
        signals = [_to_signal(voice)]

        if intent in {
            "future_decision",
            "clone_council",
            "opportunity_search",
            "social_graph",
            "reputation",
            "unknown",
        }:
            decision = await self.decide(
                IntelligenceDecisionRequest(
                    user_id=request.user_id,
                    question=_voice_runtime_question(normalized, request.transcript, intent),
                    user_profile=request.user_profile,
                    skills=request.skills,
                    goals=request.goals,
                    interests=request.interests,
                    context={
                        **request.context,
                        "voice_intent": intent,
                        "locale": request.locale,
                        "device_surface": request.device_surface,
                        "wake_word_detected": voice.data.get("wake_word_detected", False),
                    },
                    decision_horizon_months=36,
                    write_memory=True,
                )
            )
            signals.extend(decision.signals)
        elif intent == "memory_capture":
            async with httpx.AsyncClient(timeout=8.0) as client:
                memory_signal = await _run_step(
                    client,
                    name="voice_memory_capture",
                    title="Voice Memory Capture",
                    base_url=routes["memory_system"],
                    path="/v1/memory/items",
                    payload={
                        "user_id": user_id,
                        "memory_type": "note",
                        "title": _truncate(normalized or request.transcript, 120),
                        "summary": _truncate(normalized or request.transcript, 900),
                        "content": request.transcript,
                        "source": "voice_action_runtime",
                        "confidence": 0.82,
                        "importance": 0.58,
                        "metadata": {
                            "locale": request.locale,
                            "voice_intent": intent,
                        },
                    },
                    summary_builder=lambda data: (
                        f"Saved voice memory {data.get('id', 'ready')}."
                    ),
                )
            signals.append(_to_signal(memory_signal))

        spoken_response = _voice_spoken_response(
            normalized=normalized,
            intent=intent,
            decision=decision,
            memory_signal=memory_signal,
        )
        display_response = _voice_display_response(spoken_response, decision, memory_signal)
        language = language_for_code(request.locale)
        ai_provider = "alter-local"
        source_language_code = str(voice.data.get("source_language_code") or "auto")
        if self._sarvam.enabled:
            try:
                sarvam = await self._sarvam.chat(
                    messages=[
                        {
                            "role": "user",
                            "content": _sarvam_voice_prompt(
                                transcript=request.transcript,
                                normalized=normalized,
                                intent=intent,
                                spoken_response=spoken_response,
                                display_response=display_response,
                                next_actions=decision.next_actions
                                if decision
                                else ["Review the saved memory."],
                            ),
                        }
                    ],
                    target_language_code=language.code,
                    temperature=0.28,
                    max_tokens=700,
                )
                if sarvam["text"]:
                    spoken_response = str(sarvam["text"])
                    display_response = str(sarvam["text"])
                    ai_provider = "sarvam"
                    signals.append(
                        IntelligenceSignal(
                            name="sarvam_multilingual",
                            title="Sarvam Multilingual AI",
                            status="ok",
                            summary=(
                                f"Generated {language.name} response with "
                                f"{sarvam.get('model', 'sarvam')}."
                            ),
                            latency_ms=None,
                            data={"language": language.code, "provider": "sarvam"},
                        )
                    )
            except Exception as error:
                signals.append(
                    IntelligenceSignal(
                        name="sarvam_multilingual",
                        title="Sarvam Multilingual AI",
                        status="degraded",
                        summary=f"Sarvam unavailable; used local fallback. {error}",
                        latency_ms=None,
                        data={"language": language.code, "provider": "alter-local"},
                    )
                )
        return VoiceActionRuntimeResponse(
            user_id=request.user_id,
            transcript=request.transcript,
            normalized_text=normalized,
            wake_word_detected=bool(voice.data.get("wake_word_detected", False)),
            inferred_intent=intent,
            intent_confidence=intent_confidence,
            spoken_response=spoken_response,
            display_response=display_response,
            ai_provider=ai_provider,
            source_language_code=source_language_code,
            response_language_code=language.code,
            language_display_name=language.name,
            action_graph=_voice_action_graph(intent, decision, memory_signal),
            experiment_plan=decision.experiment_plan if decision else None,
            next_actions=decision.next_actions if decision else ["Review the saved memory."],
            follow_up_questions=_voice_follow_up_questions(intent, decision),
            decision_report=decision,
            signals=signals,
        )


def create_api_gateway_service(settings: Settings | None = None) -> ApiGatewayService:
    return ApiGatewayService(settings or get_settings())


def _local_multilingual_fallback(text: str, language_name: str) -> str:
    return (
        f"ALTER understood your request and is ready to act. "
        f"Sarvam is not available right now, so this fallback is in English; "
        f"target language: {language_name}. Request: {_truncate(text, 180)}"
    )


def _infer_language_code(text: str) -> str:
    value = text or ""
    if any("\u0900" <= char <= "\u097f" for char in value):
        return "hi-IN"
    if any("\u0980" <= char <= "\u09ff" for char in value):
        return "bn-IN"
    if any("\u0c80" <= char <= "\u0cff" for char in value):
        return "kn-IN"
    if any("\u0d00" <= char <= "\u0d7f" for char in value):
        return "ml-IN"
    if any("\u0b80" <= char <= "\u0bff" for char in value):
        return "ta-IN"
    if any("\u0c00" <= char <= "\u0c7f" for char in value):
        return "te-IN"
    return "en-IN"


def _ingestion_blockers(request: DataIngestionRequest) -> list[str]:
    blockers: list[str] = []
    blocked_modes = {"silent_scrape", "full_phone_scrape", "background_chat_scrape"}
    if request.import_mode.lower() in blocked_modes:
        blockers.append("Silent full-phone or chat scraping is not allowed.")
    if not request.metadata_only and request.consent_id is None:
        blockers.append("Raw content import requires an explicit consent_id.")
    if not request.items:
        blockers.append("No import items were provided.")
    return blockers


def _memory_candidates_from_items(
    items: list[dict[str, Any]],
    source: str,
) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for index, item in enumerate(items[:50], start=1):
        title = str(item.get("title") or item.get("name") or f"{source} item {index}")
        summary = str(item.get("summary") or item.get("text") or item.get("content") or "")
        candidates.append(
            {
                "title": _truncate(title, 120),
                "summary": _truncate(summary or title, 500),
                "source": source,
                "confidence": 0.72,
                "privacy": "agent_visible",
                "metadata": {
                    key: value
                    for key, value in item.items()
                    if key not in {"content", "text", "summary"}
                },
            }
        )
    return candidates


_CONTEXT_SOURCES = {"local", "cloud", "user-entered", "inferred", "imported"}


def _build_context_pack(request: AgentPlannerRequest) -> list[ContextItem]:
    """Merge client-provided (on-device) context with backend-derived context
    into one decision pack, tagged by source and de-duplicated. Backwards
    compatible: an empty client_context yields just the backend-derived items.
    """
    pack: list[ContextItem] = []
    seen: set[str] = set()

    def add(source: str, text: str) -> None:
        clean = " ".join(text.split())[:2000]
        if not clean:
            return
        label = source if source in _CONTEXT_SOURCES else "local"
        key = f"{label}|{clean.lower()}"
        if key in seen:
            return
        seen.add(key)
        pack.append(ContextItem(source=label, text=clean))

    # Local context the phone sent up (keeps its own source labels).
    for item in request.client_context:
        add(item.source, item.text)

    # Backend-derived context for this decision.
    add("inferred", f"Goal under consideration: {request.goal}")
    if request.device_state:
        keys = ", ".join(sorted(str(k) for k in request.device_state)[:8])
        add("local", f"Device signals present: {keys}")

    return pack[:40]


def _planner_steps(request: AgentPlannerRequest) -> tuple[list[AgentPlanStep], list[str]]:
    goal = request.goal.lower()
    allowed = {tool.lower() for tool in request.allowed_tools}
    steps: list[AgentPlanStep] = []
    warnings = [
        "Risky actions require confirmation before execution.",
        "Android Accessibility can only act on visible UI after the user enables the service.",
        "ALTER will not bypass passwords, banking confirmations, or Android permission dialogs.",
    ]

    def allowed_tool(name: str) -> bool:
        return not allowed or name.lower() in allowed

    if any(word in goal for word in ["open", "launch", "settings", "app"]):
        steps.append(
            AgentPlanStep(
                tool_name="device_action.open_intent",
                title="Open the target app or Android settings surface",
                rationale="Use Android intents before falling back to Accessibility.",
                parameters={"query": request.goal},
                requires_confirmation=False,
                status="ready" if allowed_tool("device_action.open_intent") else "blocked",
                blocked_reason=(
                    "" if allowed_tool("device_action.open_intent") else "Tool is not allowed."
                ),
            )
        )
    if any(word in goal for word in ["tap", "scroll", "type", "reply", "send", "whatsapp"]):
        steps.append(
            AgentPlanStep(
                tool_name="openclaw.accessibility_action",
                title="Queue visible-screen control action",
                rationale="Accessibility is required for tapping, scrolling, typing, and visible text reads.",
                parameters={"instruction": request.goal, "source": "agent_planner"},
                requires_confirmation=True,
                requires_accessibility=True,
                status="ready" if allowed_tool("openclaw.accessibility_action") else "blocked",
                blocked_reason=(
                    ""
                    if allowed_tool("openclaw.accessibility_action")
                    else "Tool is not allowed."
                ),
            )
        )
    if any(word in goal for word in ["sms", "call", "message", "email"]):
        steps.append(
            AgentPlanStep(
                tool_name="device_action.compose",
                title="Prepare a draft instead of silently sending",
                rationale="Communication actions should be reviewed by the user before send.",
                parameters={"intent": request.goal, "send_immediately": False},
                requires_confirmation=True,
                status="ready" if allowed_tool("device_action.compose") else "blocked",
                blocked_reason="" if allowed_tool("device_action.compose") else "Tool is not allowed.",
            )
        )
    if not steps:
        steps.append(
            AgentPlanStep(
                tool_name="assistant.respond",
                title="Answer and ask for the missing target",
                rationale="No safe device action was detected from the goal.",
                parameters={"goal": request.goal},
                requires_confirmation=False,
                status="ready",
            )
        )
    if "bypass" in goal or "password" in goal:
        warnings.append("Bypass/password requests are blocked by policy and Android security.")
        for step in steps:
            step.status = "blocked"
            step.blocked_reason = "Request asks for bypassing security or credentials."
    return steps, warnings


def _sarvam_voice_prompt(
    *,
    transcript: str,
    normalized: str,
    intent: str,
    spoken_response: str,
    display_response: str,
    next_actions: list[str],
) -> str:
    return (
        "Turn this ALTER Android intelligence result into a natural spoken answer. "
        "Keep it to 2-4 short sentences. Mention the concrete next action. "
        "Do not claim silent access to chats, permissions, banking, passwords, or system controls. "
        f"Original transcript: {transcript}\n"
        f"Normalized command: {normalized}\n"
        f"Intent: {intent}\n"
        f"Base spoken response: {spoken_response}\n"
        f"Base display response: {display_response}\n"
        f"Next actions: {'; '.join(next_actions[:4])}"
    )


async def _run_step(
    client: httpx.AsyncClient,
    *,
    name: str,
    title: str,
    base_url: str,
    path: str,
    payload: dict[str, Any] | None,
    summary_builder: Any,
) -> DemoStep:
    started = time.perf_counter()
    try:
        if payload is None:
            response = await client.get(f"{base_url}{path}")
        else:
            response = await client.post(f"{base_url}{path}", json=payload)
        latency_ms = int((time.perf_counter() - started) * 1000)
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            data = {"value": data}
        return DemoStep(
            name=name,
            title=title,
            status="ok",
            summary=str(summary_builder(data)),
            latency_ms=latency_ms,
            data=data,
        )
    except Exception as error:  # noqa: BLE001 - orchestration should degrade gracefully
        latency_ms = int((time.perf_counter() - started) * 1000)
        return DemoStep(
            name=name,
            title=title,
            status="error",
            summary=f"{title} unavailable: {error}",
            latency_ms=latency_ms,
            data={},
        )


async def _run_memory_step(
    client: httpx.AsyncClient,
    base_url: str,
    user_id: str,
    objective: str,
) -> DemoStep:
    started = time.perf_counter()
    try:
        create_response = await client.post(
            f"{base_url}/v1/memory/items",
            json={
                "user_id": user_id,
                "memory_type": "decision",
                "title": "Decision loop",
                "summary": objective,
                "content": (
                    f"ALTER ran an end-to-end future operating system loop for: {objective}"
                ),
                "source": "mission_control",
                "confidence": _objective_confidence(objective),
                "importance": _objective_importance(objective),
            },
        )
        create_response.raise_for_status()
        search_response = await client.post(
            f"{base_url}/v1/memory/search",
            json={
                "user_id": user_id,
                "query": objective,
                "limit": 5,
            },
        )
        latency_ms = int((time.perf_counter() - started) * 1000)
        search_response.raise_for_status()
        created = create_response.json()
        search = search_response.json()
        return DemoStep(
            name="memory_system",
            title="Personal Memory Graph",
            status="ok",
            summary=f"Stored decision memory and retrieved {len(search.get('hits', []))} related item(s).",
            latency_ms=latency_ms,
            data={"created": created, "search": search},
        )
    except Exception as error:  # noqa: BLE001
        latency_ms = int((time.perf_counter() - started) * 1000)
        return DemoStep(
            name="memory_system",
            title="Personal Memory Graph",
            status="error",
            summary=f"Memory unavailable: {error}",
            latency_ms=latency_ms,
        )


def _objective_confidence(objective: str) -> float:
    token_count = len([token for token in objective.split() if token.strip()])
    return round(min(0.82, 0.42 + token_count * 0.025), 2)


def _objective_importance(objective: str) -> float:
    clean_length = len(objective.strip())
    return round(min(0.86, 0.48 + clean_length / 900), 2)


async def _run_social_step(
    client: httpx.AsyncClient,
    base_url: str,
    request: DemoRunRequest,
) -> DemoStep:
    started = time.perf_counter()
    profile = request.profile
    name = str(
        profile.get("display_name")
        or profile.get("displayName")
        or profile.get("name")
        or ""
    ).strip()
    role = str(profile.get("role") or profile.get("current_role") or "").strip()
    skills = _coerce_string_list(profile.get("skills"))
    interests = _coerce_string_list(profile.get("interests"))
    if not any([name, role, skills, interests]):
        return DemoStep(
            name="social_graph",
            title="Social Graph Route",
            status="skipped",
            summary=(
                "No profile or contact data was provided, so social graph writes were skipped."
            ),
            latency_ms=0,
            data={},
        )
    try:
        user_response = await client.post(
            f"{base_url}/v1/social-graph/people",
            json={
                "role": role or "User",
                "name": name or "User",
                "skills": skills,
                "interests": interests,
            },
        )
        latency_ms = int((time.perf_counter() - started) * 1000)
        user_response.raise_for_status()
        user = user_response.json()
        return DemoStep(
            name="social_graph",
            title="Social Graph Route",
            status="ok",
            summary="Updated the social graph profile node from provided profile data.",
            latency_ms=latency_ms,
            data={"user": user},
        )
    except Exception as error:  # noqa: BLE001
        latency_ms = int((time.perf_counter() - started) * 1000)
        return DemoStep(
            name="social_graph",
            title="Social Graph Route",
            status="error",
            summary=f"Social graph unavailable: {error}",
            latency_ms=latency_ms,
        )


def _future_payload(request: DemoRunRequest) -> dict[str, Any]:
    profile = request.profile
    current_role = str(profile.get("current_role") or profile.get("role") or "")
    skills = _coerce_string_list(profile.get("skills"))
    interests = _coerce_string_list(profile.get("interests"))
    user_profile: dict[str, Any] = {
        "name": profile.get("name") or "",
        "current_role": current_role,
    }
    if profile.get("current_salary") is not None:
        user_profile["current_salary"] = float(profile.get("current_salary") or 0)
    if profile.get("current_network_size") is not None:
        user_profile["current_network_size"] = int(profile.get("current_network_size") or 0)
    if profile.get("risk_tolerance") is not None:
        user_profile["risk_tolerance"] = float(profile.get("risk_tolerance") or 0)
    if profile.get("weekly_learning_hours") is not None:
        user_profile["weekly_learning_hours"] = int(profile.get("weekly_learning_hours") or 0)
    currency = str(profile.get("currency") or "").upper()[:3] or None
    return {
        "user_profile": user_profile,
        "skills": [
            {"name": skill, "category": _skill_category(skill), "level": 0.5, "years": 0}
            for skill in skills[:12]
        ],
        "goals": [
            {
                "title": request.objective,
                "category": _goal_category(request.objective),
                "horizon_months": 24,
                "priority": 5,
            }
        ],
        "experience": [],
        "interests": interests,
        "horizon_months": 36,
        "currency": currency,
    }


def _opportunity_payload(request: DemoRunRequest) -> dict[str, Any]:
    profile = request.profile
    opportunity_profile: dict[str, Any] = {
        "career_stage": str(profile.get("career_stage") or ""),
        "skills": _coerce_string_list(profile.get("skills")),
        "goals": _dedupe_strings([*_coerce_string_list(profile.get("goals")), request.objective]),
        "interests": _coerce_string_list(profile.get("interests")),
        "preferred_categories": _coerce_string_list(profile.get("preferred_categories")),
    }
    if profile.get("risk_tolerance") is not None:
        opportunity_profile["risk_tolerance"] = _bounded_float(profile.get("risk_tolerance"), 0)
    return {
        "profile": opportunity_profile,
        "crawl": {
            "sources": ["devpost", "startup_grants", "yc"],
            "query": request.objective,
            "limit_per_source": 1,
        },
        "limit": 3,
    }


def _decision_future_payload(request: IntelligenceDecisionRequest) -> dict[str, Any]:
    profile = request.user_profile
    role = str(profile.get("current_role") or profile.get("role") or "")
    user_profile: dict[str, Any] = {
        "name": profile.get("name") or "",
        "current_role": role,
        "location": profile.get("location"),
        "industry": profile.get("industry") or "",
    }
    if profile.get("current_salary") is not None:
        user_profile["current_salary"] = _safe_float(profile.get("current_salary"), 0)
    if profile.get("current_network_size") is not None:
        user_profile["current_network_size"] = int(
            _safe_float(profile.get("current_network_size"), 0)
        )
    if profile.get("risk_tolerance") is not None:
        user_profile["risk_tolerance"] = _bounded_float(profile.get("risk_tolerance"), 0)
    if profile.get("weekly_learning_hours") is not None:
        user_profile["weekly_learning_hours"] = int(
            _safe_float(profile.get("weekly_learning_hours"), 0)
        )
    skills = _dedupe_strings(
        [
            *request.skills,
            *_coerce_string_list(profile.get("skills")),
        ]
    )
    goals = _dedupe_strings([*request.goals, request.question])
    interests = _dedupe_strings(
        [
            *request.interests,
            *_coerce_string_list(profile.get("interests")),
            *_coerce_string_list(request.context.get("interests")),
        ]
    )

    return {
        "user_profile": user_profile,
        "skills": [
            {
                "name": skill,
                "category": _skill_category(skill),
                "level": round(max(0.54, 0.82 - index * 0.035), 2),
                "years": round(max(0.5, 2.5 - index * 0.1), 1),
            }
            for index, skill in enumerate(skills[:12])
        ],
        "goals": [
            {
                "title": goal,
                "category": _goal_category(goal),
                "horizon_months": request.decision_horizon_months,
                "priority": 5 if index == 0 else 4,
            }
            for index, goal in enumerate(goals[:6])
        ],
        "experience": _decision_experience(request),
        "interests": interests[:20],
        "horizon_months": request.decision_horizon_months,
        "currency": str(profile.get("currency") or "USD").upper()[:3],
    }


def _decision_opportunity_payload(request: IntelligenceDecisionRequest) -> dict[str, Any]:
    profile = request.user_profile
    skills = _dedupe_strings([*request.skills, *_coerce_string_list(profile.get("skills"))])
    goals = _dedupe_strings([*request.goals, request.question])
    interests = _dedupe_strings([*request.interests, *_coerce_string_list(profile.get("interests"))])
    opportunity_profile: dict[str, Any] = {
        "user_id": str(request.user_id),
        "career_stage": str(profile.get("career_stage") or ""),
        "skills": skills,
        "goals": goals[:12],
        "interests": interests,
        "preferred_locations": _coerce_string_list(profile.get("preferred_locations")),
        "preferred_categories": [
            "hackathon",
            "grant",
            "accelerator",
            "research",
            "program",
        ],
    }
    if profile.get("risk_tolerance") is not None:
        opportunity_profile["risk_tolerance"] = _bounded_float(
            profile.get("risk_tolerance"),
            0,
        )
    return {
        "profile": opportunity_profile,
        "crawl": {
            "sources": [
                "devpost",
                "startup_grants",
                "yc",
                "google_programs",
                "research_fellowships",
            ],
            "query": request.question,
            "limit_per_source": 1,
        },
        "limit": 5,
    }


def _decision_experience(request: IntelligenceDecisionRequest) -> list[dict[str, Any]]:
    if request.experience:
        normalized = []
        for item in request.experience[:10]:
            title = str(item.get("title") or item.get("name") or "Relevant experience")
            normalized.append(
                {
                    "title": _truncate(title, 160),
                    "organization": item.get("organization"),
                    "domain": item.get("domain"),
                    "years": _safe_float(item.get("years"), 1.0),
                    "impact": item.get("impact") or item.get("summary"),
                }
            )
        return normalized
    return []


def _future_options(data: dict[str, Any]) -> list[FutureOption]:
    raw_futures = data.get("futures", [])
    if not isinstance(raw_futures, list):
        return []
    options = []
    for index, item in enumerate(raw_futures[:3]):
        if not isinstance(item, dict):
            continue
        future_id = str(item.get("future_id") or f"Future {index + 1}")
        name = str(item.get("name") or future_id)
        options.append(
            FutureOption(
                future_id=future_id,
                name=name,
                thesis=str(item.get("thesis") or "No thesis returned."),
                success_probability=_bounded_float(item.get("success_probability"), 0.0),
                opportunity_score=_bounded_score(item.get("opportunity_score")),
                risk_score=_bounded_score(item.get("risk_score")),
            )
        )
    return options


def _memory_context(data: dict[str, Any]) -> list[str]:
    context = data.get("context", [])
    if not isinstance(context, list):
        return []
    blocks = []
    for item in context[:6]:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or "Memory")
        summary = str(item.get("summary") or item.get("content") or "")
        if summary:
            blocks.append(_truncate(f"{title}: {summary}", 280))
    return blocks


def _opportunity_titles(data: dict[str, Any]) -> list[str]:
    recommendations = data.get("recommendations", {}).get("recommendations", [])
    if not isinstance(recommendations, list):
        return []
    titles = []
    for item in recommendations[:5]:
        if not isinstance(item, dict):
            continue
        opportunity = item.get("opportunity", {})
        if not isinstance(opportunity, dict):
            continue
        title = str(opportunity.get("title") or "Opportunity")
        organization = str(opportunity.get("organization") or "").strip()
        score = item.get("score")
        suffix = f" at {organization}" if organization and organization != "Unknown" else ""
        score_text = f" ({round(float(score), 1)})" if isinstance(score, (int, float)) else ""
        titles.append(_truncate(f"{title}{suffix}{score_text}", 220))
    return titles


def _decision_recommendation(
    council_data: dict[str, Any],
    future_data: dict[str, Any],
) -> str:
    recommendation = council_data.get("final_recommendation")
    if isinstance(recommendation, str) and recommendation.strip():
        return recommendation.strip()
    summary = future_data.get("summary", {})
    if isinstance(summary, dict):
        fallback = summary.get("recommendation")
        if isinstance(fallback, str) and fallback.strip():
            return fallback.strip()
    return (
        "Run a two-week evidence sprint: validate the highest-risk assumption, "
        "talk to real users or mentors, and rerun ALTER with the new signal."
    )


def _decision_confidence(
    council_data: dict[str, Any],
    future_options: list[FutureOption],
    opportunity_matches: list[str],
    steps: list[DemoStep],
) -> float:
    council_confidence = _bounded_float(council_data.get("confidence_score"), 0.62)
    best_future = max(
        (option.success_probability for option in future_options),
        default=0.55,
    )
    health = sum(1 for step in steps if step.status == "ok") / max(len(steps), 1)
    opportunity_signal = min(len(opportunity_matches), 5) / 5
    score = (
        council_confidence * 0.62
        + best_future * 0.18
        + health * 0.14
        + opportunity_signal * 0.06
    )
    return round(max(0.05, min(0.97, score)), 2)


def _recommended_future(
    future_data: dict[str, Any],
    future_options: list[FutureOption],
) -> str:
    summary = future_data.get("summary", {})
    if isinstance(summary, dict):
        best = summary.get("best_expected_value_future")
        if isinstance(best, str) and best.strip():
            return best
    if not future_options:
        return "Evidence Sprint"
    best_option = max(
        future_options,
        key=lambda option: option.success_probability * option.opportunity_score
        - option.risk_score * 0.25,
    )
    return best_option.future_id


def _decision_summary(
    *,
    question: str,
    recommended_future: str,
    memory_context: list[str],
    opportunity_matches: list[str],
    steps: list[DemoStep],
) -> str:
    ok_count = sum(1 for step in steps if step.status == "ok")
    return (
        f"ALTER evaluated '{question}' through {ok_count}/{len(steps)} live systems, "
        f"used {len(memory_context)} memory signal(s), compared future paths, and found "
        f"{len(opportunity_matches)} opportunity match(es). Recommended path: "
        f"{recommended_future}."
    )


def _decision_artifact_content(
    *,
    question: str,
    future_options: list[FutureOption],
    opportunity_matches: list[str],
    memory_context: list[str],
) -> str:
    future_lines = [
        f"{option.future_id}: {option.name} "
        f"(success {round(option.success_probability * 100)}%, "
        f"opportunity {round(option.opportunity_score)}, risk {round(option.risk_score)})"
        for option in future_options
    ]
    return "\n".join(
        [
            f"Question: {question}",
            "Futures:",
            *(future_lines or ["No futures returned."]),
            "Opportunity matches:",
            *(opportunity_matches or ["No opportunities returned."]),
            "Memory context:",
            *(memory_context or ["No relevant memories found."]),
        ]
    )


def _memory_writeback_content(
    *,
    question: str,
    recommendation: str,
    actions: list[str],
    risks: list[str],
    opportunities: list[str],
) -> str:
    return "\n".join(
        [
            f"Question: {question}",
            f"Recommendation: {recommendation}",
            "Next actions:",
            *(actions or ["Run one validation step."]),
            "Risks:",
            *(risks or ["Acting without enough fresh evidence."]),
            "Opportunities:",
            *(opportunities or ["Create a public proof point."]),
        ]
    )


def _experiment_plan(
    *,
    question: str,
    recommendation: str,
    actions: list[str],
    opportunities: list[str],
    future_options: list[FutureOption],
) -> ExperimentPlan:
    action = actions[0] if actions else "Run one validation step within seven days."
    opportunity = opportunities[0] if opportunities else "create a proof point with real users"
    best_future = max(
        future_options,
        key=lambda option: option.opportunity_score * option.success_probability
        - option.risk_score * 0.2,
        default=None,
    )
    future_name = best_future.name if best_future else "the recommended future"
    deadline = (datetime.now(UTC) + timedelta(days=7)).date().isoformat()
    return ExperimentPlan(
        action=_truncate(action, 280),
        why_it_matters=_truncate(
            f"This tests whether '{question}' deserves more commitment. "
            f"It connects the recommendation to {future_name} and turns "
            f"{opportunity} into observable evidence.",
            600,
        ),
        deadline=deadline,
        success_metric=_truncate(
            "Create one concrete evidence artifact: 5 user conversations, "
            "1 shipped prototype improvement, 1 application/submission, or "
            "1 warm intro that changes the decision.",
            280,
        ),
    )


def _execution_score(request: OutcomeUpdateRequest) -> float:
    completion = 0.55 if request.did_it else 0.12
    result_quality = request.outcome_score * 0.35
    reflection_quality = min(
        (len(request.what_happened.strip()) + len(request.what_learned.strip())) / 500,
        1.0,
    ) * 0.10
    return round((completion + result_quality + reflection_quality) * 100, 1)


def _confidence_delta(request: OutcomeUpdateRequest) -> float:
    if request.did_it:
        return round(0.03 + request.outcome_score * 0.12, 2)
    return round(-0.12 + request.outcome_score * 0.04, 2)


def _reputation_impact_score(request: OutcomeUpdateRequest) -> int:
    if request.did_it:
        return int(round(18 + request.outcome_score * 34))
    return int(round(-18 + request.outcome_score * 8))


def _outcome_importance(request: OutcomeUpdateRequest) -> float:
    base = 0.62 if request.did_it else 0.5
    return round(max(0.2, min(0.95, base + request.outcome_score * 0.22)), 2)


def _outcome_summary(
    request: OutcomeUpdateRequest,
    execution_score: float,
    confidence_delta: float,
) -> str:
    status = "completed" if request.did_it else "not completed"
    direction = "increased" if confidence_delta >= 0 else "reduced"
    return (
        f"Experiment '{request.experiment_plan.action}' was {status}. "
        f"Execution score {execution_score:.1f}/100. Outcome signal {request.outcome_score:.0%} "
        f"{direction} confidence by {abs(confidence_delta):.0%}."
    )


def _outcome_memory_content(
    request: OutcomeUpdateRequest,
    *,
    execution_score: float,
    confidence_delta: float,
) -> str:
    return "\n".join(
        [
            f"Decision: {request.question}",
            f"Experiment: {request.experiment_plan.action}",
            f"Why it mattered: {request.experiment_plan.why_it_matters}",
            f"Deadline: {request.experiment_plan.deadline}",
            f"Success metric: {request.experiment_plan.success_metric}",
            f"Did it: {request.did_it}",
            f"What happened: {request.what_happened}",
            f"What was learned: {request.what_learned}",
            f"Metric result: {request.success_metric_result}",
            f"Outcome score: {request.outcome_score:.2f}",
            f"Execution score: {execution_score:.1f}",
            f"Confidence delta: {confidence_delta:.2f}",
        ]
    )


def _profile_updates(
    request: OutcomeUpdateRequest,
    execution_score: float,
    confidence_delta: float,
) -> list[str]:
    updates = [
        f"Execution reliability signal: {execution_score:.1f}/100.",
        f"Confidence model adjustment: {confidence_delta:+.2f}.",
    ]
    if request.did_it and request.outcome_score >= 0.7:
        updates.append("User profile should weight fast validation and follow-through higher.")
    elif request.did_it:
        updates.append("User profile should weight execution as present but market signal as mixed.")
    else:
        updates.append("User profile should prefer smaller commitments until follow-through improves.")
    updates.append("Future simulations should use this outcome memory as real-world evidence.")
    return updates


def _outcome_next_recommendation(
    request: OutcomeUpdateRequest,
    execution_score: float,
) -> str:
    if request.did_it and request.outcome_score >= 0.75:
        return (
            "Double down for one more sprint: raise the bar, talk to higher-quality users, "
            "and convert the strongest signal into a public proof point."
        )
    if request.did_it:
        return (
            "Keep the direction, but tighten the success metric and run a smaller follow-up "
            "experiment before making a bigger commitment."
        )
    if execution_score < 35:
        return (
            "Shrink the commitment: pick a 30-minute action today so ALTER can rebuild "
            "execution signal from reality instead of intention."
        )
    return "Rerun the decision with this outcome and choose a lower-friction next action."


def _evidence_memory_type(evidence_type: str) -> str:
    text = evidence_type.lower()
    if any(token in text for token in ("project", "artifact", "prototype", "github", "deck")):
        return "project"
    if any(token in text for token in ("conversation", "interview", "meeting", "call")):
        return "conversation"
    if any(token in text for token in ("opportunity", "application", "program")):
        return "opportunity"
    if "skill" in text:
        return "skill"
    if "goal" in text:
        return "goal"
    return "note"


def _evidence_importance(evidence_type: str) -> float:
    text = evidence_type.lower()
    if any(token in text for token in ("user", "customer", "interview", "revenue")):
        return 0.9
    if any(token in text for token in ("prototype", "github", "deck", "application")):
        return 0.82
    if any(token in text for token in ("mentor", "investor", "intro")):
        return 0.78
    return 0.66


def _evidence_memory_content(objective: str, evidence: Any) -> str:
    lines = [
        f"Objective: {objective}",
        f"Evidence type: {evidence.evidence_type}",
        f"Title: {evidence.title}",
        f"Source: {evidence.source}",
        f"Confidence: {evidence.confidence:.2f}",
        f"Summary: {evidence.summary}",
    ]
    if evidence.url:
        lines.append(f"URL: {evidence.url}")
    return "\n".join(lines)


def _future_twin_evidence_signals(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    memory_data: dict[str, Any],
    evidence_steps: list[DemoStep],
) -> list[EvidenceSignal]:
    signals: list[EvidenceSignal] = []
    for index, evidence in enumerate(request.recent_evidence):
        step = evidence_steps[index] if index < len(evidence_steps) else None
        signals.append(
            EvidenceSignal(
                evidence_type=evidence.evidence_type,
                title=_truncate(evidence.title, 180),
                source=evidence.source,
                impact_score=_evidence_impact_score(
                    evidence.evidence_type,
                    evidence.summary,
                    evidence.confidence,
                ),
                confidence=evidence.confidence,
                memory_id=_created_memory_id(step.data) if step else None,
                summary=_truncate(evidence.summary, 300),
            )
        )

    context = memory_data.get("context", [])
    if isinstance(context, list):
        for item in context[:3]:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or "Memory signal")
            summary = str(item.get("summary") or item.get("content") or "")
            confidence = _bounded_float(item.get("confidence"), 0.68)
            importance = _bounded_float(item.get("importance"), 0.62)
            signals.append(
                EvidenceSignal(
                    evidence_type=str(item.get("memory_type") or "memory"),
                    title=_truncate(title, 180),
                    source="memory_graph",
                    impact_score=round((confidence * 45) + (importance * 45), 1),
                    confidence=confidence,
                    memory_id=item.get("memory_id"),
                    summary=_truncate(summary or title, 300),
                )
            )

    if decision.opportunity_matches:
        signals.append(
            EvidenceSignal(
                evidence_type="opportunity_pull",
                title="Opportunity pull detected",
                source="opportunity_radar",
                impact_score=min(92.0, 52.0 + len(decision.opportunity_matches) * 8.0),
                confidence=0.78,
                summary=_truncate(
                    "ALTER found external opportunity pressure: "
                    + "; ".join(decision.opportunity_matches[:3]),
                    300,
                ),
            )
        )

    if not signals:
        signals.append(
            EvidenceSignal(
                evidence_type="stated_intent",
                title="Stated objective",
                source="future_twin",
                impact_score=_evidence_impact_score(
                    "stated_intent",
                    decision.question,
                    0.45,
                ),
                confidence=0.45,
                summary=(
                    "ALTER only has the stated objective so far. Add proof, imported "
                    "memory, or outcome data to increase confidence."
                ),
            )
        )
    return signals[:8]


def _evidence_impact_score(
    evidence_type: str,
    summary: str,
    confidence: float,
) -> float:
    text = f"{evidence_type} {summary}".lower()
    base = 32.0 + confidence * 38.0
    if any(token in text for token in ("paid", "revenue", "accepted", "shipped", "launched")):
        base += 18
    if any(token in text for token in ("user", "customer", "interview", "beta")):
        base += 12
    if any(token in text for token in ("github", "prototype", "artifact", "deck")):
        base += 9
    if any(token in text for token in ("maybe", "planned", "thinking")):
        base -= 10
    return round(max(5.0, min(100.0, base)), 1)


def _future_twin_trajectory(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    evidence_signals: list[EvidenceSignal],
    reputation_data: dict[str, Any],
) -> FutureTwinTrajectory:
    best_future = _best_future_option(decision.future_options)
    average_risk = sum(option.risk_score for option in decision.future_options) / max(
        len(decision.future_options),
        1,
    )
    evidence_strength = _average_evidence_strength(evidence_signals)
    reputation_score = _safe_float(reputation_data.get("score"), 600.0) / 10.0
    event_bonus = min(_safe_float(reputation_data.get("event_count"), 0.0) * 3.0, 12.0)
    opportunity_pull = min(len(decision.opportunity_matches) * 6.0, 24.0)
    best_success = (best_future.success_probability * 100.0) if best_future else 55.0
    alignment = _bounded_score(
        decision.confidence_score * 38.0
        + best_success * 0.22
        + evidence_strength * 0.24
        + opportunity_pull * 0.45
        + min(len(request.goals), 5) * 2.2
    )
    execution_velocity = _bounded_score(
        reputation_score * 0.62
        + evidence_strength * 0.28
        + event_bonus
        + min(len(request.recent_evidence), 5) * 3.0
    )
    drift_risk = _bounded_score(
        100.0
        - alignment * 0.52
        - execution_velocity * 0.36
        + average_risk * 0.22
    )

    if drift_risk >= 62:
        current = "High ambition, insufficient proof"
        predicted = (
            "In 90 days, the idea remains emotionally compelling but still under-validated "
            "unless proof artifacts increase."
        )
    elif execution_velocity >= 68:
        current = "Evidence-compounding builder path"
        predicted = (
            "In 90 days, the user has a sharper market thesis, visible proof, and stronger "
            "follow-through reputation."
        )
    else:
        current = "Promising but proof-constrained path"
        predicted = (
            "In 90 days, the objective advances if the next action creates external evidence "
            "instead of more internal planning."
        )

    best_label = best_future.name if best_future else decision.recommended_future
    return FutureTwinTrajectory(
        current_trajectory=current,
        predicted_90_day_future=predicted,
        best_alternative_future=best_label,
        alignment_score=round(alignment, 1),
        execution_velocity=round(execution_velocity, 1),
        drift_risk=round(drift_risk, 1),
        points=[
            _trajectory_point("Skill", evidence_strength * 0.55 + 26, alignment, 92),
            _trajectory_point("Execution", execution_velocity, execution_velocity + 12, 94),
            _trajectory_point("Network", 46 + opportunity_pull, 58 + opportunity_pull, 90),
            _trajectory_point("Opportunity", 44 + opportunity_pull, 62 + opportunity_pull, 96),
            _trajectory_point("Reputation", reputation_score, reputation_score + 10, 88),
        ],
    )


def _trajectory_point(
    label: str,
    current: float,
    predicted: float,
    best_case: float,
) -> TrajectoryPoint:
    return TrajectoryPoint(
        label=label,
        current_score=round(_bounded_score(current), 1),
        predicted_score=round(_bounded_score(predicted), 1),
        best_case_score=round(_bounded_score(best_case), 1),
    )


def _compiled_action(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    trajectory: FutureTwinTrajectory,
    evidence_signals: list[EvidenceSignal],
) -> CompiledAction:
    plan = decision.experiment_plan
    proof_required = _proof_requirements(decision, evidence_signals)
    first_step = decision.next_actions[0] if decision.next_actions else plan.action
    leverage = _bounded_score(
        44.0
        + trajectory.drift_risk * 0.22
        + trajectory.alignment_score * 0.24
        + min(len(decision.opportunity_matches), 5) * 4.0
    )
    return CompiledAction(
        title=plan.action,
        why_now=_truncate(
            "This is the smallest action that can move ALTER from intention to evidence. "
            f"It attacks trajectory risk '{trajectory.current_trajectory}' for: "
            f"{request.objective}",
            600,
        ),
        deadline=plan.deadline,
        success_metric=plan.success_metric,
        proof_required=proof_required,
        first_step=_truncate(first_step, 240),
        leverage_score=round(leverage, 1),
    )


def _proof_requirements(
    decision: IntelligenceDecisionResponse,
    evidence_signals: list[EvidenceSignal],
) -> list[str]:
    proofs = [
        "5 real user or mentor conversations with notes.",
        "1 public artifact URL: demo, deck, GitHub commit, memo, or waitlist.",
        "1 outcome update saved back into ALTER memory.",
    ]
    if decision.opportunity_matches:
        proofs.insert(2, "1 submitted application, warm intro, or opportunity response.")
    if any(signal.impact_score >= 80 for signal in evidence_signals):
        proofs.append("1 follow-up that converts the strongest proof into a repeatable loop.")
    return proofs[:5]


def _opportunity_arbitrage(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    trajectory: FutureTwinTrajectory,
    action: CompiledAction,
) -> list[OpportunityArbitrageMove]:
    refs = decision.opportunity_matches[:5]
    top_ref = refs[0] if refs else "the highest-signal public proof channel"
    moves = [
        OpportunityArbitrageMove(
            title="Validation arbitrage",
            leverage_score=round(_bounded_score(action.leverage_score + 6), 1),
            why_this_matters=(
                "Most assistants answer the question. ALTER changes the user's probability "
                "curve by forcing external proof."
            ),
            stack=[
                "User conversations",
                "Prototype or deck artifact",
                "Outcome memory",
                "Reputation event",
            ],
            first_step=action.first_step,
            opportunity_refs=refs[:2],
        ),
        OpportunityArbitrageMove(
            title="Opportunity stack",
            leverage_score=round(
                _bounded_score(58 + len(refs) * 6 + trajectory.alignment_score * 0.12),
                1,
            ),
            why_this_matters=(
                f"{top_ref} can turn the objective into distribution, funding, "
                "credibility, or expert feedback faster than isolated building."
            ),
            stack=["Opportunity Radar", "Clone Council", "Future Simulation", "Memory Graph"],
            first_step=(
                f"Open {top_ref}, decide apply/contact/ignore, and save the result as evidence."
            ),
            opportunity_refs=refs,
        ),
        OpportunityArbitrageMove(
            title="Network proof route",
            leverage_score=round(
                _bounded_score(54 + trajectory.execution_velocity * 0.18),
                1,
            ),
            why_this_matters=(
                "A warm path compresses learning time and gives ALTER real-world feedback "
                "about who trusts the user's direction."
            ),
            stack=["Social Graph", "NFC contacts", "Mentor route", "Follow-up ledger"],
            first_step=(
                "Ask one founder, professor, recruiter, or investor for a specific critique "
                f"of: {request.objective}"
            ),
            opportunity_refs=refs[:1],
        ),
    ]
    return moves


def _future_twin_model_updates(
    *,
    trajectory: FutureTwinTrajectory,
    evidence_signals: list[EvidenceSignal],
    action: CompiledAction,
    reputation_data: dict[str, Any],
) -> list[str]:
    strongest = max(evidence_signals, key=lambda item: item.impact_score, default=None)
    updates = [
        f"Trajectory alignment set to {trajectory.alignment_score:.1f}/100.",
        f"Execution velocity set to {trajectory.execution_velocity:.1f}/100.",
        f"Drift risk set to {trajectory.drift_risk:.1f}/100.",
        f"Next recommendation should require proof: {action.proof_required[0]}",
    ]
    if strongest is not None:
        updates.append(
            f"Weight '{strongest.title}' as strongest evidence at {strongest.impact_score:.1f}/100."
        )
    if reputation_data:
        updates.append(
            f"Reputation model read trust level '{reputation_data.get('trust_level', 'baseline')}'."
        )
    return updates[:6]


def _future_twin_identity_summary(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    trajectory: FutureTwinTrajectory,
    evidence_signals: list[EvidenceSignal],
) -> str:
    skills = ", ".join(request.skills[:3]) or "execution, learning, and judgment"
    goals = ", ".join(request.goals[:2]) or request.objective
    evidence_count = len(evidence_signals)
    return (
        f"The Future Twin sees a user pursuing {goals} with strengths in {skills}. "
        f"Current path: {trajectory.current_trajectory}. ALTER found {evidence_count} "
        f"evidence signal(s), recommends '{decision.recommended_future}', and needs "
        "fresh proof to separate ambition from actual behavior."
    )


def _future_twin_daily_question(
    *,
    request: FutureTwinRequest,
    decision: IntelligenceDecisionResponse,
    trajectory: FutureTwinTrajectory,
) -> str:
    future_name = decision.recommended_future or trajectory.best_alternative_future
    if trajectory.drift_risk >= 62:
        return (
            f"What proof will you create today that makes {future_name} more real "
            "than the drift path?"
        )
    return (
        f"What did you do today that compounds {future_name} and would still matter "
        f"{request.horizon_days} days from now?"
    )


def _future_twin_memory_content(
    *,
    objective: str,
    trajectory: FutureTwinTrajectory,
    action: CompiledAction,
    arbitrage: list[OpportunityArbitrageMove],
    model_updates: list[str],
) -> str:
    return "\n".join(
        [
            f"Objective: {objective}",
            f"Current trajectory: {trajectory.current_trajectory}",
            f"90-day prediction: {trajectory.predicted_90_day_future}",
            f"Best alternative: {trajectory.best_alternative_future}",
            f"Alignment: {trajectory.alignment_score:.1f}",
            f"Execution velocity: {trajectory.execution_velocity:.1f}",
            f"Drift risk: {trajectory.drift_risk:.1f}",
            "Compiled action:",
            f"- {action.title}",
            f"- Deadline: {action.deadline}",
            f"- Success metric: {action.success_metric}",
            "Proof required:",
            *[f"- {proof}" for proof in action.proof_required],
            "Opportunity arbitrage:",
            *[f"- {move.title}: {move.first_step}" for move in arbitrage],
            "Model updates:",
            *[f"- {update}" for update in model_updates],
        ]
    )


def _future_twin_confidence(
    *,
    decision: IntelligenceDecisionResponse,
    evidence_signals: list[EvidenceSignal],
    steps: list[DemoStep],
) -> float:
    health = sum(1 for step in steps if step.status == "ok") / max(len(steps), 1)
    evidence_strength = _average_evidence_strength(evidence_signals) / 100.0
    confidence = decision.confidence_score * 0.54 + evidence_strength * 0.26 + health * 0.2
    return round(max(0.05, min(0.98, confidence)), 2)


def _best_future_option(options: list[FutureOption]) -> FutureOption | None:
    if not options:
        return None
    return max(
        options,
        key=lambda option: option.success_probability * option.opportunity_score
        - option.risk_score * 0.22,
    )


def _average_evidence_strength(evidence_signals: list[EvidenceSignal]) -> float:
    if not evidence_signals:
        return 35.0
    weighted = [
        signal.impact_score * max(0.25, signal.confidence)
        for signal in evidence_signals
    ]
    return round(sum(weighted) / len(weighted), 1)


def _proof_memory_content(
    *,
    objective: str,
    linked_goal: str,
    linked_action: str,
    source_surface: str,
    evidence: Any,
    impact_score: float,
) -> str:
    lines = [
        f"Objective: {objective}",
        f"Linked goal: {linked_goal}",
        f"Linked action: {linked_action}",
        f"Source surface: {source_surface}",
        f"Evidence type: {evidence.evidence_type}",
        f"Title: {evidence.title}",
        f"Source: {evidence.source}",
        f"Confidence: {evidence.confidence:.2f}",
        f"Impact score: {impact_score:.1f}",
        f"Summary: {evidence.summary}",
    ]
    if evidence.url:
        lines.append(f"URL: {evidence.url}")
    return "\n".join(lines)


def _proof_importance(impact_score: float) -> float:
    return round(max(0.35, min(0.96, 0.38 + impact_score / 150)), 2)


def _proof_reputation_event_type(evidence_type: str, impact_score: float) -> str:
    text = evidence_type.lower()
    if any(token in text for token in ("intro", "mentor", "network")):
        return "intro_made"
    if any(token in text for token in ("conversation", "interview", "follow")):
        return "follow_up"
    if any(token in text for token in ("github", "prototype", "project", "artifact")):
        return "contribution"
    if impact_score >= 78:
        return "delivered"
    return "commitment_created"


def _proof_reputation_impact(impact_score: float) -> int:
    return int(round(max(4, min(36, impact_score * 0.32))))


def _proof_trajectory_effect(evidence_type: str, impact_score: float) -> str:
    text = evidence_type.lower()
    if impact_score >= 82:
        return "Strong proof: raises execution velocity and lowers drift risk."
    if any(token in text for token in ("user", "customer", "market", "interview")):
        return "Market proof: improves confidence in the opportunity path."
    if any(token in text for token in ("prototype", "github", "artifact", "project")):
        return "Build proof: strengthens skill and product trajectory."
    if impact_score >= 58:
        return "Moderate proof: keeps the Future Twin anchored in reality."
    return "Weak proof: useful context, but not enough to change the trajectory alone."


def _proof_graph(
    *,
    objective: str,
    linked_goal: str,
    linked_action: str,
    evidence_records: list[ProofEvidenceRecord],
) -> tuple[list[ProofGraphNode], list[ProofGraphEdge]]:
    nodes = [
        ProofGraphNode(
            node_id="goal",
            label=_truncate(linked_goal or objective, 120),
            kind="goal",
            score=72,
        ),
        ProofGraphNode(
            node_id="action",
            label=_truncate(linked_action, 120),
            kind="action",
            score=68,
        ),
        ProofGraphNode(
            node_id="future_twin",
            label="Future Twin update",
            kind="future_twin",
            score=_bounded_score(
                sum(record.impact_score for record in evidence_records)
                / max(len(evidence_records), 1)
            ),
        ),
        ProofGraphNode(
            node_id="daily_loop",
            label="Daily proof briefing",
            kind="daily_briefing",
            score=74,
        ),
    ]
    edges = [
        ProofGraphEdge(from_node="goal", to_node="action", label="compiled into", strength=0.82),
        ProofGraphEdge(from_node="future_twin", to_node="daily_loop", label="sets prompt", strength=0.76),
    ]
    for index, record in enumerate(evidence_records):
        evidence_id = f"evidence_{index + 1}"
        nodes.append(
            ProofGraphNode(
                node_id=evidence_id,
                label=_truncate(record.title, 120),
                kind="evidence",
                score=record.impact_score,
                status="captured",
            )
        )
        edges.extend(
            [
                ProofGraphEdge(
                    from_node="action",
                    to_node=evidence_id,
                    label="produced",
                    strength=max(0.25, record.confidence),
                ),
                ProofGraphEdge(
                    from_node=evidence_id,
                    to_node="future_twin",
                    label="updates",
                    strength=max(0.25, min(0.98, record.impact_score / 100)),
                ),
            ]
        )
        if record.memory_id is not None:
            memory_id = f"memory_{index + 1}"
            nodes.append(
                ProofGraphNode(
                    node_id=memory_id,
                    label="Memory node",
                    kind="memory",
                    score=record.impact_score,
                    status="saved",
                )
            )
            edges.append(
                ProofGraphEdge(
                    from_node=evidence_id,
                    to_node=memory_id,
                    label="stored as",
                    strength=0.9,
                )
            )
    return nodes, edges


def _proof_trust_profile(
    evidence_records: list[ProofEvidenceRecord],
    reputation_data: dict[str, Any],
) -> TrustExecutionProfile:
    high_proof = sum(1 for record in evidence_records if record.impact_score >= 70)
    average_impact = (
        sum(record.impact_score for record in evidence_records) / max(len(evidence_records), 1)
    )
    reputation_score = _safe_float(reputation_data.get("score"), 600.0) / 10.0
    follow_through = _bounded_score(average_impact * 0.56 + reputation_score * 0.34 + high_proof * 4)
    strengths = _coerce_string_list(reputation_data.get("strengths"))
    risks = _coerce_string_list(reputation_data.get("risks"))
    if high_proof:
        strengths.insert(0, f"{high_proof} high-signal proof item(s) captured.")
    if average_impact < 55:
        risks.insert(0, "Evidence quality is still too weak to move the future curve.")
    return TrustExecutionProfile(
        execution_streak=high_proof,
        follow_through_score=round(follow_through, 1),
        trust_level=str(reputation_data.get("trust_level") or "baseline"),
        strengths=(strengths or ["Proof capture established a baseline."])[:4],
        risks=(risks or ["No acute proof risk detected."])[:4],
    )


def _proof_future_twin_delta(
    evidence_records: list[ProofEvidenceRecord],
    trust_profile: TrustExecutionProfile,
) -> FutureTwinDelta:
    average_impact = (
        sum(record.impact_score for record in evidence_records) / max(len(evidence_records), 1)
    )
    strong_count = sum(1 for record in evidence_records if record.impact_score >= 76)
    alignment_delta = round(max(0.5, min(14.0, average_impact / 12 + strong_count * 1.2)), 1)
    execution_delta = round(
        max(0.5, min(18.0, trust_profile.follow_through_score / 10 + strong_count * 1.8)),
        1,
    )
    drift_delta = round(-max(0.5, min(16.0, average_impact / 14 + strong_count * 1.4)), 1)
    if strong_count:
        summary = (
            f"{strong_count} strong proof signal(s) should increase execution velocity "
            "and reduce drift in the Future Twin."
        )
        recalibration = "Weight real artifacts higher than stated intent in the next recommendation."
    else:
        summary = "Proof was captured, but ALTER should still demand stronger external evidence."
        recalibration = "Shrink the next action until proof can be produced within 24 hours."
    return FutureTwinDelta(
        alignment_delta=alignment_delta,
        execution_delta=execution_delta,
        drift_delta=drift_delta,
        summary=summary,
        recommended_recalibration=recalibration,
    )


def _daily_proof_briefing(
    *,
    objective: str,
    linked_goal: str,
    linked_action: str,
    evidence_records: list[ProofEvidenceRecord],
    future_delta: FutureTwinDelta,
) -> DailyProofBriefing:
    strongest = max(evidence_records, key=lambda item: item.impact_score, default=None)
    proof = (
        f"Turn '{strongest.title}' into a public or shareable artifact."
        if strongest is not None
        else f"Create one proof artifact for {linked_goal or objective}."
    )
    if future_delta.drift_delta <= -8:
        drift_alert = "Drift risk decreased because proof now exists."
    else:
        drift_alert = "Drift risk remains sensitive: capture stronger external proof today."
    return DailyProofBriefing(
        morning_question=(
            f"What proof will you create today that makes '{linked_goal or objective}' "
            "more real by tonight?"
        ),
        evening_question=(
            "Did you produce proof, where is it, and what did reality teach you?"
        ),
        recommended_proof=proof,
        drift_alert=drift_alert,
        push_notifications=[
            f"Your next proof action: {linked_action}",
            proof,
            "Tonight: save the outcome so ALTER can update your Future Twin.",
        ],
    )


def _proof_next_actions(
    *,
    linked_action: str,
    daily_briefing: DailyProofBriefing,
    evidence_records: list[ProofEvidenceRecord],
) -> list[str]:
    strongest = max(evidence_records, key=lambda item: item.impact_score, default=None)
    actions = [
        linked_action,
        daily_briefing.recommended_proof,
        "Attach a URL, screenshot, note, scan, or meeting record to this proof.",
        "Run the evening proof check and save the outcome memory.",
    ]
    if strongest is not None and strongest.impact_score >= 78:
        actions.append(f"Use '{strongest.title}' as the anchor for the next Future Twin run.")
    return _dedupe_strings(actions)[:5]


def _voice_runtime_question(normalized: str, transcript: str, intent: str) -> str:
    text = normalized or transcript
    if intent == "opportunity_search":
        return f"What opportunities should I act on for: {text}?"
    if intent == "clone_council":
        return f"What should my Clone Council recommend for: {text}?"
    if intent == "social_graph":
        return f"Who should I talk to and what warm paths matter for: {text}?"
    if intent == "reputation":
        return f"What execution move will improve my reputation for: {text}?"
    if intent == "unknown":
        return f"Interpret this voice request and turn it into the best ALTER action: {text}"
    return text


def _voice_spoken_response(
    *,
    normalized: str,
    intent: str,
    decision: IntelligenceDecisionResponse | None,
    memory_signal: DemoStep | None,
) -> str:
    if decision is not None:
        action = decision.experiment_plan.action
        confidence = round(decision.confidence_score * 100)
        return (
            f"I heard: {normalized}. I recommend: {decision.recommendation} "
            f"Confidence is {confidence} percent. Your next experiment is: {action}."
        )
    if memory_signal is not None and memory_signal.status == "ok":
        return "I saved that to memory. I will use it in future decisions."
    if intent == "memory_capture":
        return "I tried to save that memory, but the memory system did not confirm it."
    return (
        "I heard you, but I need one more concrete decision or goal to run the full ALTER loop."
    )


def _voice_display_response(
    spoken_response: str,
    decision: IntelligenceDecisionResponse | None,
    memory_signal: DemoStep | None,
) -> str:
    if decision is not None:
        return (
            f"{spoken_response}\n\n"
            f"Experiment deadline: {decision.experiment_plan.deadline}\n"
            f"Success metric: {decision.experiment_plan.success_metric}"
        )
    if memory_signal is not None:
        return f"{spoken_response}\n\n{memory_signal.summary}"
    return spoken_response


def _voice_action_graph(
    intent: str,
    decision: IntelligenceDecisionResponse | None,
    memory_signal: DemoStep | None,
) -> list[str]:
    graph = [
        "Capture transcript",
        "Detect Hey Alter wake phrase",
        f"Infer intent: {intent}",
    ]
    if decision is not None:
        graph.extend(
            [
                "Retrieve personal memory",
                "Simulate futures",
                "Run Clone Council",
                "Rank opportunities",
                "Create experiment plan",
                "Write decision memory",
                "Prepare spoken response",
            ]
        )
    elif memory_signal is not None:
        graph.extend(["Write voice memory", "Prepare spoken confirmation"])
    else:
        graph.append("Ask for a sharper decision")
    return graph


def _voice_follow_up_questions(
    intent: str,
    decision: IntelligenceDecisionResponse | None,
) -> list[str]:
    if decision is not None:
        return [
            "Did you do the experiment?",
            "What happened?",
            "What did you learn?",
        ]
    if intent == "memory_capture":
        return ["Should I connect this memory to a goal or project?"]
    return [
        "What decision do you want to make?",
        "What goal should ALTER optimize for?",
    ]


def _to_signal(step: DemoStep) -> IntelligenceSignal:
    return IntelligenceSignal(
        name=step.name,
        title=step.title,
        status=step.status,
        summary=step.summary,
        latency_ms=step.latency_ms,
        data=step.data,
    )


def _created_memory_id(data: dict[str, Any]) -> Any:
    memory_id = data.get("id")
    return memory_id if isinstance(memory_id, str) and memory_id else None


def _optional_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _future_summary(data: dict[str, Any]) -> str:
    futures = data.get("futures", [])
    first = futures[0] if isinstance(futures, list) and futures else {}
    if isinstance(first, dict):
        return f"Generated {len(futures)} futures; leading path is {first.get('name', 'ready')}."
    return f"Generated {len(futures)} futures."


def _opportunity_summary(data: dict[str, Any]) -> str:
    ranked = data.get("ranked", {}).get("ranked_opportunities", [])
    top = ranked[0] if isinstance(ranked, list) and ranked else {}
    if isinstance(top, dict):
        return f"Ranked opportunities; top score is {round(float(top.get('score', 0)), 1)}."
    return "Ranked opportunity signals."


def _executive_summary(
    *,
    objective: str,
    future_data: dict[str, Any],
    council_data: dict[str, Any],
    opportunity_data: dict[str, Any],
) -> str:
    recommendation = council_data.get("final_recommendation") or (
        "Run a reversible evidence-producing next step."
    )
    future_name = "the strongest simulated path"
    futures = future_data.get("futures", [])
    if isinstance(futures, list) and futures and isinstance(futures[0], dict):
        future_name = str(futures[0].get("name") or future_name)
    opportunity_count = len(
        opportunity_data.get("recommendations", {}).get("recommendations", [])
    )
    return (
        f"For '{objective}', ALTER recommends anchoring on {future_name}, "
        f"using the Clone Council's recommendation: {recommendation} "
        f"The radar found {opportunity_count} matching opportunity signal(s)."
    )


def _next_actions(council_data: dict[str, Any], office_data: dict[str, Any]) -> list[str]:
    actions = [
        str(item)
        for item in council_data.get("action_plan", [])
        if isinstance(item, str)
    ]
    for item in office_data.get("action_items", []):
        if isinstance(item, dict) and item.get("title"):
            actions.append(str(item["title"]))
    return actions[:5] or ["Run one validation step within seven days."]


def _risks(council_data: dict[str, Any], office_data: dict[str, Any]) -> list[str]:
    risks = [str(item) for item in council_data.get("risks", []) if isinstance(item, str)]
    risks.extend(str(item) for item in office_data.get("risks", []) if isinstance(item, str))
    return risks[:5] or ["Risk: acting without fresh external evidence."]


def _opportunities(council_data: dict[str, Any], opportunity_data: dict[str, Any]) -> list[str]:
    opportunities = [
        str(item)
        for item in council_data.get("opportunities", [])
        if isinstance(item, str)
    ]
    recommendations = opportunity_data.get("recommendations", {}).get("recommendations", [])
    for item in recommendations:
        if isinstance(item, dict) and item.get("title"):
            opportunities.append(str(item["title"]))
    return opportunities[:5] or ["Opportunity: convert the decision into a public proof point."]


def _coerce_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value]
    return []


def _dedupe_strings(values: list[str]) -> list[str]:
    seen = set()
    result = []
    for value in values:
        item = " ".join(str(value).strip().split())
        key = item.lower()
        if item and key not in seen:
            result.append(item)
            seen.add(key)
    return result


def _safe_float(value: Any, fallback: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def _bounded_float(value: Any, fallback: float) -> float:
    return max(0.0, min(1.0, _safe_float(value, fallback)))


def _bounded_score(value: Any) -> float:
    return max(0.0, min(100.0, _safe_float(value, 0.0)))


def _skill_category(skill: str) -> str:
    text = skill.lower()
    if any(token in text for token in ("flutter", "python", "ai", "data", "backend")):
        return "technical"
    if any(token in text for token in ("product", "growth", "market", "user")):
        return "product"
    if any(token in text for token in ("fundraising", "sales", "business", "startup")):
        return "business"
    if any(token in text for token in ("design", "ux", "brand")):
        return "design"
    if any(token in text for token in ("story", "writing", "communication")):
        return "communication"
    return "domain"


def _goal_category(goal: str) -> str:
    text = goal.lower()
    if any(token in text for token in ("startup", "founder", "funding", "launch")):
        return "startup"
    if any(token in text for token in ("learn", "skill", "master")):
        return "learning"
    if any(token in text for token in ("salary", "wealth", "money", "income")):
        return "wealth"
    if any(token in text for token in ("leader", "team", "manage")):
        return "leadership"
    if any(token in text for token in ("reputation", "brand", "audience")):
        return "reputation"
    return "career"


def _truncate(value: str, limit: int) -> str:
    normalized = " ".join(value.strip().split())
    if len(normalized) <= limit:
        return normalized
    return f"{normalized[: max(0, limit - 1)].rstrip()}..."


async def _check_service(client: httpx.AsyncClient, route: ServiceRoute) -> ServiceHealth:
    started = time.perf_counter()
    try:
        response = await client.get(route.health_url)
        latency_ms = int((time.perf_counter() - started) * 1000)
        if response.status_code == 200:
            return ServiceHealth(
                name=route.name,
                base_url=route.base_url,
                status="ok",
                latency_ms=latency_ms,
            )
        return ServiceHealth(
            name=route.name,
            base_url=route.base_url,
            status="error",
            latency_ms=latency_ms,
            detail=f"HTTP {response.status_code}",
        )
    except Exception as error:  # noqa: BLE001 - edge health endpoint should never fail hard
        latency_ms = int((time.perf_counter() - started) * 1000)
        return ServiceHealth(
            name=route.name,
            base_url=route.base_url,
            status="down",
            latency_ms=latency_ms,
            detail=str(error),
        )
