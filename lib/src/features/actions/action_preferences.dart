import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_settings_dao.dart';
import '../../data/local/dao_providers.dart';
import '../auth/application/auth_provider.dart';

enum ActionAutonomyMode {
  draftConfirm('draft_confirm', 'Confirm before send'),
  fullAuto('full_auto', 'Auto-send');

  const ActionAutonomyMode(this.id, this.label);

  final String id;
  final String label;

  static ActionAutonomyMode fromId(String? id) => ActionAutonomyMode.values
      .firstWhere((m) => m.id == id, orElse: () => ActionAutonomyMode.draftConfirm);
}

class ActionPreferences {
  const ActionPreferences({
    this.autonomy = ActionAutonomyMode.draftConfirm,
    this.fullAutoSendsToday = 0,
    this.fullAutoDay = '',
  });

  final ActionAutonomyMode autonomy;
  final int fullAutoSendsToday;
  final String fullAutoDay;

  ActionPreferences copyWith({
    ActionAutonomyMode? autonomy,
    int? fullAutoSendsToday,
    String? fullAutoDay,
  }) =>
      ActionPreferences(
        autonomy: autonomy ?? this.autonomy,
        fullAutoSendsToday: fullAutoSendsToday ?? this.fullAutoSendsToday,
        fullAutoDay: fullAutoDay ?? this.fullAutoDay,
      );
}

const _kAutonomyKey = 'action_autonomy';
const _kAutoSendCountKey = 'full_auto_send_count';
const _kAutoSendDayKey = 'full_auto_send_day';
const kMaxFullAutoSendsPerDay = 10;

final actionPreferencesProvider =
    AsyncNotifierProvider<ActionPreferencesController, ActionPreferences>(
  ActionPreferencesController.new,
);

class ActionPreferencesController extends AsyncNotifier<ActionPreferences> {
  @override
  Future<ActionPreferences> build() async {
    ref.watch(isDbUnlockedProvider);
    return _load();
  }

  AppSettingsDao get _dao => ref.read(appSettingsDaoProvider);

  Future<ActionPreferences> _load() async {
    final autonomy =
        ActionAutonomyMode.fromId(await _dao.get(_kAutonomyKey));
    final today = _todayKey();
    final storedDay = await _dao.get(_kAutoSendDayKey) ?? '';
    final count = storedDay == today
        ? await _dao.getInt(_kAutoSendCountKey)
        : 0;
    return ActionPreferences(
      autonomy: autonomy,
      fullAutoSendsToday: count,
      fullAutoDay: storedDay,
    );
  }

  Future<void> setAutonomy(ActionAutonomyMode mode) async {
    await _dao.set(_kAutonomyKey, mode.id);
    final current = state.asData?.value ?? const ActionPreferences();
    state = AsyncValue.data(current.copyWith(autonomy: mode));
  }

  Future<bool> recordFullAutoSend() async {
    final today = _todayKey();
    final current = state.asData?.value ?? await _load();
    final count =
        current.fullAutoDay == today ? current.fullAutoSendsToday + 1 : 1;
    if (count > kMaxFullAutoSendsPerDay) return false;
    await _dao.set(_kAutoSendDayKey, today);
    await _dao.setInt(_kAutoSendCountKey, count);
    state = AsyncValue.data(
      current.copyWith(fullAutoSendsToday: count, fullAutoDay: today),
    );
    return true;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
