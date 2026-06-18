import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../memory/domain/memory_item.dart';
import '../domain/identity_trait.dart';
import '../../memory/application/memory_store.dart';
import '../../../data/local/dao_providers.dart';

final identityEngineProvider =
    AsyncNotifierProvider<IdentityEngineNotifier, List<IdentityTrait>>(
  IdentityEngineNotifier.new,
);

/// Derives identity traits from confirmed memory evidence — never LLM-invented.
class IdentityEngineNotifier extends AsyncNotifier<List<IdentityTrait>> {
  @override
  Future<List<IdentityTrait>> build() async {
    ref.watch(isDbUnlockedProvider);
    ref.watch(memoryStoreProvider);
    return _load();
  }

  Future<List<IdentityTrait>> _load() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return const [];

    try {
      return await ref.read(identityDaoProvider).list(userId);
    } catch (_) {
      return _deriveFromMemories(userId);
    }
  }

  List<IdentityTrait> _deriveFromMemories(String userId) {
    final memories =
        ref.read(memoryStoreProvider).asData?.value ?? const <MemoryItem>[];
    final confirmed = memories.where((m) => m.confirmed).toList();
    final traits = <String, IdentityTrait>{};

    for (final m in confirmed) {
      final dimension = switch (m.kind) {
        MemoryKind.preference => 'value',
        MemoryKind.goal => 'ambition',
        MemoryKind.routine => 'routine',
        MemoryKind.communicationStyle => 'communication_style',
        MemoryKind.relationship => 'relationship',
        MemoryKind.skill => 'skill',
        _ => m.kind.name,
      };
      final existing = traits[dimension];
      final ids = [
        if (m.id != null) m.id!,
        ...?existing?.sourceMemoryIds,
      ];
      traits[dimension] = IdentityTrait(
        userId: userId,
        dimension: dimension,
        value: m.content.isNotEmpty ? m.content : m.title,
        confidence: existing == null
            ? m.confidence
            : (existing.confidence + m.confidence).clamp(0, 1) / 1.2,
        sourceMemoryIds: ids,
      );
    }
    return traits.values.toList();
  }

  Future<void> refreshFromMemories() async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    final derived = _deriveFromMemories(userId);
    for (final trait in derived) {
      try {
        await ref.read(identityDaoProvider).upsert(trait);
      } catch (_) {}
    }
    state = AsyncValue.data(derived);
  }

  String promptBlock() {
    final traits = state.asData?.value ?? const [];
    if (traits.isEmpty) return '';
    return traits
        .map((t) =>
            '${t.dimension}=${t.value} (confidence=${t.confidence.toStringAsFixed(2)}, sources=${t.sourceMemoryIds.length})')
        .join('\n');
  }
}
