import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_provider.dart';
import '../domain/simulations.dart';

/// DayTwinEngine — builds a living model of the day: Default / Risk / Optimized
/// paths, pressure points, and the single next best move. Cloud-structured when
/// available; otherwise the screen reports that a reasoning backend is needed.
final dayTwinControllerProvider =
    NotifierProvider<DayTwinController, DayTwinState>(DayTwinController.new);

class DayTwinState {
  const DayTwinState({
    this.input = '',
    this.isSimulating = false,
    this.result,
    this.error = '',
  });

  final String input;
  final bool isSimulating;
  final DayTwinResult? result;
  final String error;

  DayTwinState copyWith({
    String? input,
    bool? isSimulating,
    DayTwinResult? result,
    String? error,
  }) => DayTwinState(
    input: input ?? this.input,
    isSimulating: isSimulating ?? this.isSimulating,
    result: result ?? this.result,
    error: error ?? this.error,
  );
}

class DayTwinController extends Notifier<DayTwinState> {
  @override
  DayTwinState build() => const DayTwinState();

  void setInput(String v) => state = state.copyWith(input: v, error: '');

  /// Seed the day context from another surface (e.g. a routed moment).
  void seed(String context) => state = DayTwinState(input: context);

  Future<void> simulate() async {
    final ctx = state.input.trim();
    if (ctx.length < 6) {
      state = state.copyWith(
        error: 'Describe today (plans, deadlines, commute).',
      );
      return;
    }

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      state = state.copyWith(
        error:
            'Connect the backend or sign in with AI access to simulate DayTwin.',
      );
      return;
    }

    state = state.copyWith(isSimulating: true, error: '');
    try {
      final profile = ref.read(userProfileProvider).asData?.value;
      final who = profile == null || profile.displayName.isEmpty
          ? ''
          : 'Operator: ${profile.displayName}'
                '${profile.role.isNotEmpty ? ', ${profile.role}' : ''}. ';
      final raw = await openai.chat(
        jsonMode: true,
        temperature: 0.5,
        maxTokens: 1600,
        messages: [
          {'role': 'system', 'content': _system()},
          {'role': 'user', 'content': '${who}Today: $ctx'},
        ],
      );
      final json = jsonDecode(_strip(raw)) as Map<String, dynamic>;
      state = state.copyWith(
        isSimulating: false,
        result: DayTwinResult.fromJson(json, cloud: true),
      );
    } catch (e) {
      state = state.copyWith(
        isSimulating: false,
        error:
            'DayTwin simulation failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String _system() =>
      'You are ALTER DayTwin, the day-modeling layer of an iQOO phone. From the '
      'user\'s description of today, build three timelines and the single next '
      'best move. Be concrete and time-stamped. Respond with ONLY JSON:\n'
      '{\n'
      '  "headline": string,\n'
      '  "pressure_points": [string],\n'
      '  "next_best_move": string,\n'
      '  "paths": [\n'
      '    {"type": "default" | "risk" | "optimized", "summary": string, "day_score": number,\n'
      '     "blocks": [ {"time": string, "title": string, "note": string, "stress": number} ] }\n'
      '  ]\n'
      '}\n'
      'Provide exactly 3 paths (default, risk, optimized), each with 3-5 blocks. '
      'Scores and stress are 0..1. next_best_move is one actionable sentence.';

  String _strip(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '');
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}
