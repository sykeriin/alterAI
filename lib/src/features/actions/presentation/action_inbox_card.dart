import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../../contextos/application/openclaw_adapter.dart';
import '../action_preferences.dart';

class ActionInboxCard extends ConsumerWidget {
  const ActionInboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(openClawQueueProvider);
    final pending =
        queue.where((a) => a.stage == ClawStage.queued).take(3).toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.inbox, color: AlterPalette.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pending actions (${queue.where((a) => a.stage == ClawStage.queued).length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(AlterRoutes.openclaw),
                child: const Text('Review all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pending.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PendingRow(action: action),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.action});

  final ClawAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preview = action.isCompose
        ? action.composeBody
        : action.detail;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AlterPalette.graphite.withValues(alpha: 0.35),
        border: Border.all(color: AlterPalette.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action.channel.isNotEmpty)
            Text(
              '${action.channel.toUpperCase()} · ${action.recipient}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              preview.length > 120 ? '${preview.substring(0, 117)}...' : preview,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    ref.read(openClawQueueProvider.notifier).dismiss(action.id),
                child: const Text('Dismiss'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(openClawQueueProvider.notifier)
                      .execute(action.id);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActionAutonomySettings extends ConsumerWidget {
  const ActionAutonomySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(actionPreferencesProvider);
    final theme = Theme.of(context);
    return prefsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prefs) {
        final isAuto = prefs.autonomy == ActionAutonomyMode.fullAuto;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Action autonomy',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAuto
                  ? 'Auto-send for trusted contacts only (max $kMaxFullAutoSendsPerDay/day). Requires Accessibility.'
                  : 'Default: draft actions and confirm with one tap before send.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<ActionAutonomyMode>(
              segments: const [
                ButtonSegment(
                  value: ActionAutonomyMode.draftConfirm,
                  label: Text('Confirm'),
                  icon: Icon(LucideIcons.shield_check, size: 16),
                ),
                ButtonSegment(
                  value: ActionAutonomyMode.fullAuto,
                  label: Text('Auto-send'),
                  icon: Icon(LucideIcons.zap, size: 16),
                ),
              ],
              selected: {prefs.autonomy},
              onSelectionChanged: (values) {
                ref
                    .read(actionPreferencesProvider.notifier)
                    .setAutonomy(values.first);
              },
            ),
          ],
        );
      },
    );
  }
}
