import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_provider.dart';
import '../domain/council.dart';

/// DecisionCouncil — convenes five inner voices (Practical / Risk / Future /
/// Skeptic / Action Me) for important moments only, then synthesizes consensus,
/// a recommendation, and the strongest dissent. One structured cloud call;
/// otherwise the screen reports that a reasoning backend is needed.
final decisionCouncilProvider =
    NotifierProvider<DecisionCouncilController, CouncilState>(
      DecisionCouncilController.new,
    );

class CouncilState {
  const CouncilState({
    this.topic = '',
    this.isConvening = false,
    this.result,
    this.error = '',
  });

  final String topic;
  final bool isConvening;
  final CouncilResult? result;
  final String error;

  CouncilState copyWith({
    String? topic,
    bool? isConvening,
    CouncilResult? result,
    String? error,
  }) => CouncilState(
    topic: topic ?? this.topic,
    isConvening: isConvening ?? this.isConvening,
    result: result ?? this.result,
    error: error ?? this.error,
  );
}

class DecisionCouncilController extends Notifier<CouncilState> {
  @override
  CouncilState build() => const CouncilState();

  void setTopic(String v) => state = state.copyWith(topic: v, error: '');

  void seed(String topic) => state = CouncilState(topic: topic);

  Future<void> convene() async {
    final topic = state.topic.trim();
    if (topic.length < 6) {
      state = state.copyWith(error: 'Give the council something to weigh.');
      return;
    }

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      state = state.copyWith(
        error:
            'Connect the backend or sign in with AI access to convene the council.',
      );
      return;
    }

    state = state.copyWith(isConvening: true, error: '');
    try {
      final profile = ref.read(userProfileProvider).asData?.value;
      final who = profile == null || profile.displayName.isEmpty
          ? ''
          : 'The person is ${profile.displayName}'
                '${profile.role.isNotEmpty ? ', ${profile.role}' : ''}. ';
      final raw = await openai.chat(
        jsonMode: true,
        temperature: 0.7,
        maxTokens: 1700,
        messages: [
          {'role': 'system', 'content': _system()},
          {'role': 'user', 'content': '${who}Decision/moment: $topic'},
        ],
      );
      final json = jsonDecode(_strip(raw)) as Map<String, dynamic>;
      state = state.copyWith(
        isConvening: false,
        result: CouncilResult.fromJson(json, cloud: true),
      );
    } catch (e) {
      state = state.copyWith(
        isConvening: false,
        error:
            'Council unavailable: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String _system() =>
      'You are ALTER\'s DecisionCouncil. Convene FIVE distinct inner voices to '
      'weigh the user\'s decision or moment, then synthesize. The voices are:\n'
      '- practical (Practical Me): the sensible, get-it-done view.\n'
      '- risk (Risk Me): guards the downside, worst-case.\n'
      '- future (Future Me): thinks in years, second-order effects.\n'
      '- skeptic (Skeptic Me): distrusts framing, asks what is unsaid.\n'
      '- action (Action Me): turns it into concrete next moves.\n'
      'Each voice must genuinely differ. Do not give final medical/legal/'
      'financial decisions — frame as perspectives. Respond with ONLY JSON:\n'
      '{\n'
      '  "voices": [ {"agent": "practical"|"risk"|"future"|"skeptic"|"action", "stance": string, "take": string, "confidence": number} ],\n'
      '  "consensus": string,\n'
      '  "recommendation": string,\n'
      '  "dissent": string\n'
      '}\n'
      'Exactly 5 voices, one per agent. stance is <= 8 words. confidence 0..1. '
      'dissent names the strongest disagreement.';

  String _strip(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '');
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}
