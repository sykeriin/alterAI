from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ServiceRoute(BaseModel):
    name: str
    base_url: str
    health_url: str


class ServiceHealth(BaseModel):
    name: str
    base_url: str
    status: str
    latency_ms: int | None = None
    detail: str = ""


class SystemHealthResponse(BaseModel):
    status: str
    services: list[ServiceHealth]
    checked_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class MissionBriefingRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    objective: str = Field(min_length=2, max_length=600)
    device_context: str = Field(default="phone", max_length=80)
    include_services: list[str] = Field(default_factory=list, max_length=20)


class MissionBriefingResponse(BaseModel):
    briefing_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    objective: str
    command_summary: str
    phone_layer: list[str]
    laptop_layer: list[str]
    recommended_sequence: list[str]
    route_targets: list[str]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class DemoRunRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    objective: str = Field(min_length=2, max_length=600)
    device_context: str = Field(default="mission_control", max_length=80)
    profile: dict[str, Any] = Field(default_factory=dict)


class DemoStep(BaseModel):
    name: str
    title: str
    status: str
    summary: str
    latency_ms: int | None = None
    data: dict[str, Any] = Field(default_factory=dict)


class DemoRunResponse(BaseModel):
    demo_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    objective: str
    headline: str
    executive_summary: str
    steps: list[DemoStep]
    key_metrics: dict[str, str]
    next_actions: list[str]
    risks: list[str]
    opportunities: list[str]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class IntelligenceDecisionRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    question: str = Field(min_length=3, max_length=1000)
    user_profile: dict[str, Any] = Field(default_factory=dict)
    skills: list[str] = Field(default_factory=list, max_length=80)
    goals: list[str] = Field(default_factory=list, max_length=40)
    experience: list[dict[str, Any]] = Field(default_factory=list, max_length=60)
    interests: list[str] = Field(default_factory=list, max_length=80)
    context: dict[str, Any] = Field(default_factory=dict)
    decision_horizon_months: int = Field(default=36, ge=12, le=120)
    write_memory: bool = True


class IntelligenceSignal(BaseModel):
    name: str
    title: str
    status: str
    summary: str
    latency_ms: int | None = None
    data: dict[str, Any] = Field(default_factory=dict)


class FutureOption(BaseModel):
    future_id: str
    name: str
    thesis: str
    success_probability: float = Field(ge=0.0, le=1.0)
    opportunity_score: float = Field(ge=0.0, le=100.0)
    risk_score: float = Field(ge=0.0, le=100.0)


class ExperimentPlan(BaseModel):
    experiment_id: UUID = Field(default_factory=uuid4)
    action: str = Field(min_length=2, max_length=280)
    why_it_matters: str = Field(min_length=2, max_length=600)
    deadline: str = Field(min_length=2, max_length=80)
    success_metric: str = Field(min_length=2, max_length=280)


class IntelligenceDecisionResponse(BaseModel):
    decision_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    question: str
    recommendation: str
    confidence_score: float = Field(ge=0.0, le=1.0)
    decision_summary: str
    recommended_future: str
    experiment_plan: ExperimentPlan
    future_options: list[FutureOption]
    memory_context: list[str]
    opportunity_matches: list[str]
    next_actions: list[str]
    risks: list[str]
    opportunities: list[str]
    signals: list[IntelligenceSignal]
    created_memory_id: UUID | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class OutcomeUpdateRequest(BaseModel):
    user_id: UUID
    decision_id: UUID | None = None
    question: str = Field(min_length=3, max_length=1000)
    experiment_plan: ExperimentPlan
    did_it: bool
    what_happened: str = Field(min_length=2, max_length=1500)
    what_learned: str = Field(min_length=2, max_length=1500)
    success_metric_result: str = Field(min_length=2, max_length=600)
    outcome_score: float = Field(ge=0.0, le=1.0)


class OutcomeUpdateResponse(BaseModel):
    outcome_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    decision_id: UUID | None = None
    execution_score: float = Field(ge=0.0, le=100.0)
    confidence_delta: float = Field(ge=-1.0, le=1.0)
    memory_id: UUID | None = None
    reputation_event_id: UUID | None = None
    reputation_score: int | None = None
    trust_level: str = ""
    profile_updates: list[str]
    next_recommendation: str
    memory_summary: str
    signals: list[IntelligenceSignal]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class EvidenceInput(BaseModel):
    evidence_type: str = Field(default="artifact", min_length=2, max_length=80)
    title: str = Field(min_length=2, max_length=180)
    summary: str = Field(min_length=2, max_length=900)
    source: str = Field(default="manual", max_length=120)
    url: str | None = Field(default=None, max_length=800)
    confidence: float = Field(default=0.72, ge=0.0, le=1.0)


class FutureTwinRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    objective: str = Field(min_length=3, max_length=1000)
    user_profile: dict[str, Any] = Field(default_factory=dict)
    skills: list[str] = Field(default_factory=list, max_length=80)
    goals: list[str] = Field(default_factory=list, max_length=40)
    experience: list[dict[str, Any]] = Field(default_factory=list, max_length=60)
    interests: list[str] = Field(default_factory=list, max_length=80)
    recent_evidence: list[EvidenceInput] = Field(default_factory=list, max_length=20)
    horizon_days: int = Field(default=90, ge=14, le=365)
    write_memory: bool = True


class TrajectoryPoint(BaseModel):
    label: str
    current_score: float = Field(ge=0.0, le=100.0)
    predicted_score: float = Field(ge=0.0, le=100.0)
    best_case_score: float = Field(ge=0.0, le=100.0)


class FutureTwinTrajectory(BaseModel):
    current_trajectory: str
    predicted_90_day_future: str
    best_alternative_future: str
    alignment_score: float = Field(ge=0.0, le=100.0)
    execution_velocity: float = Field(ge=0.0, le=100.0)
    drift_risk: float = Field(ge=0.0, le=100.0)
    points: list[TrajectoryPoint]


class CompiledAction(BaseModel):
    action_id: UUID = Field(default_factory=uuid4)
    title: str
    why_now: str
    deadline: str
    success_metric: str
    proof_required: list[str]
    first_step: str
    leverage_score: float = Field(ge=0.0, le=100.0)


class EvidenceSignal(BaseModel):
    evidence_id: UUID = Field(default_factory=uuid4)
    evidence_type: str
    title: str
    source: str
    impact_score: float = Field(ge=0.0, le=100.0)
    confidence: float = Field(ge=0.0, le=1.0)
    memory_id: UUID | None = None
    summary: str


class OpportunityArbitrageMove(BaseModel):
    title: str
    leverage_score: float = Field(ge=0.0, le=100.0)
    why_this_matters: str
    stack: list[str]
    first_step: str
    opportunity_refs: list[str]


class FutureTwinResponse(BaseModel):
    twin_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    objective: str
    identity_summary: str
    daily_question: str
    trajectory: FutureTwinTrajectory
    action: CompiledAction
    future_options: list[FutureOption]
    evidence_signals: list[EvidenceSignal]
    opportunity_arbitrage: list[OpportunityArbitrageMove]
    model_updates: list[str]
    confidence_score: float = Field(ge=0.0, le=1.0)
    decision_report: IntelligenceDecisionResponse
    signals: list[IntelligenceSignal]
    created_memory_id: UUID | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ProofCaptureRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    objective: str = Field(min_length=3, max_length=1000)
    linked_goal: str = Field(default="", max_length=280)
    linked_action: str = Field(default="", max_length=280)
    source_surface: str = Field(default="mission_control", max_length=80)
    evidence: list[EvidenceInput] = Field(default_factory=list, min_length=1, max_length=20)
    write_memory: bool = True
    update_reputation: bool = True


class ProofEvidenceRecord(BaseModel):
    evidence_id: UUID = Field(default_factory=uuid4)
    evidence_type: str
    title: str
    summary: str
    source: str
    linked_goal: str
    linked_action: str
    impact_score: float = Field(ge=0.0, le=100.0)
    confidence: float = Field(ge=0.0, le=1.0)
    trajectory_effect: str
    memory_id: UUID | None = None
    reputation_event_id: UUID | None = None
    captured_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ProofGraphNode(BaseModel):
    node_id: str
    label: str
    kind: str
    score: float = Field(default=0.0, ge=0.0, le=100.0)
    status: str = "active"


class ProofGraphEdge(BaseModel):
    from_node: str
    to_node: str
    label: str
    strength: float = Field(default=0.5, ge=0.0, le=1.0)


class DailyProofBriefing(BaseModel):
    morning_question: str
    evening_question: str
    recommended_proof: str
    drift_alert: str
    push_notifications: list[str]


class TrustExecutionProfile(BaseModel):
    execution_streak: int = Field(ge=0)
    follow_through_score: float = Field(ge=0.0, le=100.0)
    trust_level: str
    strengths: list[str]
    risks: list[str]


class FutureTwinDelta(BaseModel):
    alignment_delta: float = Field(ge=-100.0, le=100.0)
    execution_delta: float = Field(ge=-100.0, le=100.0)
    drift_delta: float = Field(ge=-100.0, le=100.0)
    summary: str
    recommended_recalibration: str


class ProofCaptureResponse(BaseModel):
    proof_capture_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    objective: str
    evidence_records: list[ProofEvidenceRecord]
    graph_nodes: list[ProofGraphNode]
    graph_edges: list[ProofGraphEdge]
    daily_briefing: DailyProofBriefing
    trust_profile: TrustExecutionProfile
    future_twin_delta: FutureTwinDelta
    next_actions: list[str]
    signals: list[IntelligenceSignal]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class VoiceActionRuntimeRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    transcript: str = Field(min_length=1, max_length=4000)
    locale: str = Field(default="en-US", min_length=2, max_length=16)
    device_surface: str = Field(default="phone", max_length=24)
    user_profile: dict[str, Any] = Field(default_factory=dict)
    skills: list[str] = Field(default_factory=list, max_length=80)
    goals: list[str] = Field(default_factory=list, max_length=40)
    interests: list[str] = Field(default_factory=list, max_length=80)
    context: dict[str, Any] = Field(default_factory=dict)


class VoiceActionRuntimeResponse(BaseModel):
    runtime_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    transcript: str
    normalized_text: str
    wake_word_detected: bool
    inferred_intent: str
    intent_confidence: float = Field(ge=0.0, le=1.0)
    spoken_response: str
    display_response: str
    ai_provider: str = "alter-local"
    source_language_code: str = "auto"
    response_language_code: str = "en-IN"
    language_display_name: str = "English"
    action_graph: list[str]
    experiment_plan: ExperimentPlan | None = None
    next_actions: list[str]
    follow_up_questions: list[str]
    decision_report: IntelligenceDecisionResponse | None = None
    signals: list[IntelligenceSignal]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ArchitectureResponse(BaseModel):
    service: str
    components: list[str]
    data_flow: list[str]
    output_contract: dict[str, list[str]]


class LifeFeedTask(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    meta: str = Field(default="", max_length=240)
    badge: str = Field(default="", max_length=40)
    done: bool = False
    hot: bool = False


class LifeFeedOpportunity(BaseModel):
    tag: str = Field(min_length=1, max_length=40)
    match_score: int = Field(ge=0, le=100)
    title: str = Field(min_length=1, max_length=240)
    meta: str = Field(default="", max_length=240)


class LifeFeedResponse(BaseModel):
    user_id: UUID
    greeting: str
    date_summary: str
    focus_title: str
    focus_rationale: str
    tasks: list[LifeFeedTask]
    opportunities: list[LifeFeedOpportunity]
    items_needing_attention: int = Field(ge=0, le=50)
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class UserSettingsPatch(BaseModel):
    languages: list[str] = Field(default_factory=list, max_length=12)
    role: str = Field(default="", max_length=80)
    permissions: dict[str, bool] = Field(default_factory=dict)


class UserSettingsResponse(BaseModel):
    user_id: UUID
    languages: list[str]
    role: str
    permissions: dict[str, bool]
    theme_light: bool = False
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class PlatformIntegration(BaseModel):
    id: str
    name: str
    connected: bool
    status: str = "disconnected"


class IntegrationsResponse(BaseModel):
    user_id: UUID
    platforms: list[PlatformIntegration]


class MultilingualLanguage(BaseModel):
    code: str
    name: str
    region: str
    sarvam_translate: bool
    sarvam_chat: bool


class MultilingualLanguageResponse(BaseModel):
    provider: str = "sarvam"
    sarvam_enabled: bool
    indian_languages: list[MultilingualLanguage]
    major_foreign_languages: list[MultilingualLanguage]


class MultilingualChatMessage(BaseModel):
    role: str = Field(pattern="^(system|user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class MultilingualChatRequest(BaseModel):
    messages: list[MultilingualChatMessage] = Field(min_length=1, max_length=16)
    target_language_code: str = Field(default="en-IN", min_length=2, max_length=16)
    temperature: float = Field(default=0.35, ge=0.0, le=2.0)
    max_tokens: int = Field(default=900, ge=32, le=2048)


class MultilingualChatResponse(BaseModel):
    text: str
    provider: str
    model: str
    target_language_code: str
    language_display_name: str
    sarvam_enabled: bool
    fallback: bool = False
    usage: dict[str, Any] = Field(default_factory=dict)


class MultilingualTranslateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    target_language_code: str = Field(default="hi-IN", min_length=2, max_length=16)
    source_language_code: str = Field(default="auto", min_length=2, max_length=16)


class MultilingualTranslateResponse(BaseModel):
    text: str
    provider: str
    model: str
    source_language_code: str
    target_language_code: str
    language_display_name: str
    sarvam_enabled: bool
    fallback: bool = False
    request_id: str | None = None
    error: str = ""


class LanguageDetectRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1000)


class LanguageDetectResponse(BaseModel):
    provider: str
    sarvam_enabled: bool
    language_code: str
    script_code: str = ""
    request_id: str | None = None
    fallback: bool = False
    error: str = ""


class SarvamTtsRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2500)
    target_language_code: str = Field(default="hi-IN", min_length=2, max_length=16)
    speaker: str = Field(default="shubh", min_length=2, max_length=40)
    pace: float = Field(default=1.0, ge=0.5, le=2.0)
    speech_sample_rate: int = Field(default=24000, ge=8000, le=48000)


class SarvamTtsResponse(BaseModel):
    provider: str
    model: str
    sarvam_enabled: bool
    target_language_code: str
    language_display_name: str
    speaker: str
    speech_sample_rate: int
    audio_base64: str = ""
    audio_count: int = 0
    request_id: str | None = None
    fallback: bool = False
    error: str = ""


class SarvamSttResponse(BaseModel):
    provider: str
    model: str
    sarvam_enabled: bool
    transcript: str
    language_code: str = ""
    language_probability: float | None = None
    request_id: str | None = None
    fallback: bool = False
    timestamps: dict[str, Any] | None = None
    diarized_transcript: dict[str, Any] | None = None
    error: str = ""


class ConsentGrantRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    source: str = Field(min_length=2, max_length=80)
    access_level: str = Field(default="metadata", max_length=40)
    granted: bool = True
    retention_days: int = Field(default=30, ge=1, le=3650)
    reason: str = Field(default="", max_length=500)


class ConsentGrant(BaseModel):
    consent_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    source: str
    access_level: str
    granted: bool
    retention_days: int
    reason: str
    reversible: bool = True
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ConsentLedgerResponse(BaseModel):
    user_id: UUID
    grants: list[ConsentGrant]
    required_for_full_assistant: list[str]
    audit_note: str


class DataIngestionRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    source: str = Field(min_length=2, max_length=80)
    import_mode: str = Field(default="manual_import", max_length=60)
    consent_id: UUID | None = None
    items: list[dict[str, Any]] = Field(default_factory=list, max_length=50)
    metadata_only: bool = True


class DataIngestionResponse(BaseModel):
    ingestion_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    source: str
    accepted: bool
    imported_count: int = 0
    memory_candidates: list[dict[str, Any]]
    blocked_reasons: list[str]
    audit_events: list[str]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class ContextItem(BaseModel):
    """One piece of decision context, tagged with where it came from.

    Source labels: local | cloud | user-entered | inferred | imported.
    """

    source: str = Field(default="local", max_length=24)
    text: str = Field(min_length=1, max_length=2000)


class AgentPlannerRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    goal: str = Field(min_length=2, max_length=1000)
    device_state: dict[str, Any] = Field(default_factory=dict)
    allowed_tools: list[str] = Field(default_factory=list, max_length=50)
    autonomy_level: str = Field(default="confirm_before_act", max_length=60)
    # Optional client-provided (on-device) memory context. Absent → today's
    # behaviour; present → merged into the decision context pack with labels.
    client_context: list[ContextItem] = Field(default_factory=list, max_length=50)


class AgentPlanStep(BaseModel):
    step_id: UUID = Field(default_factory=uuid4)
    tool_name: str
    title: str
    rationale: str
    parameters: dict[str, Any] = Field(default_factory=dict)
    requires_confirmation: bool = True
    requires_accessibility: bool = False
    status: str = "planned"
    blocked_reason: str = ""


class AgentPlannerResponse(BaseModel):
    plan_id: UUID = Field(default_factory=uuid4)
    user_id: UUID
    goal: str
    autonomy_level: str
    ready_to_execute: bool
    steps: list[AgentPlanStep]
    policy_warnings: list[str]
    # Local (client) + backend context merged and tagged by source.
    decision_context_pack: list[ContextItem] = Field(default_factory=list)
    tool_result_feedback_needed: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class PrivacyExportResponse(BaseModel):
    user_id: UUID
    export_id: UUID = Field(default_factory=uuid4)
    included_sections: list[str]
    download_ready: bool
    summary: dict[str, Any]
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class PrivacyDeleteRequest(BaseModel):
    user_id: UUID = Field(default_factory=uuid4)
    scopes: list[str] = Field(default_factory=list, max_length=20)
    confirm: bool = False


class PrivacyDeleteResponse(BaseModel):
    user_id: UUID
    accepted: bool
    deleted_scopes: list[str]
    blocked_reasons: list[str]
    audit_event: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
