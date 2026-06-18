import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contextos/domain/moment.dart';
import '../application/memory_classifier.dart';
import '../application/memory_lifecycle.dart';
import '../application/memory_store.dart';
import '../../../data/local/dao_providers.dart';
import '../domain/memory_item.dart';

final memoryEncodePipelineProvider = Provider<MemoryEncodePipeline>((ref) {
  return MemoryEncodePipeline(ref);
});

/// Encode → stabilize → store → forget raw (memory core loop).
class MemoryEncodePipeline {
  MemoryEncodePipeline(this._ref);

  final Ref _ref;
  final _classifier = const MemoryClassifierService();

  Future<MemoryItem?> process({
    required String rawContent,
    required String provenance,
    MomentCategory? momentCategory,
    String? title,
    bool abstractFirst = true,
  }) async {
    final lifecycle = _ref.read(memoryLifecycleProvider.notifier);
    lifecycle.setStage(MemoryLifecycleStage.encoding, message: 'Classifying…');

    final classification = _classifier.classify(
      rawContent: rawContent,
      provenance: provenance,
      momentCategory: momentCategory,
    );

    if (!classification.shouldRemember) {
      lifecycle.idle();
      return null;
    }

    lifecycle.setStage(MemoryLifecycleStage.stabilizing, message: 'Abstracting…');
    final abstracted = abstractFirst
        ? _abstract(rawContent)
        : rawContent;

    lifecycle.setStage(MemoryLifecycleStage.storing, message: 'Saving…');
    final saved = await _ref.read(memoryStoreProvider.notifier).encode(
          draft: MemoryItem(
            userId: '',
            kind: classification.kind,
            title: title ?? _titleFrom(classification.kind),
            content: abstracted,
            provenance: provenance,
            confidence: classification.confidence,
            sensitivity: classification.sensitivity,
            retention: classification.retention,
          ),
          classification: classification,
        );

    if (saved != null) {
      await _ref.read(embeddingDaoProvider).upsert(
            memoryId: saved.id,
            abstractText: abstracted,
            kind: classification.kind.name,
          );
    }

    lifecycle.setStage(MemoryLifecycleStage.updating, message: 'Indexed');
    lifecycle.idle();
    return saved;
  }

  /// After voice turn: abstract user+assistant exchange, store fact, discard raw.
  Future<void> processVoiceTurn({
    required String userTranscript,
    required String assistantSummary,
    required String intent,
  }) async {
    final combined =
        'Voice intent=$intent. User asked about: ${_oneLine(userTranscript)}. '
        'Alter responded: ${_oneLine(assistantSummary)}';
    await process(
      rawContent: combined,
      provenance: 'voice:$intent',
      title: 'Voice interaction',
    );
  }

  String _abstract(String raw) => _oneLine(raw);

  String _oneLine(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 160) return t;
    return '${t.substring(0, 157)}…';
  }

  String _titleFrom(MemoryKind kind) => switch (kind) {
        MemoryKind.commitment => 'Commitment detected',
        MemoryKind.relationship => 'Relationship note',
        MemoryKind.goal => 'Goal signal',
        MemoryKind.preference => 'Preference',
        MemoryKind.decision => 'Decision context',
        _ => 'Observation',
      };
}
