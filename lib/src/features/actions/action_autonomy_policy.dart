import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../contextos/application/memory_engine.dart';
import 'action_preferences.dart';

enum ActionDispatchRoute { openClawConfirm, fullAuto, blocked }

class ActionDispatchDecision {
  const ActionDispatchDecision({
    required this.route,
    required this.reason,
  });

  final ActionDispatchRoute route;
  final String reason;

  bool get requiresOpenClaw => route == ActionDispatchRoute.openClawConfirm;
  bool get canAutoSend => route == ActionDispatchRoute.fullAuto;
}

final actionAutonomyPolicyProvider = Provider<ActionAutonomyPolicy>((ref) {
  return ActionAutonomyPolicy(ref);
});

class ActionAutonomyPolicy {
  ActionAutonomyPolicy(this._ref);

  final Ref _ref;

  Future<ActionDispatchDecision> evaluateSend({
    required String channel,
    required String recipientLabel,
    String? recipientValue,
  }) async {
    final privacyShield =
        _ref.read(alterAppControllerProvider).privacyShield;
    if (privacyShield) {
      return const ActionDispatchDecision(
        route: ActionDispatchRoute.openClawConfirm,
        reason: 'Privacy shield requires confirmation before external actions.',
      );
    }

    final prefs =
        _ref.read(actionPreferencesProvider).asData?.value ??
        const ActionPreferences();
    if (prefs.autonomy == ActionAutonomyMode.draftConfirm) {
      return const ActionDispatchDecision(
        route: ActionDispatchRoute.openClawConfirm,
        reason: 'User setting: confirm before send.',
      );
    }

    if (prefs.fullAutoSendsToday >= kMaxFullAutoSendsPerDay) {
      return ActionDispatchDecision(
        route: ActionDispatchRoute.openClawConfirm,
        reason:
            'Daily auto-send limit ($kMaxFullAutoSendsPerDay) reached; confirm manually.',
      );
    }

    final trusted = _ref.read(memoryProvider).asData?.value ?? const [];
    final haystack =
        '${recipientLabel.toLowerCase()} ${(recipientValue ?? '').toLowerCase()}';
    final match = MemoryEngine.matchIn(trusted, haystack);
    if (match == null) {
      return const ActionDispatchDecision(
        route: ActionDispatchRoute.openClawConfirm,
        reason:
            'Recipient not in trusted contacts; add them in Memory → Trusted to enable auto-send.',
      );
    }

    return ActionDispatchDecision(
      route: ActionDispatchRoute.fullAuto,
      reason: 'Trusted contact ($match); auto-send allowed.',
    );
  }
}
