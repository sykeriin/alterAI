import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../../profile/application/profile_provider.dart';
import '../application/gemma_model_manager.dart';
import 'moment_sheet.dart';

class ContextOsHomeScreen extends ConsumerWidget {
  const ContextOsHomeScreen({super.key});

  static const _loop = [
    'Sense',
    'Intercept',
    'Edge',
    'Understand',
    'Simulate',
    'Decide',
    'Confirm',
    'Act',
    'Learn',
  ];

  static const _modes = [
    _Mode(
      'Digital Twin',
      'Your Life OS model',
      LucideIcons.brain,
      AlterPalette.aura,
      AlterRoutes.twin,
    ),
    _Mode(
      'LifeShield',
      'Protect before you act',
      LucideIcons.shield_check,
      AlterPalette.mint,
      AlterRoutes.shield,
    ),
    _Mode(
      'DayTwin',
      'Model today’s pressure',
      LucideIcons.calendar_clock,
      AlterPalette.cyan,
      AlterRoutes.dayTwin,
    ),
    _Mode(
      'FutureTwin',
      'Simulate big decisions',
      LucideIcons.git_fork,
      AlterPalette.violet,
      AlterRoutes.futureTwin,
    ),
    _Mode(
      'Council',
      'Five inner voices',
      LucideIcons.users,
      AlterPalette.iris,
      AlterRoutes.decisionCouncil,
    ),
    _Mode(
      'OpenClaw',
      'Action gateway',
      LucideIcons.wand_sparkles,
      AlterPalette.amber,
      AlterRoutes.openclaw,
    ),
    _Mode(
      'Decision DNA',
      'What ALTER learned',
      LucideIcons.dna,
      AlterPalette.mint,
      AlterRoutes.dna,
    ),
    _Mode(
      'Memory review',
      'In Settings → Memory',
      LucideIcons.brain,
      AlterPalette.aura,
      AlterRoutes.settings,
    ),
    _Mode(
      'Edge analysis',
      'Pattern check on-device',
      LucideIcons.shield_check,
      AlterPalette.cyan,
      AlterRoutes.edge,
    ),
    _Mode(
      'Mission Control',
      'The whole loop',
      LucideIcons.command,
      AlterPalette.iris,
      AlterRoutes.mission,
    ),
    _Mode(
      'Privacy',
      'What leaves the phone',
      LucideIcons.lock,
      AlterPalette.danger,
      AlterRoutes.privacy,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final cloudOn = profile?.openaiKey.isNotEmpty == true;
    final gemma = ref.watch(gemmaModelProvider);

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'CONTEXT',
        subtitle: 'Understands the moment before you act.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Status(
                icon: LucideIcons.cpu,
                label: gemma.edgePillLabel,
                color: AlterPalette.mint,
              ),
              _Status(
                icon: cloudOn ? LucideIcons.cloud : LucideIcons.cloud_off,
                label: cloudOn ? 'Cloud AI ready' : 'Cloud AI off',
                color: cloudOn ? AlterPalette.cyan : AlterPalette.slate,
              ),
              _Status(
                icon: LucideIcons.lock,
                label: 'Private Mode available',
                color: AlterPalette.iris,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary CTA.
          GestureDetector(
            onTap: () => showMomentSheet(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AlterPalette.premiumGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AlterPalette.iris.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.scan_eye,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Drop a moment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Paste a message, link, payment or install prompt — '
                            'ALTER checks it before you act.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.arrow_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The loop.
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The loop',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _loop.length; i++) ...[
                      Text(
                        _loop[i],
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AlterPalette.iris,
                        ),
                      ),
                      if (i < _loop.length - 1)
                        Icon(
                          LucideIcons.chevron_right,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [for (final m in _modes) _ModeCard(mode: m)],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Mode {
  const _Mode(this.title, this.subtitle, this.icon, this.color, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final _Mode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go(mode.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: mode.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(mode.icon, color: mode.color, size: 22),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            mode.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            mode.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
