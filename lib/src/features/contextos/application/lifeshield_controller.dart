import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../data/local/contextos_dao.dart';
import '../../../data/local/dao_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../../data/gateway/alter_gateway_providers.dart';
import '../../profile/application/profile_provider.dart';
import '../data/context_engine.dart';
import '../../memory/application/memory_encode_pipeline.dart';
import '../data/moment_classifier.dart';
import '../data/moment_interceptor.dart';
import '../domain/contextos_models.dart';
import '../domain/moment.dart';
import 'gemma_model_manager.dart';
import 'memory_engine.dart';

final lifeShieldControllerProvider =
    NotifierProvider<LifeShieldController, LifeShieldState>(
      LifeShieldController.new,
    );

class LifeShieldState {
  const LifeShieldState({
    this.input = '',
    this.source = MomentSource.notification,
    this.privateMode = false,
    this.isAnalyzing = false,
    this.moment,
    this.extraction = const _EmptyExtraction(),
    this.category,
    this.triage,
    this.analysis,
    this.needsCloud = false,
    this.error = '',
    this.momentId,
    this.trustedMatch,
  });

  final String input;
  final MomentSource source;
  final bool privateMode;
  final bool isAnalyzing;
  final Moment? moment;
  final ContextExtraction extraction;
  final MomentCategory? category;
  final EdgeTriage? triage;
  final MomentAnalysis? analysis;
  final bool needsCloud;
  final String error;
  final String? momentId;

  /// Non-null when the moment matched a source the user has marked trusted.
  final String? trustedMatch;

  bool get hasMoment => moment != null;
  bool get hasResult => analysis != null;
  bool get routedElsewhere => category?.isRoutedElsewhere ?? false;

  String get cloudPreview => triage?.redactedText ?? '';
  List<String> get redactedFields => triage?.redactedFields ?? const [];

  LifeShieldState copyWith({
    String? input,
    MomentSource? source,
    bool? privateMode,
    bool? isAnalyzing,
    Moment? moment,
    ContextExtraction? extraction,
    MomentCategory? category,
    EdgeTriage? triage,
    MomentAnalysis? analysis,
    bool? needsCloud,
    String? error,
    String? momentId,
    String? trustedMatch,
    bool clearResult = false,
  }) {
    return LifeShieldState(
      input: input ?? this.input,
      source: source ?? this.source,
      privateMode: privateMode ?? this.privateMode,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      moment: clearResult ? moment : (moment ?? this.moment),
      extraction: extraction ?? this.extraction,
      category: clearResult ? category : (category ?? this.category),
      triage: triage ?? this.triage,
      analysis: clearResult ? analysis : (analysis ?? this.analysis),
      needsCloud: needsCloud ?? this.needsCloud,
      error: error ?? this.error,
      momentId: momentId ?? this.momentId,
      trustedMatch: clearResult
          ? trustedMatch
          : (trustedMatch ?? this.trustedMatch),
    );
  }
}

/// A tiny const empty extraction so the state field can stay non-null.
class _EmptyExtraction extends ContextExtraction {
  const _EmptyExtraction()
    : super(
        entities: const [],
        requestedAction: '',
        deadline: '',
        risks: const {},
        sensitiveDataRequest: false,
        missingInfo: const [],
        confidence: 0,
        cloudEnriched: false,
      );
}

class LifeShieldController extends Notifier<LifeShieldState> {
  @override
  LifeShieldState build() => const LifeShieldState();

  void setInput(String value) =>
      state = state.copyWith(input: value, error: '');

  void setSource(MomentSource source) => state = state.copyWith(source: source);

  void togglePrivateMode() =>
      state = state.copyWith(privateMode: !state.privateMode);

  void reset() => state = const LifeShieldState();

  /// Sense → Intercept → Edge Check → Understand → Classify (all on-device).
  Future<void> capture() async {
    final input = state.input.trim();
    if (input.length < 4) {
      state = state.copyWith(error: 'Paste or pick a moment to analyze.');
      return;
    }

    // 1. Intercept into a Moment object.
    final interceptor = ref.read(momentInterceptorProvider);
    var moment = interceptor.intake(state.source, input);
    if (state.privateMode) {
      moment = moment.copyWith(privacyLevel: PrivacyLevel.private);
    }

    // 2. Edge check: redact + triage (Gemma 4 when loaded, else pattern check).
    final engine = ref.read(localGemmaEngineProvider);
    final triage = await engine.analyzeAsync(moment.rawContent);

    // 3. Understand (ContextEngine local extraction).
    final ctx = ref.read(contextEngineProvider).extractLocal(moment);

    // 4. Classify + route.
    var category = ref
        .read(momentClassifierProvider)
        .classify(moment, triage, ctx);

    // 4b. MemoryEngine — a source the user trusts mutes non-critical warnings.
    // Hard danger (OTP/money/scam) is NEVER muted, even for a trusted source.
    final trusted = ref.read(memoryProvider).asData?.value ?? const [];
    final trustedMatch = MemoryEngine.matchIn(trusted, moment.rawContent);
    final hardDanger =
        triage.coarseVerdict == RiskVerdict.dangerous ||
        (ctx.risks['Identity'] ?? 0) >= 0.8 ||
        (ctx.risks['Money'] ?? 0) >= 0.8;

    var effTriage = triage;
    if (trustedMatch != null &&
        !hardDanger &&
        category.handledByLifeShield &&
        triage.coarseVerdict != RiskVerdict.safe) {
      effTriage = EdgeTriage(
        redactedText: triage.redactedText,
        redactedFields: triage.redactedFields,
        coarseVerdict: RiskVerdict.safe,
        signals: triage.signals,
        shouldEscalate: false,
        summary:
            'From a source you trust ($trustedMatch) — '
            'non-critical risk muted on-device.',
      );
      category = MomentCategory.safeInfo;
    }

    final handles = category.handledByLifeShield;
    final wantsCloud =
        handles && effTriage.shouldEscalate && !state.privateMode;

    state = state.copyWith(
      moment: moment,
      triage: effTriage,
      extraction: ctx,
      category: category,
      analysis: handles
          ? _edgeOnlyAnalysis(effTriage, state.privateMode)
          : null,
      needsCloud: wantsCloud,
      error: '',
      trustedMatch: trustedMatch,
      clearResult: true,
    );

    final momentId = await _persistMoment(moment, triage);
    state = state.copyWith(momentId: momentId);
    await _audit(
      momentId,
      'capture',
      '${moment.sourceSurface.label} → ${category.label}',
    );
    if (triage.redactedFields.isNotEmpty) {
      await _audit(
        momentId,
        'redaction',
        'Redacted on-device: ${triage.redactedFields.join(', ')}',
      );
    }

    await ref.read(memoryEncodePipelineProvider).process(
          rawContent: moment.rawContent,
          provenance: moment.sourceSurface.label,
          momentCategory: category,
          title: category.label,
        );

    if (handles && !wantsCloud) {
      await _persistAnalysis(momentId, state.analysis!);
    }
    await _ingestMomentToGateway(moment, category, triage);
  }

  Future<void> _ingestMomentToGateway(
    Moment moment,
    MomentCategory category,
    EdgeTriage triage,
  ) async {
    if (!AlterGatewayConfig.isConfigured) return;
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(alterGatewayApiClientProvider).ingestData(
            userId: userId,
            source: moment.sourceSurface.label,
            items: <Map<String, Object>>[
              <String, Object>{
                'title': category.label,
                'summary': triage.summary,
                'category': category.label,
                'verdict': triage.coarseVerdict.name,
              },
            ],
          );
    } catch (_) {}
  }

  /// Decide → escalate to cloud reasoning (the consent boundary).
  Future<void> runCloud() async {
    final triage = state.triage;
    if (triage == null) return;

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      state = state.copyWith(
        error:
            'Cloud reasoning unavailable — sign in or set an OpenAI key. '
            'Showing on-device result only.',
        needsCloud: false,
      );
      return;
    }

    state = state.copyWith(isAnalyzing: true, error: '');
    await _audit(
      state.momentId,
      'cloud_escalation',
      'Sent redacted moment for deep reasoning',
    );

    try {
      final raw = await openai.chat(
        jsonMode: true,
        temperature: 0.3,
        maxTokens: 1600,
        messages: [
          {'role': 'system', 'content': _systemPrompt()},
          {'role': 'user', 'content': _userPrompt(triage)},
        ],
      );
      final json = jsonDecode(_strip(raw)) as Map<String, dynamic>;

      final analysis = MomentAnalysis.fromJson(
        json,
        edgeSummary: triage.summary,
        cloudUsed: true,
        edgeState: EdgeState.cloud,
        redactedFields: triage.redactedFields,
      );
      final enriched = json['context'] is Map
          ? state.extraction.mergeCloud(
              Map<String, dynamic>.from(json['context'] as Map),
            )
          : state.extraction;

      state = state.copyWith(
        isAnalyzing: false,
        analysis: analysis,
        extraction: enriched,
        needsCloud: false,
      );
      await _audit(
        state.momentId,
        'analysis',
        'Cloud verdict: ${analysis.verdict.label} (${(analysis.confidence * 100).round()}%)',
      );
      await _persistAnalysis(state.momentId, analysis);
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        needsCloud: false,
        error:
            'Cloud reasoning failed: '
            '${e.toString().replaceFirst('Exception: ', '')}. Using on-device result.',
      );
    }
  }

  MomentAnalysis _edgeOnlyAnalysis(EdgeTriage t, bool privateMode) {
    return MomentAnalysis(
      verdict: t.coarseVerdict,
      riskScore: switch (t.coarseVerdict) {
        RiskVerdict.dangerous => 0.9,
        RiskVerdict.needsVerification => 0.6,
        RiskVerdict.caution => 0.4,
        RiskVerdict.safe => 0.1,
      },
      headline: switch (t.coarseVerdict) {
        RiskVerdict.dangerous => 'On-device: likely scam / unsafe action',
        RiskVerdict.needsVerification => 'On-device: verify before you act',
        RiskVerdict.caution => 'On-device: read carefully',
        RiskVerdict.safe => 'On-device: no obvious risk',
      },
      whyItMatters: t.summary,
      facts: const [],
      redFlags: t.signals,
      assumptions: const [
        'Based on on-device pattern matching only — no cloud reasoning applied.',
      ],
      missingInfo: t.shouldEscalate
          ? const ['Cloud reasoning can add context, consequences, and proof.']
          : const [],
      whatCouldMakeWrong:
          'On-device triage is fast but shallow; subtle or novel scams may slip past.',
      verificationSteps: t.coarseVerdict == RiskVerdict.safe
          ? const []
          : const [
              'Contact the company via its official app or printed number.',
              'Never share OTPs, PINs, or passwords with anyone.',
            ],
      confidence: 0.55,
      edgeSummary: t.summary,
      actions: const [],
      cloudUsed: false,
      edgeState: privateMode ? EdgeState.private : EdgeState.edge,
      redactedFields: t.redactedFields,
    );
  }

  // --- Persistence (best-effort) ---
  Future<String?> _persistMoment(Moment m, EdgeTriage t) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return null;
    try {
      final excerpt = t.redactedText.length > 400
          ? t.redactedText.substring(0, 400)
          : t.redactedText;
      final saved = await ref.read(contextOsDaoProvider).insertCapturedMoment(
            CapturedMomentRecord(
              id: '',
              userId: userId,
              sourceSurface: m.sourceSurface.id,
              sourceType: m.sourceType,
              rawExcerpt: excerpt,
              redactedText: t.redactedText,
              privateMode: state.privateMode,
              createdAt: DateTime.now(),
            ),
          );
      return saved.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistAnalysis(String? momentId, MomentAnalysis a) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      final dao = ref.read(contextOsDaoProvider);
      await dao.insertRiskAnalysis(
        RiskAnalysisRecord(
          id: '',
          momentId: momentId,
          userId: userId,
          verdict: a.verdict.id,
          riskScore: a.riskScore,
          headline: a.headline,
          whyItMatters: a.whyItMatters,
          facts: a.facts,
          redFlags: a.redFlags,
          assumptions: a.assumptions,
          missingInfo: a.missingInfo,
          whatCouldMakeWrong: a.whatCouldMakeWrong,
          verificationSteps: a.verificationSteps,
          confidence: a.confidence,
          edgeSummary: a.edgeSummary,
          cloudUsed: a.cloudUsed,
          createdAt: DateTime.now(),
        ),
      );
      if (a.actions.isNotEmpty && momentId != null) {
        for (final act in a.actions) {
          await dao.insertAlterAction(
            AlterActionRecord(
              id: '',
              momentId: momentId,
              userId: userId,
              actionType: act.type,
              title: act.title,
              detail: act.detail,
              requiresConfirmation: act.requiresConfirmation,
              irreversible: act.irreversible,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _audit(String? momentId, String kind, String detail) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(contextOsDaoProvider).insertAuditEvent(
            AuditEventRecord(
              id: '',
              userId: userId,
              momentId: momentId,
              kind: kind,
              detail: detail,
              edgeState: state.privateMode ? 'private' : 'edge',
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  String _strip(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '');
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  String _systemPrompt() {
    return 'You are ALTER LifeShield, the decision-safety layer of an iQOO '
        'phone. You analyze a captured phone "moment" (a message, link, QR, '
        'install/permission screen, call transcript, or payment prompt) that '
        'has ALREADY been redacted of sensitive data on-device. Decide whether '
        'it is safe to act on, prove your reasoning, and extract structured '
        'context. You are not a chatbot; be terse, concrete, and protective. '
        'Never invent facts not present in the input. Do not give final '
        'medical/legal/financial decisions — recommend verification instead. '
        'Respond with ONLY a JSON object:\n'
        '{\n'
        '  "verdict": "safe" | "caution" | "dangerous" | "needs_verification",\n'
        '  "risk_score": number,            // 0..1\n'
        '  "headline": string,              // <= 8 words, what to do\n'
        '  "why_it_matters": string,\n'
        '  "facts": [string],\n'
        '  "red_flags": [string],\n'
        '  "assumptions": [string],\n'
        '  "missing_info": [string],\n'
        '  "what_could_make_wrong": string,\n'
        '  "verification_steps": [string],\n'
        '  "confidence": number,            // 0..1\n'
        '  "context": {\n'
        '     "entities": [string], "requested_action": string, "deadline": string,\n'
        '     "risks": {"money": number, "identity": number, "permission": number, "link": number, "qr": number, "location": number, "urgency": number},\n'
        '     "sensitive_data_request": boolean, "missing_info": [string], "confidence": number\n'
        '  },\n'
        '  "actions": [ {"type": string, "title": string, "detail": string, "requires_confirmation": boolean, "irreversible": boolean} ]\n'
        '}\n'
        'Action types: draft_reply, reminder, checklist, open_official_app, '
        'call_verified, save_evidence, share_warning, block, safe_ignore. '
        'Mark anything that sends/pays/installs requires_confirmation=true and '
        'irreversible=true. Provide 2-4 actions, safest first.';
  }

  String _userPrompt(EdgeTriage t) {
    final cat = state.category?.label ?? 'unknown';
    return 'Source surface: ${state.source.label}\n'
        'On-device classification: $cat\n'
        'On-device triage: ${t.coarseVerdict.label} '
        '(${t.signals.isEmpty ? 'no signals' : t.signals.join('; ')})\n'
        'Redacted moment:\n"""\n${t.redactedText}\n"""';
  }
}
