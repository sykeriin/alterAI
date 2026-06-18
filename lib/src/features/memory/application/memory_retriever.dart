import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contextos/application/memory_engine.dart';
import '../../../data/local/dao_providers.dart';
import '../data/scored_memory_vector.dart';
import 'memory_lifecycle.dart';
import 'memory_store.dart';

final memoryRetrieverProvider = Provider<MemoryRetriever>((ref) {
  return MemoryRetriever(ref);
});

/// Hybrid lexical + on-device vector RAG with strict char budget.
/// Vector leg uses hash_v1 embeddings (lexical-ish); not semantic ONNX embedder.
class MemoryRetriever {
  MemoryRetriever(this._ref);

  final Ref _ref;

  Future<String> retrieveContext({
    required String query,
    int? maxChars,
    String? queryPrefix,
  }) async {
    final expandedQuery = [
      if (queryPrefix != null && queryPrefix.trim().isNotEmpty) queryPrefix.trim(),
      query.trim(),
    ].join(' ');
    _ref.read(memoryLifecycleProvider.notifier).setStage(
          MemoryLifecycleStage.retrieving,
          message: 'Searching memories…',
        );

    final governance = _ref.read(memoryGovernanceProvider).asData?.value;
    final cap = maxChars ?? governance?.maxRetrievalChars ?? 6000;

    final memories = _ref.read(memoryStoreProvider).asData?.value ?? const [];
    final vectorHits = await _safeVectorSearch(expandedQuery);

    final tokens = expandedQuery.toLowerCase().split(RegExp(r'\W+'));
    final scored = memories.map((m) {
      final hay = '${m.title} ${m.content} ${m.kind.name}'.toLowerCase();
      var score = m.confidence;
      for (final t in tokens) {
        if (t.length > 2 && hay.contains(t)) score += 0.15;
      }
      if (m.confirmed) score += 0.2;
      for (final hit in vectorHits) {
        if (hit.memoryId == m.id) score += hit.score * 0.5;
      }
      return MapEntry(m, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();
    for (final entry in scored.take(12)) {
      final m = entry.key;
      final line =
          '- [${m.kind.name}] ${m.title}: ${m.content} (confidence=${m.confidence.toStringAsFixed(2)})';
      if (buffer.length + line.length > cap) break;
      buffer.writeln(line);
    }

    for (final hit in vectorHits) {
      if (hit.memoryId != null &&
          memories.any((m) => m.id == hit.memoryId)) {
        continue;
      }
      final line = '- [${hit.kind}] ${hit.abstractText} (vector=${hit.score.toStringAsFixed(2)})';
      if (buffer.length + line.length > cap) break;
      buffer.writeln(line);
    }

    _ref.read(memoryLifecycleProvider.notifier).idle();
    return buffer.toString().trim();
  }

  Future<List<ScoredMemoryVector>> _safeVectorSearch(String query) async {
    try {
      return await _ref
          .read(embeddingDaoProvider)
          .search(query: query, limit: 8);
    } catch (_) {
      return const [];
    }
  }
}
