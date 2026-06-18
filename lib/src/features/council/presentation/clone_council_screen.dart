import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/widgets.dart';
import '../../../domain/entities/alter_models.dart';
import '../../shared/application/alter_data_providers.dart';
import '../application/council_debate_controller.dart';

class CloneCouncilScreen extends ConsumerStatefulWidget {
  const CloneCouncilScreen({super.key});

  @override
  ConsumerState<CloneCouncilScreen> createState() => _CloneCouncilScreenState();
}

class _CloneCouncilScreenState extends ConsumerState<CloneCouncilScreen> {
  final _topicController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debate = ref.watch(councilDebateControllerProvider);
    final agents = ref.watch(cloneCouncilProvider);
    final theme = Theme.of(context);

    final agentItems = agents.asData?.value ?? const <CloneAgent>[];
    final doneCount = debate.entries
        .where((e) => e.status == AgentStatus.done)
        .length;
    final consensusPct = debate.entries.isEmpty
        ? '--'
        : '${((doneCount / debate.entries.length) * 100).round()}%';
    final activeAgents = debate.entries.isNotEmpty
        ? '$doneCount/${debate.entries.length}'
        : '${agentItems.length}';

    return DeepScaffold(
      title: 'CLONE COUNCIL',
      subtitle:
          'Multi-agent reasoning with consensus, dissent, and next action traceability.',
      child: ListView(
        children: [
          ResponsiveGrid(
            mediumColumns: 3,
            expandedColumns: 3,
            children: [
              MetricTile(
                label: 'Council consensus',
                value: consensusPct,
                icon: LucideIcons.messages_square,
                accent: AlterPalette.iris,
              ),
              MetricTile(
                label: 'Active agents',
                value: activeAgents,
                icon: LucideIcons.bot,
                accent: AlterPalette.cyan,
              ),
              MetricTile(
                label: 'Action quality',
                value: debate.hasResult && debate.steps.isNotEmpty
                    ? 'Ready'
                    : '--',
                icon: LucideIcons.shield_check,
                accent: AlterPalette.mint,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Convene the council',
                  subtitle:
                      'Ask the council a strategic question and get 4 parallel AI perspectives.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _topicController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Strategic question',
                    hintText: 'Should I pivot my startup to enterprise sales?',
                    prefixIcon: Icon(LucideIcons.circle_question_mark),
                  ),
                  onSubmitted: (_) => _runDebate(),
                ),
                const SizedBox(height: 14),
                PremiumButton(
                  label: debate.isDebating
                      ? 'Council deliberating…'
                      : 'Convene Council',
                  icon: debate.isDebating
                      ? LucideIcons.loader
                      : LucideIcons.sparkles,
                  onPressed: debate.isDebating ? null : _runDebate,
                ),
                if (debate.error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    debate.error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AlterPalette.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (debate.entries.isNotEmpty) ...[
            ResponsiveGrid(
              mediumColumns: 2,
              expandedColumns: 2,
              children: [
                for (final entry in debate.entries)
                  _AgentDebateCard(
                    entry: entry,
                  ).animate().fadeIn(duration: 360.ms).slideY(begin: 0.04),
              ],
            ),
          ] else
            agents.when(
              data: (items) => items.isEmpty
                  ? const _EmptyCouncil()
                  : ResponsiveGrid(
                      mediumColumns: 2,
                      expandedColumns: 2,
                      children: [
                        for (final agent in items)
                          _AgentCard(agent: agent)
                              .animate()
                              .fadeIn(duration: 360.ms)
                              .slideY(begin: 0.04),
                      ],
                    ),
              loading: () => const GlassPanel(
                child: SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) =>
                  GlassPanel(child: Text('Unable to load council: $e')),
            ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Council output',
                  subtitle: debate.hasResult
                      ? 'Based on debate on: "${debate.topic}"'
                      : 'Run a council debate to generate recommendations.',
                  trailing: PremiumChip(
                    label: 'Consensus',
                    selected: true,
                    icon: LucideIcons.check,
                  ),
                ),
                const SizedBox(height: 18),
                if (debate.hasResult && debate.steps.isNotEmpty)
                  ...debate.steps.asMap().entries.map(
                    (e) => _DecisionStep(
                      number: '0${e.key + 1}',
                      title: e.value,
                      color: [
                        AlterPalette.cyan,
                        AlterPalette.iris,
                        AlterPalette.aura,
                      ][e.key % 3],
                    ),
                  )
                else
                  Text(
                    'No council output yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.58,
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

  void _runDebate() {
    FocusScope.of(context).unfocus();
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    ref.read(councilDebateControllerProvider.notifier).debate(topic);
  }
}

class _EmptyCouncil extends StatelessWidget {
  const _EmptyCouncil();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        children: [
          const Icon(LucideIcons.bot, size: 40, color: AlterPalette.iris),
          const SizedBox(height: 12),
          Text(
            'No council agents loaded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect the backend or run a debate to populate real agent output.',
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

class _AgentDebateCard extends StatelessWidget {
  const _AgentDebateCard({required this.entry});

  final AgentDebateEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThinking = entry.status == AgentStatus.thinking;
    final isFailed = entry.status == AgentStatus.failed;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: entry.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(LucideIcons.bot, color: entry.accent, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      entry.role,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.56,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isThinking)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: entry.accent,
                  ),
                )
              else
                PremiumChip(
                  label: isFailed ? 'Error' : 'Done',
                  selected: !isFailed,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isThinking)
            Text(
              'Deliberating…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              entry.response,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.42),
            ),
          if (!isThinking) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: isFailed ? 0 : 0.80 + (entry.name.length % 8) * 0.02,
                minHeight: 7,
                backgroundColor: entry.accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFailed ? AlterPalette.danger : entry.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final CloneAgent agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: agent.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(LucideIcons.bot, color: agent.accent, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      agent.role,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.56,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PremiumChip(label: agent.state, selected: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            agent.summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: agent.confidence,
              minHeight: 7,
              backgroundColor: agent.accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(agent.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionStep extends StatelessWidget {
  const _DecisionStep({
    required this.number,
    required this.title,
    required this.color,
  });

  final String number;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  number,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
