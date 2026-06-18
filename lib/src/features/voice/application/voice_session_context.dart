import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceSessionTurn {
  const VoiceSessionTurn({
    required this.userTranscript,
    required this.assistantSummary,
  });

  final String userTranscript;
  final String assistantSummary;
}

/// Short-term buffer for multi-turn voice query expansion (not persisted).
class VoiceSessionContext extends Notifier<List<VoiceSessionTurn>> {
  static const maxTurns = 5;

  @override
  List<VoiceSessionTurn> build() => const [];

  void record({
    required String userTranscript,
    required String assistantSummary,
  }) {
    final next = [
      ...state,
      VoiceSessionTurn(
        userTranscript: userTranscript.trim(),
        assistantSummary: assistantSummary.trim(),
      ),
    ];
    if (next.length > maxTurns) {
      state = next.sublist(next.length - maxTurns);
    } else {
      state = next;
    }
  }

  void clear() => state = const [];

  /// Keywords from recent turns for memory retrieval expansion.
  String expansionPrefix({String? displayName, String? role}) {
    final parts = <String>[];
    if (displayName != null && displayName.isNotEmpty) {
      parts.add(displayName);
    }
    if (role != null && role.isNotEmpty) parts.add(role);
    for (final turn in state) {
      parts.add(turn.userTranscript);
    }
    return parts.join(' ');
  }
}

final voiceSessionContextProvider =
    NotifierProvider<VoiceSessionContext, List<VoiceSessionTurn>>(
  VoiceSessionContext.new,
);
