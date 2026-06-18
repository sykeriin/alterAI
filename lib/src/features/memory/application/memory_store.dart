import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../contextos/application/memory_engine.dart';
import '../../identity/application/identity_engine.dart';
import '../../../data/local/dao_providers.dart';
import '../domain/memory_item.dart';

final memoryStoreProvider =
    AsyncNotifierProvider<MemoryStoreNotifier, List<MemoryItem>>(
  MemoryStoreNotifier.new,
);

class MemoryStoreNotifier extends AsyncNotifier<List<MemoryItem>> {
  @override
  Future<List<MemoryItem>> build() async {
    ref.watch(isDbUnlockedProvider);
    return _load();
  }

  Future<List<MemoryItem>> _load() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return const [];

    try {
      return ref.read(memoryDaoProvider).listActive(userId, 200);
    } catch (_) {
      return const [];
    }
  }

  Future<MemoryItem?> encode({
    required MemoryItem draft,
    required MemoryClassification classification,
  }) async {
    if (!classification.shouldRemember) return null;

    final userId = ref.read(localUserIdProvider);
    if (userId == null) return null;

    final governance = ref.read(memoryGovernanceProvider).asData?.value;
    final needsConfirmDurable =
        governance?.durableRequiresConfirmation == true &&
            classification.retention == MemoryRetention.durable;
    final needsConfirmSensitive =
        governance?.sensitiveRequiresConfirmation == true &&
            classification.sensitivity == MemorySensitivity.sensitive;
    final needsConfirm = needsConfirmDurable || needsConfirmSensitive;

    final item = MemoryItem(
      userId: userId,
      kind: classification.kind,
      title: draft.title,
      content: draft.content,
      provenance: draft.provenance,
      confidence: classification.confidence,
      sensitivity: classification.sensitivity,
      retention: classification.retention,
      expiresAt: _expiryFor(classification.retention),
      confirmed: !needsConfirm,
    );

    try {
      final saved = await ref.read(memoryDaoProvider).insert(item);
      state = AsyncValue.data([saved, ...?state.asData?.value]);
      return saved;
    } catch (_) {
      return null;
    }
  }

  Future<void> confirm(String memoryId) async {
    final item = await ref.read(memoryDaoProvider).getById(memoryId);
    if (item == null) return;
    await ref.read(memoryDaoProvider).update(
          item.copyWith(
            confirmed: true,
            retention: MemoryRetention.durable,
            clearExpiresAt: true,
          ),
        );
    await _reindexEmbedding(memoryId);
    await ref.read(identityEngineProvider.notifier).refreshFromMemories();
    ref.invalidateSelf();
  }

  /// Swipe right — keep as durable, confirmed profile memory.
  Future<void> keep(String memoryId) async {
    final item = await ref.read(memoryDaoProvider).getById(memoryId);
    if (item == null) return;
    await ref.read(memoryDaoProvider).update(
          item.copyWith(
            confirmed: true,
            retention: MemoryRetention.durable,
            clearExpiresAt: true,
          ),
        );
    await _reindexEmbedding(memoryId);
    await ref.read(identityEngineProvider.notifier).refreshFromMemories();
    ref.invalidateSelf();
  }

  /// Swipe left — remove from memory store and vector index.
  Future<void> forget(String memoryId) async {
    await delete(memoryId);
  }

  Future<void> correct(String memoryId, {String? title, String? content}) async {
    final item = await ref.read(memoryDaoProvider).getById(memoryId);
    if (item == null) return;
    await ref.read(memoryDaoProvider).update(
          item.copyWith(
            title: title ?? item.title,
            content: content ?? item.content,
          ),
        );
    await _reindexEmbedding(memoryId);
    ref.invalidateSelf();
  }

  Future<void> delete(String memoryId) async {
    await ref.read(memoryDaoProvider).delete(memoryId);
    await ref.read(embeddingDaoProvider).deleteByMemoryId(memoryId);
    ref.invalidateSelf();
  }

  Future<void> purgeExpired() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    await ref.read(memoryDaoProvider).purgeExpired(userId);
    ref.invalidateSelf();
  }

  Future<void> deleteAll() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    await ref.read(memoryDaoProvider).deleteAllForUser(userId);
    await ref.read(identityEngineProvider.notifier).refreshFromMemories();
    ref.invalidateSelf();
  }

  Future<void> _reindexEmbedding(String memoryId) async {
    final item = await ref.read(memoryDaoProvider).getById(memoryId);
    if (item == null) return;
    final text = item.content.isNotEmpty ? item.content : item.title;
    if (text.trim().isEmpty) return;
    await ref.read(embeddingDaoProvider).deleteByMemoryId(memoryId);
    await ref.read(embeddingDaoProvider).upsert(
          memoryId: memoryId,
          abstractText: text,
          kind: item.kind.name,
        );
  }

  DateTime? _expiryFor(MemoryRetention retention) {
    return switch (retention) {
      MemoryRetention.immediateDelete => DateTime.now(),
      MemoryRetention.ephemeral => DateTime.now().add(const Duration(days: 7)),
      MemoryRetention.durable => null,
    };
  }
}
