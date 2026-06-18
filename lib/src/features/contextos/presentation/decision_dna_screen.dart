import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../application/decision_dna_controller.dart';

class DecisionDnaScreen extends ConsumerWidget {
  const DecisionDnaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dnaAsync = ref.watch(decisionDnaProvider);
    final theme = Theme.of(context);

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'DNA',
        subtitle:
            'What ALTER has learned about how you decide — from real outcomes, not guesses.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dnaAsync.when(
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => GlassPanel(child: Text('Could not load DNA: $e')),
            data: (dna) => _DnaBody(dna: dna),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DnaBody extends StatelessWidget {
  const _DnaBody({required this.dna});

  final DecisionDna dna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trustPct = (dna.trustScore * 100).round();
    final trustColor = dna.trustScore >= 0.7
        ? AlterPalette.mint
        : dna.trustScore >= 0.45
        ? AlterPalette.amber
        : AlterPalette.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow-through',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GradientText(
                    '$trustPct%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: trustColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(LucideIcons.dna, color: trustColor, size: 30),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (dna.outcomeCounts.isNotEmpty) ...[
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outcomes logged (${dna.totalOutcomes})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in dna.outcomeCounts.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: e.key.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: e.key.color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${e.key.label} · ${e.value}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: e.key.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final p in dna.patterns)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PatternCard(pattern: p),
          ),
      ],
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});

  final DnaPattern pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: AlterPalette.iris),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pattern.pattern,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(pattern.weight * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AlterPalette.iris,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pattern.evidence,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pattern.weight.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AlterPalette.iris.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AlterPalette.iris,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
