import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../profile/application/profile_provider.dart';
import '../application/dashboard_controller.dart';
import '../application/daytwin_controller.dart';
import '../application/decision_dna_controller.dart';
import '../application/futuretwin_controller.dart';
import '../application/openclaw_adapter.dart';
import '../domain/contextos_models.dart';

class ContextMissionControlScreen extends ConsumerWidget {
  const ContextMissionControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashAsync = ref.watch(contextDashboardProvider);
    final dna = ref.watch(decisionDnaProvider).asData?.value;
    final queue = ref.watch(openClawQueueProvider);
    final day = ref.watch(dayTwinControllerProvider).result;
    final future = ref.watch(futureTwinControllerProvider).result;
    final cloudOn = ref.watch(openAIServiceProvider) != null;

    final pending = queue.where((a) => a.stage == ClawStage.queued).length;

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      'Mission Control',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'OfficeKit — the full ContextOS loop in one view.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(LucideIcons.refresh_cw),
                onPressed: () =>
                    ref.read(contextDashboardProvider.notifier).refresh(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Edge / cloud / private status — always visible.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: LucideIcons.cpu,
                label: 'Edge active (on-device)',
                color: AlterPalette.mint,
              ),
              _StatusPill(
                icon: cloudOn ? LucideIcons.cloud : LucideIcons.cloud_off,
                label: cloudOn ? 'Cloud connected' : 'Cloud offline',
                color: cloudOn ? AlterPalette.cyan : AlterPalette.slate,
              ),
              _StatusPill(
                icon: LucideIcons.lock,
                label: 'Private Mode available',
                color: AlterPalette.iris,
              ),
            ],
          ),
          const SizedBox(height: 16),
          dashAsync.when(
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => GlassPanel(child: Text('Dashboard error: $e')),
            data: (data) => _Body(
              data: data,
              dnaTrust: dna?.trustScore ?? 0.5,
              dnaPattern: dna != null && dna.patterns.isNotEmpty
                  ? dna.patterns.first.pattern
                  : null,
              pendingActions: pending,
              queue: queue,
              hasDay: day != null,
              dayMove: day?.nextBestMove,
              hasFuture: future != null,
              futureLine: future?.recommended,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.data,
    required this.dnaTrust,
    required this.dnaPattern,
    required this.pendingActions,
    required this.queue,
    required this.hasDay,
    required this.dayMove,
    required this.hasFuture,
    required this.futureLine,
  });

  final DashboardData data;
  final double dnaTrust;
  final String? dnaPattern;
  final int pendingActions;
  final List queue;
  final bool hasDay;
  final String? dayMove;
  final bool hasFuture;
  final String? futureLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dangerous = data.riskMap[RiskVerdict.dangerous] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!data.persisted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Note(
              'Showing live in-memory state. Apply the contextos migration in '
              'Supabase to persist the full moment history and audit log.',
            ),
          ),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 4,
          children: [
            MetricTile(
              label: 'Moments analyzed',
              value: '${data.momentCount}',
              icon: LucideIcons.scan_eye,
              accent: AlterPalette.iris,
            ),
            MetricTile(
              label: 'Dangerous flagged',
              value: '$dangerous',
              icon: LucideIcons.octagon_x,
              accent: AlterPalette.danger,
            ),
            MetricTile(
              label: 'Follow-through',
              value: '${(dnaTrust * 100).round()}%',
              icon: LucideIcons.dna,
              accent: AlterPalette.mint,
            ),
            MetricTile(
              label: 'OpenClaw pending',
              value: '$pendingActions',
              icon: LucideIcons.wand_sparkles,
              accent: AlterPalette.amber,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Risk map.
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Risk map',
                subtitle: 'Verdicts across every analyzed moment.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final v in RiskVerdict.values)
                    Expanded(
                      child: _RiskCell(verdict: v, count: data.riskMap[v] ?? 0),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 2,
          children: [
            _DayCard(hasDay: hasDay, move: dayMove),
            _FutureCard(hasFuture: hasFuture, recommended: futureLine),
          ],
        ),
        const SizedBox(height: 14),
        // Proof ledger / live moments.
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Proof ledger',
                subtitle:
                    'Every verdict, with confidence and where it was reasoned.',
              ),
              const SizedBox(height: 12),
              if (data.ledger.isEmpty)
                Text(
                  'No moments yet — analyze one in LifeShield.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                )
              else
                ...data.ledger.take(8).map((e) => _LedgerRow(entry: e)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // OpenClaw + DNA.
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 2,
          children: [
            _LinkCard(
              icon: LucideIcons.wand_sparkles,
              color: AlterPalette.iris,
              title: 'OpenClaw queue',
              line: pendingActions == 0
                  ? 'No actions waiting.'
                  : '$pendingActions action(s) awaiting your approval.',
              route: '/openclaw',
            ),
            _LinkCard(
              icon: LucideIcons.dna,
              color: AlterPalette.mint,
              title: 'Decision DNA',
              line: dnaPattern ?? 'Learning from your outcomes.',
              route: '/dna',
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Audit log.
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Audit log',
                subtitle: 'Edge / cloud / consent / action trail.',
              ),
              const SizedBox(height: 12),
              if (data.audit.isEmpty)
                Text(
                  'No audited events yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                )
              else
                ...data.audit.take(10).map((e) => _AuditRow(entry: e)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RiskCell extends StatelessWidget {
  const _RiskCell({required this.verdict, required this.count});

  final RiskVerdict verdict;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = verdict.color;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              color: c,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            verdict.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = entry.verdict.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            entry.cloudUsed ? LucideIcons.cloud : LucideIcons.cpu,
            size: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
          Text(
            '${(entry.confidence * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (entry.timeLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              entry.timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (entry.edgeState) {
      'cloud' => AlterPalette.cyan,
      'private' => AlterPalette.iris,
      _ => AlterPalette.mint,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.detail,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.timeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.hasDay, required this.move});

  final bool hasDay;
  final String? move;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go('/daytwin'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.calendar_clock,
                size: 18,
                color: AlterPalette.cyan,
              ),
              const SizedBox(width: 8),
              Text(
                'DayTwin',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasDay
                ? (move ?? 'Day modeled.')
                : 'No day modeled yet — tap to simulate today.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _FutureCard extends StatelessWidget {
  const _FutureCard({required this.hasFuture, required this.recommended});

  final bool hasFuture;
  final String? recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go('/futuretwin'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.git_fork, size: 18, color: AlterPalette.violet),
              const SizedBox(width: 8),
              Text(
                'FutureTwin',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasFuture
                ? 'Recommended path: ${recommended ?? '—'}'
                : 'No decision simulated yet — tap to weigh one.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: () => context.go(route),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

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

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlterPalette.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 15, color: AlterPalette.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
