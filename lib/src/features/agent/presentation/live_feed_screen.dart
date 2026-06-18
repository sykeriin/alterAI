import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../contextos/application/lifeshield_controller.dart';
import '../../contextos/domain/contextos_models.dart';
import '../application/notification_monitor.dart';

class LiveFeedScreen extends ConsumerWidget {
  const LiveFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final m = ref.watch(notificationMonitorProvider);
    final notifier = ref.read(notificationMonitorProvider.notifier);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Live Feed',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ALTER watches incoming notifications and triages each one on-device. '
            'Nothing leaves your phone unless you open a moment for cloud analysis.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (!m.supported)
            GlassPanel(
              child: Text(
                'Notification monitoring runs on the Android/iQOO build, not on web.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            )
          else if (!m.enabled)
            _ConsentCard(onEnable: notifier.enable, error: m.error)
          else ...[
            Row(
              children: [
                _Stat(
                  icon: LucideIcons.radio,
                  label: 'Monitoring',
                  value: 'on-device',
                  color: AlterPalette.mint,
                ),
                const SizedBox(width: 10),
                _Stat(
                  icon: LucideIcons.flag,
                  label: 'Flagged',
                  value: '${m.flaggedCount}',
                  color: AlterPalette.danger,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.pause, size: 15),
                  label: const Text('Pause'),
                  onPressed: notifier.disable,
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.eraser, size: 15),
                  label: const Text('Clear'),
                  onPressed: notifier.clear,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (m.moments.isEmpty)
              GlassPanel(
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.radio,
                      size: 36,
                      color: AlterPalette.iris,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Listening…',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'New notifications will appear here, each triaged on-device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...m.moments.map(
                (lm) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MomentRow(
                    moment: lm,
                    onOpen: () {
                      ref
                          .read(lifeShieldControllerProvider.notifier)
                          .setSource(MomentSource.notification);
                      ref
                          .read(lifeShieldControllerProvider.notifier)
                          .setInput(lm.excerpt);
                      context.go('/shield');
                    },
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.onEnable, required this.error});

  final VoidCallback onEnable;
  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shield, size: 20, color: AlterPalette.iris),
              const SizedBox(width: 10),
              Text(
                'Turn on monitoring',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._points(theme, [
            'ALTER reads incoming notification text only — never your apps\' private data.',
            'Each notification is redacted and risk-checked on-device.',
            'Nothing is sent to the cloud unless you tap a moment open.',
            'You grant Notification Access in system settings, and can revoke it anytime.',
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              label: 'Enable monitoring',
              icon: LucideIcons.radio,
              onPressed: onEnable,
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AlterPalette.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _points(ThemeData theme, List<String> items) => [
    for (final t in items)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.check, size: 15, color: AlterPalette.mint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
  ];
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.moment, required this.onOpen});

  final LiveMoment moment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = moment.verdict.color;
    final h = moment.at.hour.toString().padLeft(2, '0');
    final min = moment.at.minute.toString().padLeft(2, '0');
    return GlassPanel(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      moment.app,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$h:$min',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        moment.verdict.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  moment.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
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
