import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../../data/local/contextos_dao.dart';
import '../../../data/local/dao_providers.dart';

class TrustedEntity {
  const TrustedEntity({this.id, required this.type, required this.value});

  final String? id;
  final String type; // domain | contact | app
  final String value;
}

class MemoryGovernanceSettings {
  const MemoryGovernanceSettings({
    this.defaultRetention = 'ephemeral',
    this.durableRequiresConfirmation = true,
    this.sensitiveRequiresConfirmation = true,
    this.restrictedStorageAllowed = false,
    this.portableExportEnabled = true,
    this.maxRetrievalChars = 6000,
  });

  final String defaultRetention;
  final bool durableRequiresConfirmation;
  final bool sensitiveRequiresConfirmation;
  final bool restrictedStorageAllowed;
  final bool portableExportEnabled;
  final int maxRetrievalChars;

  MemoryGovernanceSettings copyWith({
    String? defaultRetention,
    bool? durableRequiresConfirmation,
    bool? sensitiveRequiresConfirmation,
    bool? restrictedStorageAllowed,
    bool? portableExportEnabled,
    int? maxRetrievalChars,
  }) =>
      MemoryGovernanceSettings(
        defaultRetention: defaultRetention ?? this.defaultRetention,
        durableRequiresConfirmation:
            durableRequiresConfirmation ?? this.durableRequiresConfirmation,
        sensitiveRequiresConfirmation: sensitiveRequiresConfirmation ??
            this.sensitiveRequiresConfirmation,
        restrictedStorageAllowed:
            restrictedStorageAllowed ?? this.restrictedStorageAllowed,
        portableExportEnabled:
            portableExportEnabled ?? this.portableExportEnabled,
        maxRetrievalChars: maxRetrievalChars ?? this.maxRetrievalChars,
      );
}

final memoryGovernanceProvider =
    AsyncNotifierProvider<MemoryGovernanceController, MemoryGovernanceSettings>(
  MemoryGovernanceController.new,
);

class MemoryGovernanceController
    extends AsyncNotifier<MemoryGovernanceSettings> {
  @override
  Future<MemoryGovernanceSettings> build() => _load();

  Future<MemoryGovernanceSettings> _load() async {
    ref.watch(isDbUnlockedProvider);
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return const MemoryGovernanceSettings();
    try {
      return await ref.read(memoryGovernanceDaoProvider).get(userId) ??
          const MemoryGovernanceSettings();
    } catch (_) {
      return const MemoryGovernanceSettings();
    }
  }

  Future<void> save(MemoryGovernanceSettings settings) async {
    state = AsyncValue.data(settings);
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(memoryGovernanceDaoProvider).upsert(userId, settings);
    } catch (_) {}
  }
}

final memoryProvider = AsyncNotifierProvider<MemoryEngine, List<TrustedEntity>>(
  MemoryEngine.new,
);

class MemoryEngine extends AsyncNotifier<List<TrustedEntity>> {
  @override
  Future<List<TrustedEntity>> build() => _load();

  Future<List<TrustedEntity>> _load() async {
    ref.watch(isDbUnlockedProvider);
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return const [];
    try {
      final rows =
          await ref.read(contextOsDaoProvider).listTrustedEntities(userId);
      return rows.map((r) => r.toEntity()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addTrusted(String type, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;

    final current = state.asData?.value ?? const [];
    if (current.any((e) => e.value.toLowerCase() == v.toLowerCase())) return;

    state = AsyncValue.data([TrustedEntity(type: type, value: v), ...current]);

    try {
      await ref.read(contextOsDaoProvider).insertTrustedEntity(
            TrustedEntityRecord(
              id: '',
              userId: userId,
              entityType: type,
              value: v,
              createdAt: DateTime.now(),
            ),
          );
      state = AsyncValue.data(await _load());
    } catch (_) {}
  }

  Future<void> remove(TrustedEntity entity) async {
    final current = state.asData?.value ?? const [];
    state = AsyncValue.data(
      current.where((e) => e.value != entity.value).toList(),
    );
    if (entity.id == null) return;
    try {
      await ref.read(contextOsDaoProvider).deleteTrustedEntity(entity.id!);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final userId = ref.read(localUserIdProvider);
    state = const AsyncValue.data([]);
    if (userId == null) return;
    try {
      final rows =
          await ref.read(contextOsDaoProvider).listTrustedEntities(userId);
      for (final row in rows) {
        await ref.read(contextOsDaoProvider).deleteTrustedEntity(row.id);
      }
    } catch (_) {}
  }

  static String? matchIn(List<TrustedEntity> trusted, String text) {
    final lower = text.toLowerCase();
    for (final e in trusted) {
      if (e.value.isNotEmpty && lower.contains(e.value.toLowerCase())) {
        return e.value;
      }
    }
    return null;
  }
}
