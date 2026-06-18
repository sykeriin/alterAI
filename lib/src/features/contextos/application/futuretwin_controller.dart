import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../data/gateway/gateway_intelligence_bridge.dart';
import '../../../data/gateway/gateway_profile_context.dart';
import '../../mission/application/mission_control_provider.dart';
import '../../profile/application/profile_provider.dart';
import '../domain/simulations.dart';

/// FutureTwinEngine — for bigger decisions: Safe / Smart / Bold paths with
/// effort, risk, upside, regret, and a roadmap, plus a regret-minimizing
/// recommendation. Cloud-structured when available; on-device sample otherwise.
final futureTwinControllerProvider =
    NotifierProvider<FutureTwinController, FutureTwinState>(
        FutureTwinController.new);

class FutureTwinState {
  const FutureTwinState({
    this.input = '',
    this.isSimulating = false,
    this.result,
    this.error = '',
  });

  final String input;
  final bool isSimulating;
  final FutureTwinResult? result;
  final String error;

  FutureTwinState copyWith({
    String? input,
    bool? isSimulating,
    FutureTwinResult? result,
    String? error,
  }) =>
      FutureTwinState(
        input: input ?? this.input,
        isSimulating: isSimulating ?? this.isSimulating,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

class FutureTwinController extends Notifier<FutureTwinState> {
  @override
  FutureTwinState build() => const FutureTwinState();

  void setInput(String v) => state = state.copyWith(input: v, error: '');

  void seed(String decision) => state = FutureTwinState(input: decision);

  Future<void> simulate() async {
    final q = state.input.trim();
    if (q.length < 6) {
      state = state.copyWith(error: 'Describe the decision you are weighing.');
      return;
    }

    if (AlterGatewayConfig.isConfigured) {
      state = state.copyWith(isSimulating: true, error: '');
      try {
        final profile = ref.read(userProfileProvider).asData?.value;
        final report = await ref.read(missionControlApiClientProvider).decide(
              question: q,
              userProfile: GatewayProfileContext.userProfile(profile),
              skills: GatewayProfileContext.skills(profile),
              goals: GatewayProfileContext.goals(profile),
              interests: GatewayProfileContext.interests(profile),
            );
        state = state.copyWith(
          isSimulating: false,
          result: futureTwinFromDecision(report, question: q),
        );
        return;
      } catch (_) {
        // Fall through to OpenAI below.
      }
    }

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      state = state.copyWith(
        isSimulating: false,
        error: 'Sign in and add an OpenAI key to simulate futures.',
      );
      return;
    }

    state = state.copyWith(isSimulating: true, error: '');
    try {
      final profile = ref.read(userProfileProvider).asData?.value;
      final who = profile == null || profile.displayName.isEmpty
          ? ''
          : 'Operator: ${profile.displayName}'
              '${profile.role.isNotEmpty ? ', ${profile.role}' : ''}'
              '${profile.goals.isNotEmpty ? '. Goals: ${profile.goals.join(', ')}' : ''}. ';
      final raw = await openai.chat(
        jsonMode: true,
        temperature: 0.55,
        maxTokens: 1700,
        messages: [
          {'role': 'system', 'content': _system()},
          {'role': 'user', 'content': '${who}Decision: $q'},
        ],
      );
      final json = jsonDecode(_strip(raw)) as Map<String, dynamic>;
      state = state.copyWith(
        isSimulating: false,
        result: FutureTwinResult.fromJson(json, cloud: true),
      );
    } catch (e) {
      state = state.copyWith(
        isSimulating: false,
        error: 'Simulation failed (${e.toString().replaceFirst('Exception: ', '')}).',
      );
    }
  }

  String _system() =>
      'You are ALTER FutureTwin, the decision-simulation layer of an iQOO '
      'phone. For the user\'s decision, simulate three honest futures and '
      'recommend the regret-minimizing one. Do not give final '
      'medical/legal/financial advice — frame as scenarios. Respond with ONLY '
      'JSON:\n'
      '{\n'
      '  "headline": string,\n'
      '  "summary": string,\n'
      '  "recommended": "safe" | "smart" | "bold",\n'
      '  "regret_minimizer": string,\n'
      '  "paths": [\n'
      '    {"type": "safe" | "smart" | "bold", "thesis": string,\n'
      '     "effort": number, "risk": number, "upside": number, "regret": number,\n'
      '     "roadmap": [string] }\n'
      '  ]\n'
      '}\n'
      'Provide exactly 3 paths (safe, smart, bold). All scores 0..1. Each '
      'roadmap has 3 concrete steps.';

  String _strip(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '');
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}
