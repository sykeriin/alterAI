import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/routes.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../application/digital_twin_controller.dart';
import '../application/openclaw_adapter.dart';
import '../domain/contextos_models.dart';
import '../domain/digital_twin_models.dart';

class DigitalTwinScreen extends ConsumerWidget {
  const DigitalTwinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final twinAsync = ref.watch(digitalTwinProvider);

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'TWIN',
        subtitle:
            'A private model of your data, decisions, tone, routines, and relationships.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: 'Privacy',
              icon: const Icon(LucideIcons.lock, size: 18),
              onPressed: () => context.go(AlterRoutes.privacy),
            ),
          ),
          const SizedBox(height: 16),
          twinAsync.when(
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) =>
                GlassPanel(child: Text('Could not load twin: $error')),
            data: (state) => _TwinBody(state: state),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TwinBody extends ConsumerWidget {
  const _TwinBody({required this.state});

  final DigitalTwinState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadinessPanel(state: state),
        const SizedBox(height: 14),
        _AutonomyPanel(state: state),
        const SizedBox(height: 14),
        _OpenClawBridge(state: state),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Data sources',
          subtitle:
              'Each source can be off, metadata-only, redacted memory, or a full local index.',
          trailing: PremiumButton(
            compact: true,
            icon: LucideIcons.brain,
            label: 'Stage full twin',
            onPressed: () => _stageCompleteTwin(context, ref),
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 3,
          children: [
            for (final source in DigitalTwinSource.values)
              _SourceCard(
                consent: state.consentFor(source),
                onChanged: (level) => ref
                    .read(digitalTwinProvider.notifier)
                    .setAccess(source, level),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _stageCompleteTwin(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref.read(digitalTwinProvider.notifier).stageCompleteTwin();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Digital Twin staged with local-first access rules.'),
      ),
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.state});

  final DigitalTwinState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readiness = state.readinessScore;
    final pct = (readiness * 100).round();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AlterPalette.coolGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(LucideIcons.brain, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.maturityLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${state.activeSourceCount} active sources, ${state.localFullCount} local full indexes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.58,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AlterPalette.iris,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: readiness,
              minHeight: 8,
              backgroundColor: AlterPalette.iris.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AlterPalette.iris,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            spacing: 10,
            children: [
              _FacetBar(
                icon: Icons.chat_outlined,
                title: 'Tone',
                detail: 'Chats and replies',
                value: state.personalityDepth,
                color: AlterPalette.cyan,
              ),
              _FacetBar(
                icon: Icons.photo_library_outlined,
                title: 'Memory',
                detail: 'Photos, notes, files',
                value: _coverage(state, const [
                  DigitalTwinSource.photos,
                  DigitalTwinSource.notes,
                  DigitalTwinSource.files,
                ]),
                color: AlterPalette.aura,
              ),
              _FacetBar(
                icon: Icons.event_available_outlined,
                title: 'Rhythm',
                detail: 'Calendar and places',
                value: _coverage(state, const [
                  DigitalTwinSource.calendar,
                  DigitalTwinSource.location,
                  DigitalTwinSource.browser,
                ]),
                color: AlterPalette.mint,
              ),
              _FacetBar(
                icon: Icons.groups_outlined,
                title: 'People',
                detail: 'Contacts and graph',
                value: _coverage(state, const [
                  DigitalTwinSource.contacts,
                  DigitalTwinSource.calls,
                  DigitalTwinSource.social,
                ]),
                color: AlterPalette.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _coverage(DigitalTwinState state, List<DigitalTwinSource> sources) {
    final max = sources.fold<double>(
      0,
      (sum, source) => sum + source.sensitivity,
    );
    if (max == 0) return 0;
    final score = sources.fold<double>(
      0,
      (sum, source) => sum + state.consentFor(source).coverageWeight,
    );
    return (score / max).clamp(0.0, 1.0).toDouble();
  }
}

class _FacetBar extends StatelessWidget {
  const _FacetBar({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutonomyPanel extends ConsumerWidget {
  const _AutonomyPanel({required this.state});

  final DigitalTwinState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.settings, color: AlterPalette.iris, size: 18),
              const SizedBox(width: 8),
              Text(
                'Autonomy ring',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _MiniPill(
                label: state.autonomyLevel.label,
                color: AlterPalette.iris,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in TwinAutonomyLevel.values)
                _AutonomyButton(
                  level: level,
                  selected: state.autonomyLevel == level,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(digitalTwinProvider.notifier).setAutonomy(level);
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            state.autonomyLevel.detail,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final guardrail in state.hardGuardrails)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.shield_check,
                    size: 14,
                    color: AlterPalette.mint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guardrail,
                      style: theme.textTheme.labelSmall?.copyWith(
                        height: 1.3,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AutonomyButton extends StatelessWidget {
  const _AutonomyButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final TwinAutonomyLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AlterPalette.iris.withValues(alpha: 0.16)
              : theme.colorScheme.surface.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AlterPalette.iris.withValues(alpha: 0.42)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              level.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? AlterPalette.iris : null,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (level.weight + 1) / TwinAutonomyLevel.values.length,
              minHeight: 4,
              backgroundColor: AlterPalette.iris.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AlterPalette.iris,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenClawBridge extends ConsumerWidget {
  const _OpenClawBridge({required this.state});

  final DigitalTwinState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AlterPalette.amber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                LucideIcons.wand_sparkles,
                color: AlterPalette.amber,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OpenClaw phone bridge',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ALTER can prepare calls, messages, searches, calendar events, and setup actions. The final high-impact tap stays yours.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.radio, size: 15),
                      label: const Text('Live feed'),
                      onPressed: () => context.go(AlterRoutes.feed),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.wand_sparkles, size: 15),
                      label: const Text('Queue setup'),
                      onPressed: () => _queueSetup(context, ref),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.chevron_right, size: 15),
                      label: const Text('OpenClaw'),
                      onPressed: () => context.go(AlterRoutes.openclaw),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _queueSetup(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(openClawQueueProvider.notifier)
        .enqueue(
          SafeAction(
            type: 'digital_twin_setup',
            title: 'Set up Digital Twin sources',
            detail:
                'Review ${state.activeSourceCount} active sources and open phone permission surfaces where needed.',
            requiresConfirmation: true,
            irreversible: false,
          ),
          momentExcerpt: 'Digital Twin source setup',
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Queued Digital Twin setup in OpenClaw.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.go(AlterRoutes.openclaw),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.consent, required this.onChanged});

  final TwinSourceConsent consent;
  final ValueChanged<TwinAccessLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = consent.source;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: source.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(source.icon, color: source.color, size: 21),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Sensitivity ${source.sensitivity}/5',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: source.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                consent.isActive
                    ? LucideIcons.circle_check
                    : LucideIcons.circle_x,
                color: consent.isActive
                    ? AlterPalette.mint
                    : AlterPalette.slate,
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            source.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in TwinAccessLevel.values)
                _AccessButton(
                  level: level,
                  selected: consent.accessLevel == level,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(level);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.lock, size: 13, color: AlterPalette.iris),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  consent.accessLevel.cloudBoundary,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                    height: 1.25,
                    fontWeight: FontWeight.w700,
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

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final TwinAccessLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AlterPalette.iris : theme.colorScheme.onSurface;
    return Tooltip(
      message: level.scopeLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AlterPalette.iris.withValues(alpha: 0.15)
                : theme.colorScheme.surface.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AlterPalette.iris.withValues(alpha: 0.36)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            level.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
