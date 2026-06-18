import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/widgets.dart';
import '../../device_control/application/phone_control_controller.dart';
import '../application/decision_dna_controller.dart';
import '../application/openclaw_adapter.dart';

class OpenClawQueueScreen extends ConsumerWidget {
  const OpenClawQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(openClawQueueProvider);
    final phoneControl = ref.watch(phoneControlControllerProvider);
    final theme = Theme.of(context);
    final pending = queue.where((a) => a.stage == ClawStage.queued).toList();
    final resolved = queue.where((a) => a.stage != ClawStage.queued).toList();

    return DeepScaffold(
      title: 'OPENCLAW',
      subtitle:
          'The action gateway, not the brain. Draft → Explain → Confirm → Execute. '
          'ALTER never sends, pays, or installs without your explicit approval.',
      child: ListView(
        children: [
          Row(
            children: [
              _StatChip(
                label: 'Pending',
                value: '${pending.length}',
                color: AlterPalette.amber,
                icon: LucideIcons.clock,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Executed',
                value:
                    '${resolved.where((a) => a.stage == ClawStage.executed).length}',
                color: AlterPalette.mint,
                icon: LucideIcons.circle_check,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PhoneControlHub(state: phoneControl),
          const SizedBox(height: 18),
          if (queue.isEmpty)
            GlassPanel(
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.inbox,
                    size: 40,
                    color: AlterPalette.iris,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No actions queued',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirm a safe action from a LifeShield moment and it lands here '
                    'for review before anything runs.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.58,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final a in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClawCard(
                action: a,
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04),
            ),
          if (resolved.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'History',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final a in resolved)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ResolvedRow(action: a),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PhoneControlHub extends ConsumerWidget {
  const _PhoneControlHub({required this.state});

  final PhoneControlState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = state.audit.take(4).toList();
    final screen = state.lastStructuredScreen;
    final admin = state.deviceAdminStatus;
    final adminEnabled = admin?.managed == true;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Phone Control',
            subtitle:
                'Accessibility, native intents, and every action ALTER has attempted.',
            trailing: PremiumButton(
              label: state.accessibilityEnabled ? 'Enabled' : 'Enable',
              compact: true,
              icon: state.accessibilityEnabled
                  ? LucideIcons.shield_check
                  : LucideIcons.accessibility,
              onPressed: () async {
                HapticFeedback.selectionClick();
                if (state.accessibilityEnabled) {
                  await ref
                      .read(phoneControlControllerProvider.notifier)
                      .refresh();
                } else {
                  await ref
                      .read(phoneControlControllerProvider.notifier)
                      .openAccessibilitySettings();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: state.accessibilityEnabled
                    ? 'Accessibility on'
                    : 'Accessibility off',
                selected: state.accessibilityEnabled,
                icon: LucideIcons.accessibility,
              ),
              PremiumChip(
                label: '${state.audit.length} audited',
                selected: state.audit.isNotEmpty,
                icon: LucideIcons.clipboard_check,
              ),
              PremiumChip(
                label: 'Native intents',
                selected: true,
                icon: LucideIcons.smartphone,
              ),
              if (screen != null) ...[
                PremiumChip(
                  label: '${screen.buttons.length} buttons',
                  selected: screen.buttons.isNotEmpty,
                  icon: LucideIcons.workflow,
                ),
                PremiumChip(
                  label: '${screen.inputs.length} inputs',
                  selected: screen.inputs.isNotEmpty,
                  icon: LucideIcons.pencil,
                ),
              ],
              PremiumChip(
                label: adminEnabled
                    ? admin!.deviceOwner
                          ? 'Device Owner'
                          : admin.profileOwner
                          ? 'Profile Owner'
                          : 'Device Admin'
                    : 'Admin off',
                selected: adminEnabled,
                icon: LucideIcons.shield,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.scan_text, size: 16),
                  label: const Text('Read current screen'),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final snapshot = await ref
                        .read(phoneControlControllerProvider.notifier)
                        .readScreen();
                    if (context.mounted && snapshot.message.isNotEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(snapshot.message)));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.eraser, size: 16),
                label: const Text('Clear'),
                onPressed: state.audit.isEmpty
                    ? null
                    : () => ref
                          .read(phoneControlControllerProvider.notifier)
                          .clearAudit(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    adminEnabled
                        ? LucideIcons.lock_keyhole
                        : LucideIcons.shield,
                    size: 16,
                  ),
                  label: Text(adminEnabled ? 'Lock test' : 'Enable admin'),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final controller = ref.read(
                      phoneControlControllerProvider.notifier,
                    );
                    final message = adminEnabled
                        ? await controller.lockDevice()
                        : await controller.openDeviceAdmin();
                    if (context.mounted && message.isNotEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.shield_check, size: 16),
                  label: const Text('Admin status'),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await ref
                        .read(phoneControlControllerProvider.notifier)
                        .refresh();
                    final status = ref
                        .read(phoneControlControllerProvider)
                        .deviceAdminStatus;
                    if (context.mounted && status != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(status.message)));
                    }
                  },
                ),
              ),
            ],
          ),
          if (screen != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${screen.packageName}: ${screen.summary}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
            ),
          ],
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              state.error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AlterPalette.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (latest.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final entry in latest)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.ok
                          ? LucideIcons.circle_check
                          : LucideIcons.circle_alert,
                      size: 16,
                      color: entry.ok ? AlterPalette.mint : AlterPalette.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.kind.replaceAll('_', ' ')} • ${entry.target.isEmpty ? entry.message : entry.target}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClawCard extends ConsumerWidget {
  const _ClawCard({required this.action});

  final ClawAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final danger = action.irreversible;
    final accent = danger ? AlterPalette.danger : AlterPalette.iris;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    danger
                        ? LucideIcons.shield_alert
                        : LucideIcons.wand_sparkles,
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      action.type.replaceAll('_', ' '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (danger)
                _MiniBadge(text: 'Irreversible', color: AlterPalette.danger),
            ],
          ),
          if (action.isCompose) ...[
            const SizedBox(height: 10),
            if (action.channel.isNotEmpty)
              Text(
                '${action.channel.toUpperCase()} → ${action.recipient}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AlterPalette.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (action.composeSubject.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Subject: ${action.composeSubject}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (action.composeBody.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                action.composeBody,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
          ] else if (action.detail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              action.detail,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          // Explain step.
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.why,
                    style: theme.textTheme.labelSmall?.copyWith(
                      height: 1.3,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: action.irreversible ? 'Confirm & execute' : 'Execute',
                  icon: LucideIcons.zap,
                  compact: true,
                  onPressed: () => _execute(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(openClawQueueProvider.notifier).dismiss(action.id);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _execute(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    if (action.requiresConfirmation || action.irreversible) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.irreversible ? 'Irreversible action' : 'Confirm'),
          content: Text(
            action.irreversible
                ? '“${action.title}” cannot be undone. Execute through OpenClaw?'
                : 'Execute “${action.title}” now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: action.irreversible
                    ? AlterPalette.danger
                    : AlterPalette.iris,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Execute'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.heavyImpact();
    final result = await ref
        .read(openClawQueueProvider.notifier)
        .execute(action.id);
    if (context.mounted && result.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    if (context.mounted) {
      await _askOutcome(context, ref, action);
    }
  }
}

Future<void> _askOutcome(
  BuildContext context,
  WidgetRef ref,
  ClawAction action,
) async {
  final outcome = await showModalBottomSheet<OutcomeKind>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OutcomeSheet(action: action),
  );
  if (outcome == null) return;
  await ref.read(decisionDnaProvider.notifier).recordOutcome(action, outcome);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged: ${outcome.label} → Decision DNA updated'),
      ),
    );
  }
}

class _OutcomeSheet extends StatelessWidget {
  const _OutcomeSheet({required this.action});

  final ClawAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? AlterPalette.graphite : AlterPalette.white).withValues(
          alpha: 0.97,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(
            color: AlterPalette.iris.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How did it turn out?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '“${action.title}” — your answer trains your Decision DNA.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in OutcomeKind.values)
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => Navigator.pop(context, o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: o.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: o.color.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          o.positive
                              ? LucideIcons.check
                              : LucideIcons.triangle_alert,
                          size: 14,
                          color: o.color,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          o.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: o.color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolvedRow extends StatelessWidget {
  const _ResolvedRow({required this.action});

  final ClawAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final executed = action.stage == ClawStage.executed;
    final c = executed ? AlterPalette.mint : AlterPalette.slate;
    return Opacity(
      opacity: 0.8,
      child: Row(
        children: [
          Icon(
            executed ? LucideIcons.circle_check : LucideIcons.circle_x,
            size: 16,
            color: c,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            action.stage.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
