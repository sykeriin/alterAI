import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../../../domain/entities/alter_models.dart';
import '../../../domain/entities/alter_models.dart';
import '../../shared/application/alter_data_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../mission/application/mission_control_provider.dart';
import '../../mission/data/mission_control_api_client.dart';
import '../../reputation/application/reputation_score_provider.dart';

class ReputationDashboardScreen extends ConsumerWidget {
  const ReputationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(reputationEventsProvider);
    final gatewayScore = ref.watch(reputationScoreProvider);
    final theme = Theme.of(context);

    final liveScore = gatewayScore.asData?.value?.score ??
        (events.asData?.value != null
            ? 700 + events.value!.fold<int>(0, (sum, e) => sum + e.delta)
            : null);

    final trend = events.asData?.value != null
        ? events.value!.take(5).fold<int>(0, (sum, e) => sum + e.delta)
        : null;

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'REPUTATION',
        subtitle:
            'Track trust, responsiveness, delivery, and relationship quality as durable assets.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filled(
              tooltip: 'Log reputation event',
              style: IconButton.styleFrom(
                backgroundColor: AlterPalette.iris,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(LucideIcons.plus),
              onPressed: () => _showLogEventDialog(context, ref),
            ),
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              _ReputationScore(score: liveScore),
              MetricTile(
                label: 'Recent trend',
                value: trend != null
                    ? (trend >= 0 ? '+$trend' : '$trend')
                    : '+26',
                icon: trend != null && trend >= 0
                    ? LucideIcons.trending_up
                    : LucideIcons.trending_down,
                accent: trend != null && trend < 0
                    ? AlterPalette.danger
                    : AlterPalette.mint,
              ),
              MetricTile(
                label: 'Events logged',
                value: events.asData?.value?.length.toString() ?? '—',
                icon: LucideIcons.list_checks,
                accent: AlterPalette.amber,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Reputation vector',
                  subtitle: 'Signals are weighted by recency, trust, and impact.',
                ),
                const SizedBox(height: 18),
                _Bar(label: 'Reliability', value: 0.91, color: AlterPalette.mint),
                _Bar(label: 'Follow-through', value: 0.84, color: AlterPalette.iris),
                _Bar(label: 'Generosity', value: 0.77, color: AlterPalette.cyan),
                _Bar(label: 'Visibility', value: 0.68, color: AlterPalette.aura),
              ],
            ),
          ),
          const SizedBox(height: 18),
          events.when(
            data: (items) => items.isEmpty
                ? GlassPanel(
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.trophy,
                          size: 40,
                          color: AlterPalette.iris,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No events logged yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log reputation events to track your trust over time.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        PremiumButton(
                          label: 'Log first event',
                          icon: LucideIcons.plus,
                          compact: true,
                          onPressed: () => _showLogEventDialog(context, ref),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final event in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EventCard(event: event),
                        ),
                    ],
                  ),
            loading: () => const GlassPanel(
              child: SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Text('Unable to load reputation: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogEventDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _LogEventDialog(),
    );
    if (result == null) return;

    try {
      if (AlterGatewayConfig.isConfigured) {
        await ref.read(missionControlApiClientProvider).captureProof(
              objective: result['title']?.toString() ?? 'Reputation event',
              linkedGoal: 'Trust and follow-through',
              linkedAction: result['description']?.toString() ?? '',
              evidence: <ProofEvidenceInput>[
                ProofEvidenceInput(
                  evidenceType: 'reputation_event',
                  title: result['title']?.toString() ?? 'Event',
                  summary: result['description']?.toString() ?? '',
                  source: 'reputation_dashboard',
                  confidence: 0.8,
                ),
              ],
            );
        ref.invalidate(reputationScoreProvider);
      }

      final now = DateTime.now();
      final ts = '${now.day}/${now.month}/${now.year}';
      await ref.read(lifeOsMutationsProvider).insertReputationEvent(
            ReputationEvent(
              title: result['title'] as String,
              delta: result['delta'] as int,
              description: result['description'] as String? ?? '',
              timestamp: ts,
            ),
          );
      ref.invalidate(reputationEventsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reputation event logged locally.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log event: $e')),
        );
      }
    }
  }
}

class _LogEventDialog extends StatefulWidget {
  const _LogEventDialog();

  @override
  State<_LogEventDialog> createState() => _LogEventDialogState();
}

class _LogEventDialogState extends State<_LogEventDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _positive = true;
  int _magnitude = 10;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Reputation Event',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Event title *',
                prefixIcon: Icon(LucideIcons.star),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(LucideIcons.file_text),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Impact type',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Positive'),
                      icon: Icon(LucideIcons.trending_up, size: 14),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Negative'),
                      icon: Icon(LucideIcons.trending_down, size: 14),
                    ),
                  ],
                  selected: {_positive},
                  onSelectionChanged: (s) =>
                      setState(() => _positive = s.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Magnitude',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _positive ? '+$_magnitude' : '-$_magnitude',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _positive ? AlterPalette.mint : AlterPalette.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: _magnitude.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (v) => setState(() => _magnitude = v.round()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AlterPalette.iris,
                    ),
                    onPressed: _submit,
                    child: const Text('Log Event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, {
      'title': title,
      'delta': _positive ? _magnitude : -_magnitude,
      'description': _descCtrl.text.trim(),
    });
  }
}

class _ReputationScore extends StatelessWidget {
  const _ReputationScore({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayScore = score ?? 700;
    final label = displayScore >= 900
        ? 'Elite reputation'
        : displayScore >= 800
            ? 'High trust operator'
            : displayScore >= 700
                ? 'Trusted professional'
                : 'Building reputation';

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumChip(
            label: 'Live score',
            selected: true,
            icon: LucideIcons.trophy,
          ),
          const SizedBox(height: 20),
          GradientText(
            '$displayScore',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ReputationEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = event.delta >= 0;
    final color = positive ? AlterPalette.mint : AlterPalette.danger;
    return GlassPanel(
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Center(
                child: Text(
                  positive ? '+${event.delta}' : '${event.delta}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            event.timestamp,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
