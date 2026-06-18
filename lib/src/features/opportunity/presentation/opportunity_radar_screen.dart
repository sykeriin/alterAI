import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../../../domain/entities/alter_models.dart';
import '../../shared/application/alter_data_providers.dart';

class OpportunityRadarScreen extends ConsumerWidget {
  const OpportunityRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunities = ref.watch(opportunitySignalsProvider);
    final theme = Theme.of(context);
    final opportunityItems =
        opportunities.asData?.value ?? const <OpportunitySignal>[];
    final heatScore = opportunityItems.isEmpty
        ? '--'
        : '${(opportunityItems.map((item) => item.score).reduce(math.max) * 100).round()}';
    final sourceCount = opportunityItems
        .map((item) => item.source.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .length;

    return DeepScaffold(
      title: 'OPPORTUNITY RADAR',
      subtitle:
          'Live signal discovery across web, memory, social graph, and office context.',
      bg: const [Color(0xFF0D5C40), Color(0xFF0D2620), AppColors.bg],
      bgCenter: const Alignment(0.4, -1.0),
      child: ListView(
        children: [
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              GlassPanel(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: context.isCompact ? 260 : 330,
                  child: const _RadarView(),
                ),
              ),
              MetricTile(
                label: 'Heat score',
                value: heatScore,
                icon: LucideIcons.radar,
                detail: opportunityItems.isEmpty
                    ? 'No ranked opportunities yet'
                    : 'Highest current opportunity score',
                accent: AlterPalette.aura,
              ),
              MetricTile(
                label: 'Fresh sources',
                value: '$sourceCount',
                icon: LucideIcons.globe,
                detail: 'Distinct sources in loaded results',
                accent: AlterPalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _OpportunityHeatmap(items: opportunityItems),
          const SizedBox(height: 18),
          opportunities.when(
            data: (items) => items.isEmpty
                ? const _EmptyOpportunities()
                : Column(
                    children: [
                      for (final opportunity in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OpportunityCard(opportunity: opportunity),
                        ),
                    ],
                  ),
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stackTrace) =>
                Text('Unable to load opportunities: $error'),
          ),
        ],
      ),
    );
  }
}

class _OpportunityHeatmap extends StatelessWidget {
  const _OpportunityHeatmap({required this.items});

  final List<OpportunitySignal> items;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, double>{};
    for (final item in items) {
      final category = item.category.trim().isEmpty
          ? 'Uncategorized'
          : item.category;
      grouped[category] = math.max(grouped[category] ?? 0, item.score);
    }
    final cells = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Opportunity heatmap',
            subtitle:
                'Grouped by categories returned from the backend/data store.',
          ),
          const SizedBox(height: 16),
          if (cells.isEmpty)
            Text(
              'No opportunity categories loaded yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final width = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in cells.take(6))
                      SizedBox(
                        width: width,
                        child: _HeatCell(
                          label: entry.key,
                          value: entry.value,
                          color: _heatColor(entry.value),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyOpportunities extends StatelessWidget {
  const _EmptyOpportunities();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        children: [
          const Icon(LucideIcons.radar, size: 40, color: AlterPalette.iris),
          const SizedBox(height: 12),
          Text(
            'No opportunities loaded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect the backend and complete your profile to rank real signals.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

Color _heatColor(double value) {
  if (value >= 0.85) return AlterPalette.aura;
  if (value >= 0.7) return AlterPalette.iris;
  if (value >= 0.55) return AlterPalette.cyan;
  if (value >= 0.4) return AlterPalette.amber;
  return AlterPalette.slate;
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09 + value * 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${(value * 100).round()}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarView extends StatelessWidget {
  const _RadarView();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
          painter: _RadarPainter(),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AlterPalette.premiumGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(LucideIcons.radar, color: Colors.white, size: 34),
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 2400.ms,
          color: Colors.white.withValues(alpha: 0.28),
        );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AlterPalette.iris.withValues(alpha: 0.24);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AlterPalette.iris.withValues(alpha: 0),
          AlterPalette.iris.withValues(alpha: 0.28),
          AlterPalette.cyan.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ringPaint);
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 1.55,
      true,
      sweepPaint,
    );

    final points = [
      Offset(center.dx + radius * 0.42, center.dy - radius * 0.34),
      Offset(center.dx - radius * 0.58, center.dy + radius * 0.12),
      Offset(center.dx + radius * 0.18, center.dy + radius * 0.64),
      Offset(center.dx - radius * 0.2, center.dy - radius * 0.52),
    ];

    for (final point in points) {
      canvas.drawCircle(
        point,
        6,
        Paint()..color = AlterPalette.aura.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        point,
        14,
        Paint()..color = AlterPalette.aura.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity});

  final OpportunitySignal opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  opportunity.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumChip(
                label: '${(opportunity.score * 100).round()}',
                selected: true,
                icon: LucideIcons.zap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            opportunity.evidence,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: opportunity.score,
              minHeight: 8,
              backgroundColor: AlterPalette.aura.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AlterPalette.aura,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(label: opportunity.category),
              PremiumChip(label: opportunity.source, icon: LucideIcons.globe),
              PremiumChip(label: opportunity.window, icon: LucideIcons.clock),
            ],
          ),
        ],
      ),
    );
  }
}
