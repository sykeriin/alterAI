import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../../data/local/contextos_dao.dart';
import '../../../data/local/dao_providers.dart';
import '../domain/digital_twin_models.dart';

final digitalTwinProvider =
    AsyncNotifierProvider<DigitalTwinController, DigitalTwinState>(
  DigitalTwinController.new,
);

class DigitalTwinController extends AsyncNotifier<DigitalTwinState> {
  @override
  Future<DigitalTwinState> build() => _load();

  Future<void> setAccess(
    DigitalTwinSource source,
    TwinAccessLevel accessLevel,
  ) async {
    final next = (state.asData?.value ?? DigitalTwinState.defaults())
        .withSource(source, accessLevel);
    state = AsyncValue.data(next);
    await _persistSource(next.consentFor(source));
  }

  Future<void> setAutonomy(TwinAutonomyLevel autonomyLevel) async {
    final next = (state.asData?.value ?? DigitalTwinState.defaults()).copyWith(
      autonomyLevel: autonomyLevel,
      updatedAt: DateTime.now(),
    );
    state = AsyncValue.data(next);
    await _persistSettings(next);
  }

  Future<void> stageCompleteTwin() async {
    final next = (state.asData?.value ?? DigitalTwinState.defaults())
        .stageCompleteTwin();
    state = AsyncValue.data(next);
    await Future.wait([
      for (final consent in next.sources.values) _persistSource(consent),
      _persistSettings(next),
    ]);
  }

  Future<DigitalTwinState> _load() async {
    var loaded = DigitalTwinState.defaults();
    ref.watch(isDbUnlockedProvider);
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return loaded;

    try {
      final rows =
          await ref.read(contextOsDaoProvider).listDigitalTwinSources(userId);
      final next = Map<DigitalTwinSource, TwinSourceConsent>.from(
        loaded.sources,
      );
      for (final row in rows) {
        final consent = row.toConsent();
        next[consent.source] = consent;
      }
      loaded = loaded.copyWith(sources: next);
    } catch (_) {}

    try {
      final settings =
          await ref.read(contextOsDaoProvider).getDigitalTwinSettings(userId);
      if (settings != null) {
        loaded = loaded.copyWith(
          autonomyLevel: TwinAutonomyLevel.fromId(settings.autonomyLevel),
          updatedAt: settings.updatedAt,
        );
      }
    } catch (_) {}

    return loaded;
  }

  Future<void> _persistSource(TwinSourceConsent consent) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(contextOsDaoProvider).upsertDigitalTwinSource(
            DigitalTwinSourceRecord(
              userId: userId,
              sourceKey: consent.source.id,
              accessLevel: consent.accessLevel.id,
              connected: consent.connected,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }

  Future<void> _persistSettings(DigitalTwinState next) async {
    final userId = ref.read(localUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(contextOsDaoProvider).upsertDigitalTwinSettings(
            DigitalTwinSettingsRecord(
              userId: userId,
              autonomyLevel: next.autonomyLevel.id,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {}
  }
}
