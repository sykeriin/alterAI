import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../council/application/five_persona_council.dart';
import '../../memory/application/memory_store.dart';
import '../../proactive/application/briefing_controller.dart';
import '../application/decision_council_controller.dart';

final councilAmbientProvider =
    NotifierProvider<CouncilAmbientController, CouncilAmbientState>(
  CouncilAmbientController.new,
);

class CouncilAmbientState {
  const CouncilAmbientState({
    this.warmedTopic = '',
    this.shouldShowPulse = false,
  });

  final String warmedTopic;
  final bool shouldShowPulse;

  CouncilAmbientState copyWith({
    String? warmedTopic,
    bool? shouldShowPulse,
  }) =>
      CouncilAmbientState(
        warmedTopic: warmedTopic ?? this.warmedTopic,
        shouldShowPulse: shouldShowPulse ?? this.shouldShowPulse,
      );
}

/// Watches memories/briefing and pre-warms council context when a decision signal appears.
class CouncilAmbientController extends Notifier<CouncilAmbientState> {
  @override
  CouncilAmbientState build() {
    ref.listen(briefingControllerProvider, (_, next) => _evaluate());
    ref.listen(memoryStoreProvider, (_, __) => _evaluate());
    Future.microtask(_evaluate);
    return const CouncilAmbientState();
  }

  void _evaluate() {
    final briefing = ref.read(briefingControllerProvider).asData?.value;
    final memories = ref.read(memoryStoreProvider).asData?.value ?? const [];
    final candidates = <String>[
      ...?briefing?.commitments,
      ...?briefing?.patterns,
      ...memories.take(3).map((m) => m.title),
    ];
    for (final c in candidates) {
      if (FivePersonaCouncil.shouldDeliberate(c)) {
        state = CouncilAmbientState(
          warmedTopic: c,
          shouldShowPulse: true,
        );
        ref.read(decisionCouncilProvider.notifier).seed(c);
        return;
      }
    }
    state = const CouncilAmbientState();
  }
}
