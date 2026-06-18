import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../profile/application/profile_provider.dart';
import '../data/mission_control_api_client.dart';
import '../domain/mission_control_models.dart';
import 'mission_ai.dart';

const _kNoAiMessage =
    'Sign in to run Mission Control intelligence. Connect the ALTER gateway or add an AI key in Settings.';

/// Returns a [MissionAi] bound to the gateway (when configured) and/or OpenAI.
MissionAi? _missionAi(Ref ref) {
  final openai = ref.read(openAIServiceProvider);
  final gateway = AlterGatewayConfig.isConfigured
      ? ref.read(missionControlApiClientProvider)
      : null;
  if (openai == null && gateway == null) return null;
  final profile = ref.read(userProfileProvider).asData?.value;
  return MissionAi(openai, profile, gateway: gateway);
}

/// Self-hosted Mission Control gateway. Defaults to the deployed ALTER gateway
/// URL; override with `--dart-define=ALTER_API_GATEWAY_URL=...`.

final missionControlApiClientProvider = Provider<MissionControlApiClient>((
  ref,
) {
  final client = MissionControlApiClient(
    baseUrl: AlterGatewayConfig.normalizedBaseUrl,
  );
  ref.onDispose(client.close);
  return client;
});

final missionControlProvider = FutureProvider<MissionControlSnapshot>((ref) {
  if (!AlterGatewayConfig.isConfigured) {
    return fallbackMissionControlSnapshot;
  }
  return ref
      .watch(missionControlApiClientProvider)
      .loadSnapshot(fallbackMissionControlSnapshot);
});

final missionDemoControllerProvider =
    NotifierProvider<MissionDemoController, MissionDemoState>(
      MissionDemoController.new,
    );

final intelligenceKernelControllerProvider =
    NotifierProvider<IntelligenceKernelController, IntelligenceKernelState>(
      IntelligenceKernelController.new,
    );

final futureTwinControllerProvider =
    NotifierProvider<FutureTwinController, FutureTwinState>(
      FutureTwinController.new,
    );

final proofCaptureControllerProvider =
    NotifierProvider<ProofCaptureController, ProofCaptureState>(
      ProofCaptureController.new,
    );

class ProofCaptureController extends Notifier<ProofCaptureState> {
  @override
  ProofCaptureState build() => const ProofCaptureState();

  Future<void> capture({
    required String objective,
    required String linkedGoal,
    required String linkedAction,
    required List<ProofEvidenceInput> evidence,
  }) async {
    final trimmed = objective.trim();
    if (trimmed.length < 3) {
      state = state.copyWith(errorMessage: 'Enter the future objective this proof updates.');
      return;
    }
    if (evidence.isEmpty) {
      state = state.copyWith(errorMessage: 'Add at least one proof item.');
      return;
    }
    final ai = _missionAi(ref);
    if (ai == null) {
      state = state.copyWith(errorMessage: _kNoAiMessage);
      return;
    }
    state = state.copyWith(isRunning: true, errorMessage: '');
    try {
      final result = await ai.captureProof(
        objective: trimmed,
        linkedGoal: linkedGoal.trim(),
        linkedAction: linkedAction.trim(),
        evidence: evidence,
      );
      state = state.copyWith(isRunning: false, result: result);
    } catch (error) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: UserFacingError.from(error).message,
      );
    }
  }
}

class ProofCaptureState {
  const ProofCaptureState({
    this.isRunning = false,
    this.result,
    this.errorMessage = '',
  });

  final bool isRunning;
  final ProofCaptureResult? result;
  final String errorMessage;

  ProofCaptureState copyWith({
    bool? isRunning,
    ProofCaptureResult? result,
    String? errorMessage,
  }) {
    return ProofCaptureState(
      isRunning: isRunning ?? this.isRunning,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FutureTwinController extends Notifier<FutureTwinState> {
  @override
  FutureTwinState build() => const FutureTwinState();

  Future<void> buildTwin({
    required String objective,
    required List<FutureTwinEvidenceInput> evidence,
  }) async {
    final trimmed = objective.trim();
    if (trimmed.length < 3) {
      state = state.copyWith(errorMessage: 'Enter an objective for your Future Twin.');
      return;
    }
    final ai = _missionAi(ref);
    if (ai == null) {
      state = state.copyWith(errorMessage: _kNoAiMessage);
      return;
    }
    state = state.copyWith(isRunning: true, errorMessage: '');
    try {
      final result = await ai.buildTwin(objective: trimmed, evidence: evidence);
      state = state.copyWith(isRunning: false, result: result);
    } catch (error) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: UserFacingError.from(error).message,
      );
    }
  }
}

class FutureTwinState {
  const FutureTwinState({
    this.isRunning = false,
    this.result,
    this.errorMessage = '',
  });

  final bool isRunning;
  final FutureTwinResult? result;
  final String errorMessage;

  FutureTwinState copyWith({
    bool? isRunning,
    FutureTwinResult? result,
    String? errorMessage,
  }) {
    return FutureTwinState(
      isRunning: isRunning ?? this.isRunning,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class IntelligenceKernelController extends Notifier<IntelligenceKernelState> {
  @override
  IntelligenceKernelState build() => const IntelligenceKernelState();

  Future<void> decide(String question) async {
    final trimmed = question.trim();
    if (trimmed.length < 3) {
      state = state.copyWith(errorMessage: 'Enter a decision to reason through.');
      return;
    }
    final ai = _missionAi(ref);
    if (ai == null) {
      state = state.copyWith(errorMessage: _kNoAiMessage);
      return;
    }
    state = state.copyWith(
      isRunning: true,
      errorMessage: '',
      clearOutcomeResult: true,
    );
    try {
      final report = await ai.decide(trimmed);
      state = state.copyWith(isRunning: false, report: report);
    } catch (error) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: UserFacingError.from(error).message,
      );
    }
  }

  Future<void> recordOutcome({
    required bool didIt,
    required String whatHappened,
    required String whatLearned,
    required String successMetricResult,
    required double outcomeScore,
  }) async {
    final report = state.report;
    if (report == null) {
      state = state.copyWith(outcomeErrorMessage: 'Run a decision first.');
      return;
    }
    if (whatHappened.trim().length < 2 ||
        whatLearned.trim().length < 2 ||
        successMetricResult.trim().length < 2) {
      state = state.copyWith(
        outcomeErrorMessage: 'Add what happened, what you learned, and the metric result.',
      );
      return;
    }
    final ai = _missionAi(ref);
    if (ai == null) {
      state = state.copyWith(outcomeErrorMessage: _kNoAiMessage);
      return;
    }
    state = state.copyWith(isSubmittingOutcome: true, outcomeErrorMessage: '');
    try {
      final outcome = await ai.recordOutcome(
        report: report,
        didIt: didIt,
        whatHappened: whatHappened.trim(),
        whatLearned: whatLearned.trim(),
        successMetricResult: successMetricResult.trim(),
        outcomeScore: outcomeScore,
      );
      state = state.copyWith(
        isSubmittingOutcome: false,
        outcomeResult: outcome,
        outcomeErrorMessage: '',
      );
    } catch (error) {
      state = state.copyWith(
        isSubmittingOutcome: false,
        outcomeErrorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class IntelligenceKernelState {
  const IntelligenceKernelState({
    this.isRunning = false,
    this.report,
    this.errorMessage = '',
    this.isSubmittingOutcome = false,
    this.outcomeResult,
    this.outcomeErrorMessage = '',
  });

  final bool isRunning;
  final IntelligenceDecisionReport? report;
  final String errorMessage;
  final bool isSubmittingOutcome;
  final OutcomeUpdateResult? outcomeResult;
  final String outcomeErrorMessage;

  IntelligenceKernelState copyWith({
    bool? isRunning,
    IntelligenceDecisionReport? report,
    String? errorMessage,
    bool? isSubmittingOutcome,
    OutcomeUpdateResult? outcomeResult,
    String? outcomeErrorMessage,
    bool clearOutcomeResult = false,
  }) {
    return IntelligenceKernelState(
      isRunning: isRunning ?? this.isRunning,
      report: report ?? this.report,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmittingOutcome: isSubmittingOutcome ?? this.isSubmittingOutcome,
      outcomeResult: clearOutcomeResult
          ? null
          : outcomeResult ?? this.outcomeResult,
      outcomeErrorMessage: outcomeErrorMessage ?? this.outcomeErrorMessage,
    );
  }
}

class MissionDemoController extends Notifier<MissionDemoState> {
  @override
  MissionDemoState build() => const MissionDemoState();

  Future<void> run(String objective) async {
    final trimmed = objective.trim();
    if (trimmed.length < 2) {
      state = state.copyWith(errorMessage: 'Enter a decision to simulate.');
      return;
    }
    final ai = _missionAi(ref);
    if (ai == null) {
      state = state.copyWith(errorMessage: _kNoAiMessage);
      return;
    }
    state = state.copyWith(isRunning: true, errorMessage: '');
    try {
      final result = await ai.runDemo(trimmed);
      state = state.copyWith(isRunning: false, result: result);
    } catch (error) {
      state = state.copyWith(
        isRunning: false,
        errorMessage: UserFacingError.from(error).message,
      );
    }
  }
}

class MissionDemoState {
  const MissionDemoState({
    this.isRunning = false,
    this.result,
    this.errorMessage = '',
  });

  final bool isRunning;
  final MissionDemoRun? result;
  final String errorMessage;

  MissionDemoState copyWith({
    bool? isRunning,
    MissionDemoRun? result,
    String? errorMessage,
  }) {
    return MissionDemoState(
      isRunning: isRunning ?? this.isRunning,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

const fallbackMissionControlSnapshot = MissionControlSnapshot(
  operatorName: '',
  activeObjective: '',
  readiness: 0,
  phoneModules: [],
  laptopModules: [],
  metrics: [],
  events: [],
);
