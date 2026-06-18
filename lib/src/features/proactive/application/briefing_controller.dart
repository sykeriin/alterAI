import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../memory/application/memory_store.dart';

class DailyBriefing {
  const DailyBriefing({
    required this.headline,
    required this.commitments,
    required this.relationships,
    required this.patterns,
    required this.memoryCitations,
  });

  final String headline;
  final List<String> commitments;
  final List<String> relationships;
  final List<String> patterns;
  final List<String> memoryCitations;
}

final briefingControllerProvider =
    AsyncNotifierProvider<BriefingController, DailyBriefing>(
  BriefingController.new,
);

/// Proactive daily briefing from stored memories (Stage 5).
class BriefingController extends AsyncNotifier<DailyBriefing> {
  @override
  Future<DailyBriefing> build() async {
    ref.watch(memoryStoreProvider);
    return _compose();
  }

  Future<DailyBriefing> _compose() async {
    final memories = ref.read(memoryStoreProvider).asData?.value ?? const [];

    final commitments = memories
        .take(5)
        .map((m) => m.title.isNotEmpty ? m.title : m.content)
        .toList();

    final relationships = memories
        .where((m) => m.kind.name == 'relationship')
        .take(3)
        .map((m) => m.content)
        .toList();

    final patterns = memories
        .where((m) => m.kind.name == 'routine' || m.kind.name == 'preference')
        .take(3)
        .map((m) => m.content)
        .toList();

    final citations = memories
        .take(5)
        .map((m) => m.title)
        .where((t) => t.isNotEmpty)
        .toList();

    final hasData = commitments.isNotEmpty ||
        relationships.isNotEmpty ||
        patterns.isNotEmpty ||
        citations.isNotEmpty;

    return DailyBriefing(
      headline: hasData
          ? 'Here is what ALTER remembers that matters today.'
          : 'Still inferring from your activity…',
      commitments: commitments,
      relationships: relationships,
      patterns: patterns,
      memoryCitations: citations,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _compose());
  }
}
