import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../application/mission_control_provider.dart';
import '../data/mission_control_api_client.dart';
import '../domain/mission_control_models.dart';

class MissionControlScreen extends ConsumerWidget {
  const MissionControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(missionControlProvider);
    final snapshot = snapshotAsync.value ?? fallbackMissionControlSnapshot;
    final isSyncing = snapshotAsync.isLoading && !snapshotAsync.hasValue;
    final hasApiError = snapshotAsync.hasError && !snapshotAsync.hasValue;
    final theme = Theme.of(context);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 8),
                    Text(
                      snapshot.activeObjective,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!context.isCompact) ...[
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PremiumChip(
                      label: snapshot.operatorName,
                      selected: true,
                      icon: LucideIcons.shield_check,
                    ),
                    const SizedBox(height: 8),
                    PremiumChip(
                      label: hasApiError
                          ? 'Gateway offline'
                          : '${snapshot.backendStatus} backend',
                      selected: !hasApiError && snapshot.backendStatus == 'ok',
                      icon: hasApiError
                          ? LucideIcons.cloud_off
                          : LucideIcons.server,
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (isSyncing) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 4),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: 'Phone uplink',
                selected: true,
                icon: LucideIcons.smartphone,
              ),
              PremiumChip(
                label: 'Laptop command',
                selected: true,
                icon: LucideIcons.laptop,
              ),
              PremiumChip(
                label: 'Live ops',
                selected: !hasApiError,
                icon: LucideIcons.activity,
              ),
              if (snapshot.degradedServices.isNotEmpty)
                PremiumChip(
                  label: '${snapshot.degradedServices.length} degraded',
                  icon: LucideIcons.triangle_alert,
                ),
            ],
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              for (final metric in snapshot.metrics)
                MetricTile(
                  label: metric.label,
                  value: metric.value,
                  detail: metric.detail,
                  icon: _moduleIcon(metric.moduleId),
                  accent: _moduleColor(metric.moduleId),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const _FutureTwinPanel(),
          const SizedBox(height: 18),
          const _ProofCapturePanel(),
          const SizedBox(height: 18),
          const _IntelligenceKernelPanel(),
          const SizedBox(height: 18),
          if (context.isExpanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 9,
                  child: _SurfacePanel(
                    title: 'Phone Field Layer',
                    subtitle: 'Voice, camera, and NFC capture the world.',
                    icon: LucideIcons.smartphone,
                    modules: snapshot.phoneModules,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(flex: 12, child: _MissionMap(snapshot: snapshot)),
                const SizedBox(width: 14),
                Expanded(
                  flex: 10,
                  child: _SurfacePanel(
                    title: 'Laptop Strategy Layer',
                    subtitle: 'Timelines, agents, radar, graph, reputation.',
                    icon: LucideIcons.laptop,
                    modules: snapshot.laptopModules,
                  ),
                ),
              ],
            )
          else ...[
            _MissionMap(snapshot: snapshot),
            const SizedBox(height: 14),
            _SurfacePanel(
              title: 'Phone Field Layer',
              subtitle: 'Voice, camera, and NFC capture the world.',
              icon: LucideIcons.smartphone,
              modules: snapshot.phoneModules,
            ),
            const SizedBox(height: 14),
            _SurfacePanel(
              title: 'Laptop Strategy Layer',
              subtitle: 'Timelines, agents, radar, graph, reputation.',
              icon: LucideIcons.laptop,
              modules: snapshot.laptopModules,
            ),
          ],
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 2,
            children: [
              _TimelinePanel(snapshot: snapshot),
              _EventPanel(events: snapshot.events),
            ],
          ),
        ],
      ),
    );
  }
}

class _FutureTwinPanel extends ConsumerStatefulWidget {
  const _FutureTwinPanel();

  @override
  ConsumerState<_FutureTwinPanel> createState() => _FutureTwinPanelState();
}

class _FutureTwinPanelState extends ConsumerState<_FutureTwinPanel> {
  late final TextEditingController _objectiveController;
  late final TextEditingController _prototypeEvidenceController;
  late final TextEditingController _voiceEvidenceController;
  late final TextEditingController _marketEvidenceController;

  @override
  void initState() {
    super.initState();
    _objectiveController = TextEditingController();
    _prototypeEvidenceController = TextEditingController();
    _voiceEvidenceController = TextEditingController();
    _marketEvidenceController = TextEditingController();
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    _prototypeEvidenceController.dispose();
    _voiceEvidenceController.dispose();
    _marketEvidenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twin = ref.watch(futureTwinControllerProvider);
    void runFutureTwin() {
      ref
          .read(futureTwinControllerProvider.notifier)
          .buildTwin(
            objective: _objectiveController.text,
            evidence: _evidenceInputs(),
          );
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Future Twin',
            subtitle:
                'Compares ambition with evidence, predicts drift, and compiles action.',
            trailing: PremiumButton(
              label: twin.isRunning ? 'Modeling' : 'Build Twin',
              compact: true,
              icon: twin.isRunning
                  ? LucideIcons.loader
                  : LucideIcons.scan_search,
              onPressed: twin.isRunning ? null : runFutureTwin,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _objectiveController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Future objective',
              prefixIcon: Icon(LucideIcons.orbit),
            ),
            onSubmitted: (_) => runFutureTwin(),
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            mediumColumns: 1,
            expandedColumns: 3,
            children: [
              TextField(
                controller: _prototypeEvidenceController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Product evidence',
                  prefixIcon: Icon(LucideIcons.box),
                ),
              ),
              TextField(
                controller: _voiceEvidenceController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Behavior evidence',
                  prefixIcon: Icon(LucideIcons.audio_waveform),
                ),
              ),
              TextField(
                controller: _marketEvidenceController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Market evidence',
                  prefixIcon: Icon(LucideIcons.radar),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: twin.isRunning
                    ? 'Modeling Future Twin'
                    : 'Build Future Twin',
                selected: true,
                icon: twin.isRunning
                    ? LucideIcons.loader
                    : LucideIcons.sparkles,
                onTap: twin.isRunning ? null : runFutureTwin,
              ),
              PremiumChip(
                label: 'Evidence -> trajectory -> action',
                selected: true,
                icon: LucideIcons.workflow,
              ),
              PremiumChip(
                label: 'Writes memory',
                selected: true,
                icon: LucideIcons.database_zap,
              ),
            ],
          ),
          if (twin.isRunning) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
          ],
          if (twin.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              twin.errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (twin.result != null) ...[
            const SizedBox(height: 16),
            _FutureTwinResultPanel(result: twin.result!),
          ],
        ],
      ),
    );
  }

  List<FutureTwinEvidenceInput> _evidenceInputs() {
    return [
      _futureEvidence(
        evidenceType: 'project_artifact',
        title: 'Project artifact',
        summary: _prototypeEvidenceController.text,
        source: 'mission_control',
        confidence: 0.9,
      ),
      _futureEvidence(
        evidenceType: 'behavior_signal',
        title: 'Behavior signal',
        summary: _voiceEvidenceController.text,
        source: 'voice_runtime',
        confidence: 0.86,
      ),
      _futureEvidence(
        evidenceType: 'market_signal',
        title: 'Market signal',
        summary: _marketEvidenceController.text,
        source: 'manual_entry',
        confidence: 0.74,
      ),
    ].nonNulls.toList(growable: false);
  }

  FutureTwinEvidenceInput? _futureEvidence({
    required String evidenceType,
    required String title,
    required String summary,
    required String source,
    required double confidence,
  }) {
    final clean = summary.trim();
    if (clean.isEmpty) return null;
    return FutureTwinEvidenceInput(
      evidenceType: evidenceType,
      title: title,
      summary: clean,
      source: source,
      confidence: confidence,
    );
  }
}

class _FutureTwinResultPanel extends StatelessWidget {
  const _FutureTwinResultPanel({required this.result});

  final FutureTwinResult result;

  @override
  Widget build(BuildContext context) {
    final trajectory = result.trajectory;
    final confidence = (result.confidenceScore * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AlterPalette.iris.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AlterPalette.iris.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PremiumChip(
                    label: '$confidence% twin confidence',
                    selected: result.confidenceScore >= 0.72,
                    icon: LucideIcons.brain_circuit,
                  ),
                  PremiumChip(
                    label: result.memorySaved
                        ? 'Twin memory saved'
                        : 'Memory pending',
                    selected: result.memorySaved,
                    icon: result.memorySaved
                        ? LucideIcons.database_zap
                        : LucideIcons.database,
                  ),
                  PremiumChip(
                    label: trajectory.currentTrajectory,
                    selected: trajectory.driftRisk < 60,
                    icon: LucideIcons.route,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.identitySummary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.dailyQuestion,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlterPalette.iris,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 4,
          children: [
            MetricTile(
              label: 'Alignment',
              value: '${trajectory.alignmentScore.round()}',
              detail: 'Stated future vs current evidence.',
              icon: LucideIcons.target,
              accent: AlterPalette.mint,
            ),
            MetricTile(
              label: 'Execution',
              value: '${trajectory.executionVelocity.round()}',
              detail: 'Follow-through and proof velocity.',
              icon: LucideIcons.activity,
              accent: AlterPalette.iris,
            ),
            MetricTile(
              label: 'Drift Risk',
              value: '${trajectory.driftRisk.round()}',
              detail: trajectory.predicted90DayFuture,
              icon: LucideIcons.triangle_alert,
              accent: AlterPalette.aura,
            ),
            MetricTile(
              label: 'Best Future',
              value: trajectory.bestAlternativeFuture,
              detail: 'Highest expected-value path.',
              icon: LucideIcons.sparkles,
              accent: AlterPalette.cyan,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TrajectoryPanel(trajectory: trajectory),
        const SizedBox(height: 14),
        _ActionCompilerPanel(action: result.action),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 2,
          children: [
            _EvidenceEnginePanel(signals: result.evidenceSignals),
            _ArbitragePanel(moves: result.opportunityArbitrage),
          ],
        ),
        const SizedBox(height: 14),
        _ResultListColumn(
          title: 'Model Updates',
          icon: LucideIcons.refresh_ccw,
          items: result.modelUpdates,
        ),
      ],
    );
  }
}

class _TrajectoryPanel extends StatelessWidget {
  const _TrajectoryPanel({required this.trajectory});

  final FutureTwinTrajectory trajectory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Life Trajectory',
            subtitle: 'Current curve, predicted 90-day curve, and best case.',
            trailing: Icon(
              LucideIcons.chart_no_axes_combined,
              color: AlterPalette.iris,
            ),
          ),
          const SizedBox(height: 14),
          for (final point in trajectory.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrajectoryPointRow(point: point),
            ),
        ],
      ),
    );
  }
}

class _TrajectoryPointRow extends StatelessWidget {
  const _TrajectoryPointRow({required this.point});

  final TrajectoryPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                point.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${point.predictedScore.round()} / ${point.bestCaseScore.round()}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AlterPalette.iris,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ScoreRail(
          current: point.currentScore,
          predicted: point.predictedScore,
          bestCase: point.bestCaseScore,
        ),
      ],
    );
  }
}

class _ScoreRail extends StatelessWidget {
  const _ScoreRail({
    required this.current,
    required this.predicted,
    required this.bestCase,
  });

  final double current;
  final double predicted;
  final double bestCase;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final currentWidth = width * (current.clamp(0, 100) / 100);
        final predictedWidth = width * (predicted.clamp(0, 100) / 100);
        final bestWidth = width * (bestCase.clamp(0, 100) / 100);
        return SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: bestWidth,
                height: 7,
                decoration: BoxDecoration(
                  color: AlterPalette.cyan.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: predictedWidth,
                height: 7,
                decoration: BoxDecoration(
                  gradient: AlterPalette.premiumGradient,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Positioned(
                left: math.max(0, math.min(width - 10, currentWidth - 5)),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AlterPalette.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AlterPalette.iris, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCompilerPanel extends StatelessWidget {
  const _ActionCompilerPanel({required this.action});

  final CompiledFutureAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.mint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Action Compiler',
            subtitle: 'Recommendation converted into proof, deadline, metric.',
            trailing: PremiumChip(
              label: '${action.leverageScore.round()} leverage',
              selected: action.leverageScore >= 70,
              icon: LucideIcons.zap,
            ),
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              _PlanTile(
                icon: LucideIcons.clipboard_check,
                label: 'Action',
                value: action.title,
              ),
              _PlanTile(
                icon: LucideIcons.timer,
                label: 'Deadline',
                value: action.deadline,
              ),
              _PlanTile(
                icon: LucideIcons.target,
                label: 'Metric',
                value: action.successMetric,
              ),
              _PlanTile(
                icon: LucideIcons.forward,
                label: 'First step',
                value: action.firstStep,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            action.whyNow,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.35,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final proof in action.proofRequired)
                PremiumChip(
                  label: proof,
                  selected: true,
                  icon: LucideIcons.badge_check,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceEnginePanel extends StatelessWidget {
  const _EvidenceEnginePanel({required this.signals});

  final List<EvidenceSignal> signals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Evidence Engine',
            subtitle: 'Proof that updates the twin.',
            trailing: Icon(LucideIcons.scan_eye, color: AlterPalette.iris),
          ),
          const SizedBox(height: 12),
          for (final signal in signals.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          signal.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PremiumChip(
                        label: '${signal.impactScore.round()}',
                        selected: signal.impactScore >= 70,
                        icon: signal.memorySaved
                            ? LucideIcons.database_zap
                            : LucideIcons.gauge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
                      height: 1.34,
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

class _ArbitragePanel extends StatelessWidget {
  const _ArbitragePanel({required this.moves});

  final List<OpportunityArbitrageMove> moves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.aura.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.aura.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Opportunity Arbitrage',
            subtitle: 'Leverage moves this week.',
            trailing: Icon(LucideIcons.radar, color: AlterPalette.aura),
          ),
          const SizedBox(height: 12),
          for (final move in moves.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          move.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PremiumChip(
                        label: '${move.leverageScore.round()} leverage',
                        selected: move.leverageScore >= 70,
                        icon: LucideIcons.zap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    move.whyThisMatters,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
                      height: 1.34,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    move.firstStep,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AlterPalette.aura,
                      fontWeight: FontWeight.w800,
                      height: 1.34,
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

class _ProofCapturePanel extends ConsumerStatefulWidget {
  const _ProofCapturePanel();

  @override
  ConsumerState<_ProofCapturePanel> createState() => _ProofCapturePanelState();
}

class _ProofCapturePanelState extends ConsumerState<_ProofCapturePanel> {
  late final TextEditingController _objectiveController;
  late final TextEditingController _goalController;
  late final TextEditingController _actionController;
  late final TextEditingController _artifactController;
  late final TextEditingController _conversationController;
  late final TextEditingController _applicationController;

  @override
  void initState() {
    super.initState();
    _objectiveController = TextEditingController();
    _goalController = TextEditingController();
    _actionController = TextEditingController();
    _artifactController = TextEditingController();
    _conversationController = TextEditingController();
    _applicationController = TextEditingController();
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    _goalController.dispose();
    _actionController.dispose();
    _artifactController.dispose();
    _conversationController.dispose();
    _applicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proof = ref.watch(proofCaptureControllerProvider);
    void captureProof() {
      ref
          .read(proofCaptureControllerProvider.notifier)
          .capture(
            objective: _objectiveController.text,
            linkedGoal: _goalController.text,
            linkedAction: _actionController.text,
            evidence: _evidenceInputs(),
          );
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Proof Capture OS',
            subtitle:
                'Evidence inbox, proof graph, daily briefing, trust update.',
            trailing: PremiumButton(
              label: proof.isRunning ? 'Capturing' : 'Capture Proof',
              compact: true,
              icon: proof.isRunning ? LucideIcons.loader : LucideIcons.inbox,
              onPressed: proof.isRunning ? null : captureProof,
            ),
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            mediumColumns: 1,
            expandedColumns: 3,
            children: [
              TextField(
                controller: _objectiveController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Future this proof updates',
                  prefixIcon: Icon(LucideIcons.orbit),
                ),
              ),
              TextField(
                controller: _goalController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Linked goal',
                  prefixIcon: Icon(LucideIcons.target),
                ),
              ),
              TextField(
                controller: _actionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Linked action',
                  prefixIcon: Icon(LucideIcons.clipboard_check),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            mediumColumns: 1,
            expandedColumns: 3,
            children: [
              TextField(
                controller: _artifactController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Artifact proof',
                  prefixIcon: Icon(LucideIcons.box),
                ),
              ),
              TextField(
                controller: _conversationController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Conversation proof',
                  prefixIcon: Icon(LucideIcons.messages_square),
                ),
              ),
              TextField(
                controller: _applicationController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Opportunity proof',
                  prefixIcon: Icon(LucideIcons.send),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: proof.isRunning
                    ? 'Writing proof memory'
                    : 'Capture Evidence',
                selected: true,
                icon: proof.isRunning
                    ? LucideIcons.loader
                    : LucideIcons.database_zap,
                onTap: proof.isRunning ? null : captureProof,
              ),
              PremiumChip(
                label: 'Goal -> Action -> Evidence -> Twin',
                selected: true,
                icon: LucideIcons.workflow,
              ),
              PremiumChip(
                label: 'Daily proof loop',
                selected: true,
                icon: LucideIcons.calendar_check,
              ),
            ],
          ),
          if (proof.isRunning) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
          ],
          if (proof.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              proof.errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (proof.result != null) ...[
            const SizedBox(height: 16),
            _ProofCaptureResultPanel(result: proof.result!),
          ],
        ],
      ),
    );
  }

  List<ProofEvidenceInput> _evidenceInputs() {
    return [
      _proofEvidence(
        evidenceType: 'project_artifact',
        title: 'Project artifact',
        summary: _artifactController.text,
        source: 'mission_control',
        confidence: 0.9,
      ),
      _proofEvidence(
        evidenceType: 'user_conversation',
        title: 'User conversation',
        summary: _conversationController.text,
        source: 'manual_entry',
        confidence: 0.78,
      ),
      _proofEvidence(
        evidenceType: 'opportunity_application',
        title: 'Opportunity application',
        summary: _applicationController.text,
        source: 'manual_entry',
        confidence: 0.72,
      ),
    ].nonNulls.toList(growable: false);
  }

  ProofEvidenceInput? _proofEvidence({
    required String evidenceType,
    required String title,
    required String summary,
    required String source,
    required double confidence,
  }) {
    final clean = summary.trim();
    if (clean.isEmpty) return null;
    return ProofEvidenceInput(
      evidenceType: evidenceType,
      title: title,
      summary: clean,
      source: source,
      confidence: confidence,
    );
  }
}

class _ProofCaptureResultPanel extends StatelessWidget {
  const _ProofCaptureResultPanel({required this.result});

  final ProofCaptureResult result;

  @override
  Widget build(BuildContext context) {
    final trust = result.trustProfile;
    final delta = result.futureTwinDelta;
    final memoryCount = result.evidenceRecords
        .where((item) => item.memorySaved)
        .length;
    final reputationCount = result.evidenceRecords
        .where((item) => item.reputationLogged)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AlterPalette.mint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AlterPalette.mint.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PremiumChip(
                    label: '${result.evidenceRecords.length} proof items',
                    selected: true,
                    icon: LucideIcons.inbox,
                  ),
                  PremiumChip(
                    label: '$memoryCount memory nodes',
                    selected: memoryCount == result.evidenceRecords.length,
                    icon: LucideIcons.database_zap,
                  ),
                  PremiumChip(
                    label: '$reputationCount reputation events',
                    selected: reputationCount == result.evidenceRecords.length,
                    icon: LucideIcons.trophy,
                  ),
                  PremiumChip(
                    label: '${trust.followThroughScore.round()} follow-through',
                    selected: trust.followThroughScore >= 70,
                    icon: LucideIcons.activity,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                delta.summary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                delta.recommendedRecalibration,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlterPalette.mint,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 4,
          children: [
            MetricTile(
              label: 'Alignment Delta',
              value: '+${delta.alignmentDelta.toStringAsFixed(1)}',
              detail: 'Proof effect on stated future.',
              icon: LucideIcons.target,
              accent: AlterPalette.mint,
            ),
            MetricTile(
              label: 'Execution Delta',
              value: '+${delta.executionDelta.toStringAsFixed(1)}',
              detail: 'Proof effect on follow-through.',
              icon: LucideIcons.activity,
              accent: AlterPalette.iris,
            ),
            MetricTile(
              label: 'Drift Delta',
              value: delta.driftDelta.toStringAsFixed(1),
              detail: 'Negative means drift risk decreased.',
              icon: LucideIcons.triangle_alert,
              accent: AlterPalette.aura,
            ),
            MetricTile(
              label: 'Trust',
              value: trust.trustLevel.isEmpty ? 'baseline' : trust.trustLevel,
              detail: '${trust.executionStreak} high-signal proof streak.',
              icon: LucideIcons.shield_check,
              accent: AlterPalette.cyan,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DailyProofBriefingPanel(briefing: result.dailyBriefing),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 2,
          children: [
            _EvidenceInboxPanel(records: result.evidenceRecords),
            _ProofGraphPanel(
              nodes: result.graphNodes,
              edges: result.graphEdges,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          mediumColumns: 2,
          expandedColumns: 2,
          children: [
            _ResultListColumn(
              title: 'Next Proof Actions',
              icon: LucideIcons.check_check,
              items: result.nextActions,
            ),
            _ResultListColumn(
              title: 'Trust Profile',
              icon: LucideIcons.shield_check,
              items: [...trust.strengths, ...trust.risks],
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyProofBriefingPanel extends StatelessWidget {
  const _DailyProofBriefingPanel({required this.briefing});

  final DailyProofBriefing briefing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.iris.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.iris.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Daily Proof Briefing',
            subtitle: 'Morning intent, night outcome, proactive nudges.',
            trailing: Icon(
              LucideIcons.calendar_check,
              color: AlterPalette.iris,
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            mediumColumns: 1,
            expandedColumns: 3,
            children: [
              _PlanTile(
                icon: LucideIcons.sun,
                label: 'Morning',
                value: briefing.morningQuestion,
              ),
              _PlanTile(
                icon: LucideIcons.moon,
                label: 'Night',
                value: briefing.eveningQuestion,
              ),
              _PlanTile(
                icon: LucideIcons.bell,
                label: 'Drift alert',
                value: briefing.driftAlert,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing.recommendedProof,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AlterPalette.iris,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final notification in briefing.pushNotifications)
                PremiumChip(
                  label: notification,
                  selected: true,
                  icon: LucideIcons.bell_ring,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceInboxPanel extends StatelessWidget {
  const _EvidenceInboxPanel({required this.records});

  final List<ProofEvidenceRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Evidence Inbox',
            subtitle: 'Proof converted into memory and reputation.',
            trailing: Icon(LucideIcons.inbox, color: AlterPalette.mint),
          ),
          const SizedBox(height: 12),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PremiumChip(
                        label: '${record.impactScore.round()} impact',
                        selected: record.impactScore >= 70,
                        icon: record.memorySaved
                            ? LucideIcons.database_zap
                            : LucideIcons.gauge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.trajectoryEffect,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AlterPalette.mint,
                      fontWeight: FontWeight.w800,
                      height: 1.34,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    record.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.62,
                      ),
                      height: 1.34,
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

class _ProofGraphPanel extends StatelessWidget {
  const _ProofGraphPanel({required this.nodes, required this.edges});

  final List<ProofGraphNode> nodes;
  final List<ProofGraphEdge> edges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.cyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.cyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Proof Graph',
            subtitle: 'Goal -> action -> evidence -> memory -> Future Twin.',
            trailing: Icon(LucideIcons.network, color: AlterPalette.cyan),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final node in nodes.take(8))
                PremiumChip(
                  label: '${node.kind}: ${node.label}',
                  selected: node.status != 'skipped',
                  icon: _proofNodeIcon(node.kind),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final edge in edges.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '${edge.fromNode} ${edge.label} ${edge.toNode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _proofNodeIcon(String kind) {
  return switch (kind) {
    'goal' => LucideIcons.target,
    'action' => LucideIcons.clipboard_check,
    'evidence' => LucideIcons.inbox,
    'memory' => LucideIcons.database_zap,
    'future_twin' => LucideIcons.brain_circuit,
    'daily_briefing' => LucideIcons.calendar_check,
    _ => LucideIcons.circle,
  };
}

class _IntelligenceKernelPanel extends ConsumerStatefulWidget {
  const _IntelligenceKernelPanel();

  @override
  ConsumerState<_IntelligenceKernelPanel> createState() =>
      _IntelligenceKernelPanelState();
}

class _IntelligenceKernelPanelState
    extends ConsumerState<_IntelligenceKernelPanel> {
  late final TextEditingController _controller;
  late final TextEditingController _happenedController;
  late final TextEditingController _learnedController;
  late final TextEditingController _metricController;
  bool _didIt = true;
  double _outcomeScore = 0.72;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _happenedController = TextEditingController();
    _learnedController = TextEditingController();
    _metricController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _happenedController.dispose();
    _learnedController.dispose();
    _metricController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kernel = ref.watch(intelligenceKernelControllerProvider);
    final report = kernel.report;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Decision Intelligence',
            subtitle:
                'Memory, futures, agents, radar, and execution in one loop.',
            trailing: PremiumButton(
              label: kernel.isRunning ? 'Reasoning' : 'Run Decision Loop',
              compact: true,
              icon: kernel.isRunning ? LucideIcons.loader : LucideIcons.play,
              onPressed: kernel.isRunning
                  ? null
                  : () => ref
                        .read(intelligenceKernelControllerProvider.notifier)
                        .decide(_controller.text),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter the life or career decision to simulate',
              prefixIcon: Icon(LucideIcons.sparkles),
            ),
            onSubmitted: (_) => ref
                .read(intelligenceKernelControllerProvider.notifier)
                .decide(_controller.text),
          ),
          if (kernel.isRunning) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
          ],
          if (kernel.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              kernel.errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 18),
            _DecisionReportHeader(report: report),
            const SizedBox(height: 16),
            _ExperimentPlanPanel(plan: report.experimentPlan),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mediumColumns: 2,
              expandedColumns: 3,
              children: [
                for (final option in report.futureOptions)
                  _FutureOptionCard(
                    option: option,
                    selected: option.futureId == report.recommendedFuture,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(
              mediumColumns: 2,
              expandedColumns: 4,
              children: [
                _ResultListColumn(
                  title: 'Next Actions',
                  icon: LucideIcons.check_check,
                  items: report.nextActions,
                ),
                _ResultListColumn(
                  title: 'Opportunities',
                  icon: LucideIcons.zap,
                  items: report.opportunities,
                ),
                _ResultListColumn(
                  title: 'Risks',
                  icon: LucideIcons.triangle_alert,
                  items: report.risks,
                ),
                _ResultListColumn(
                  title: 'Memory Context',
                  icon: LucideIcons.brain,
                  items: report.memoryContext.isEmpty
                      ? <String>[
                          report.memorySaved
                              ? 'New decision memory saved.'
                              : 'No relevant memory was found yet.',
                        ]
                      : report.memoryContext,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumChip(
                  label: report.memorySaved ? 'Memory saved' : 'Memory skipped',
                  selected: report.memorySaved,
                  icon: report.memorySaved
                      ? LucideIcons.database_zap
                      : LucideIcons.database,
                ),
                for (final match in report.opportunityMatches.take(3))
                  PremiumChip(
                    label: match,
                    selected: true,
                    icon: LucideIcons.radar,
                  ),
                for (final signal in report.signals)
                  PremiumChip(
                    label: signal.latencyMs == null
                        ? signal.title
                        : '${signal.title} ${signal.latencyMs}ms',
                    selected: signal.isHealthy,
                    icon: signal.isHealthy
                        ? LucideIcons.circle_check
                        : LucideIcons.circle_alert,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _OutcomeLearningPanel(
              didIt: _didIt,
              outcomeScore: _outcomeScore,
              happenedController: _happenedController,
              learnedController: _learnedController,
              metricController: _metricController,
              isSubmitting: kernel.isSubmittingOutcome,
              errorMessage: kernel.outcomeErrorMessage,
              result: kernel.outcomeResult,
              onDidItChanged: (value) => setState(() => _didIt = value),
              onOutcomeScoreChanged: (value) =>
                  setState(() => _outcomeScore = value),
              onSubmit: () => ref
                  .read(intelligenceKernelControllerProvider.notifier)
                  .recordOutcome(
                    didIt: _didIt,
                    whatHappened: _happenedController.text,
                    whatLearned: _learnedController.text,
                    successMetricResult: _metricController.text,
                    outcomeScore: _outcomeScore,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExperimentPlanPanel extends StatelessWidget {
  const _ExperimentPlanPanel({required this.plan});

  final ExperimentPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.mint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Experiment Plan',
            subtitle: 'Decision becomes action, metric, and memory.',
            trailing: Icon(LucideIcons.flask_conical, color: AlterPalette.mint),
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 4,
            children: [
              _PlanTile(
                icon: LucideIcons.clipboard_check,
                label: 'What to do',
                value: plan.action,
              ),
              _PlanTile(
                icon: LucideIcons.target,
                label: 'Why it matters',
                value: plan.whyItMatters,
              ),
              _PlanTile(
                icon: LucideIcons.calendar,
                label: 'Deadline',
                value: plan.deadline,
              ),
              _PlanTile(
                icon: LucideIcons.gauge,
                label: 'Success metric',
                value: plan.successMetric,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
              Icon(icon, size: 16, color: AlterPalette.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AlterPalette.mint,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              height: 1.34,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeLearningPanel extends StatelessWidget {
  const _OutcomeLearningPanel({
    required this.didIt,
    required this.outcomeScore,
    required this.happenedController,
    required this.learnedController,
    required this.metricController,
    required this.isSubmitting,
    required this.errorMessage,
    required this.result,
    required this.onDidItChanged,
    required this.onOutcomeScoreChanged,
    required this.onSubmit,
  });

  final bool didIt;
  final double outcomeScore;
  final TextEditingController happenedController;
  final TextEditingController learnedController;
  final TextEditingController metricController;
  final bool isSubmitting;
  final String errorMessage;
  final OutcomeUpdateResult? result;
  final ValueChanged<bool> onDidItChanged;
  final ValueChanged<double> onOutcomeScoreChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.iris.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.iris.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Outcome Learning',
            subtitle: 'Action, result, memory, reputation.',
            trailing: PremiumButton(
              label: isSubmitting ? 'Saving' : 'Save Outcome',
              compact: true,
              icon: isSubmitting ? LucideIcons.loader : LucideIcons.send,
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: 'Did it',
                selected: didIt,
                icon: LucideIcons.circle_check,
                onTap: () => onDidItChanged(true),
              ),
              PremiumChip(
                label: 'Not yet',
                selected: !didIt,
                icon: LucideIcons.circle_alert,
                onTap: () => onDidItChanged(false),
              ),
              PremiumChip(
                label: '${(outcomeScore * 100).round()}% outcome signal',
                selected: outcomeScore >= 0.65,
                icon: LucideIcons.gauge,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Slider(
            value: outcomeScore,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${(outcomeScore * 100).round()}%',
            onChanged: isSubmitting ? null : onOutcomeScoreChanged,
          ),
          const SizedBox(height: 8),
          ResponsiveGrid(
            mediumColumns: 1,
            expandedColumns: 3,
            children: [
              TextField(
                controller: happenedController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  prefixIcon: Icon(LucideIcons.history),
                ),
              ),
              TextField(
                controller: learnedController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What did you learn?',
                  prefixIcon: Icon(LucideIcons.book_open),
                ),
              ),
              TextField(
                controller: metricController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Success metric result',
                  prefixIcon: Icon(LucideIcons.target),
                ),
              ),
            ],
          ),
          if (isSubmitting) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
          ],
          if (errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            _OutcomeResultPanel(result: result!),
          ],
        ],
      ),
    );
  }
}

class _OutcomeResultPanel extends StatelessWidget {
  const _OutcomeResultPanel({required this.result});

  final OutcomeUpdateResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.mint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.mint.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: '${result.executionScore.round()} execution',
                selected: result.executionScore >= 70,
                icon: LucideIcons.badge_check,
              ),
              PremiumChip(
                label:
                    '${result.confidenceDelta >= 0 ? '+' : ''}${result.confidenceDelta.toStringAsFixed(2)} confidence',
                selected: result.confidenceDelta >= 0,
                icon: LucideIcons.refresh_ccw,
              ),
              if (result.reputationScore != null)
                PremiumChip(
                  label: '${result.reputationScore} trust',
                  selected: true,
                  icon: LucideIcons.trophy,
                ),
              PremiumChip(
                label: result.memorySaved
                    ? 'Outcome memory saved'
                    : 'Memory pending',
                selected: result.memorySaved,
                icon: result.memorySaved
                    ? LucideIcons.database_zap
                    : LucideIcons.database,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.nextRecommendation,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.memorySummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final update in result.profileUpdates.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                update,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DecisionReportHeader extends StatelessWidget {
  const _DecisionReportHeader({required this.report});

  final IntelligenceDecisionReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = (report.confidenceScore * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlterPalette.iris.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlterPalette.iris.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumChip(
                label: '$confidence% confidence',
                selected: confidence >= 70,
                icon: LucideIcons.gauge,
              ),
              PremiumChip(
                label: report.recommendedFuture,
                selected: true,
                icon: LucideIcons.route,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.recommendation,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.decisionSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureOptionCard extends StatelessWidget {
  const _FutureOptionCard({required this.option, required this.selected});

  final IntelligenceFutureOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AlterPalette.mint : AlterPalette.iris;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.32 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(icon: LucideIcons.git_branch, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.futureId,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PremiumChip(
                label: '${(option.successProbability * 100).round()}%',
                selected: selected,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            option.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.thesis,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniScore(
                  label: 'Opportunity',
                  value: option.opportunityScore,
                  color: AlterPalette.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniScore(
                  label: 'Risk',
                  value: option.riskScore,
                  color: AlterPalette.aura,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ResultListColumn extends StatelessWidget {
  const _ResultListColumn({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.38),
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
              Icon(icon, size: 17, color: AlterPalette.iris),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  height: 1.34,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.modules,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<MissionModule> modules;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: Icon(icon, color: AlterPalette.iris),
          ),
          const SizedBox(height: 16),
          for (final module in modules)
            _ModuleRow(
              module: module,
            ).animate().fadeIn(duration: 260.ms).moveY(begin: 8, end: 0),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final MissionModule module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _moduleColor(module.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(module.route),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconBox(icon: _moduleIcon(module.id), color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            module.status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.58,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PremiumChip(
                      label: '${(module.signal * 100).round()}%',
                      selected: module.signal >= 0.86,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: module.health,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PremiumChip(label: module.cadence),
                    for (final capability in module.capabilities.take(2))
                      PremiumChip(label: capability),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionMap extends StatelessWidget {
  const _MissionMap({required this.snapshot});

  final MissionControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: context.isCompact ? 420 : 560,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MissionMapPainter(
                  readiness: snapshot.readiness,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AlterPalette.premiumGradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AlterPalette.iris.withValues(alpha: 0.28),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 92,
                      height: 92,
                      child: Icon(
                        LucideIcons.command,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ALTER',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PremiumChip(
                    label: '${(snapshot.readiness * 100).round()}% ready',
                    selected: true,
                  ),
                ],
              ),
            ),
            _MapNode(
              alignment: const Alignment(-0.78, -0.64),
              module: snapshot.phoneModules[0],
            ),
            _MapNode(
              alignment: const Alignment(-0.84, 0.08),
              module: snapshot.phoneModules[1],
            ),
            _MapNode(
              alignment: const Alignment(-0.66, 0.68),
              module: snapshot.phoneModules[2],
            ),
            _MapNode(
              alignment: const Alignment(0.7, -0.72),
              module: snapshot.laptopModules[0],
            ),
            _MapNode(
              alignment: const Alignment(0.86, -0.22),
              module: snapshot.laptopModules[1],
            ),
            _MapNode(
              alignment: const Alignment(0.78, 0.24),
              module: snapshot.laptopModules[2],
            ),
            _MapNode(
              alignment: const Alignment(0.58, 0.72),
              module: snapshot.laptopModules[3],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({required this.alignment, required this.module});

  final Alignment alignment;
  final MissionModule module;

  @override
  Widget build(BuildContext context) {
    final color = _moduleColor(module.id);
    return Align(
      alignment: alignment,
      child: Tooltip(
        message: module.status,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(module.route),
          child: Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_moduleIcon(module.id), size: 17, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionMapPainter extends CustomPainter {
  const _MissionMapPainter({required this.readiness, required this.isDark});

  final double readiness;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final grid = Paint()
      ..color = (isDark ? Colors.white : AlterPalette.ink).withValues(
        alpha: isDark ? 0.07 : 0.06,
      )
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 24.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AlterPalette.iris.withValues(alpha: 0.28);
    for (var i = 0; i < 4; i++) {
      final radius = math.min(size.width, size.height) * (0.16 + i * 0.11);
      canvas.drawCircle(center, radius, ring);
    }

    final nodes = [
      Offset(size.width * 0.22, size.height * 0.18),
      Offset(size.width * 0.16, size.height * 0.54),
      Offset(size.width * 0.26, size.height * 0.84),
      Offset(size.width * 0.76, size.height * 0.15),
      Offset(size.width * 0.88, size.height * 0.39),
      Offset(size.width * 0.82, size.height * 0.62),
      Offset(size.width * 0.74, size.height * 0.86),
    ];
    for (final node in nodes) {
      canvas.drawLine(
        center,
        node,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AlterPalette.iris.withValues(alpha: 0.34),
              AlterPalette.cyan.withValues(alpha: 0.16),
            ],
          ).createShader(Rect.fromPoints(center, node))
          ..strokeWidth = 1.5,
      );
    }

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AlterPalette.mint.withValues(alpha: 0.82);
    final radius = math.min(size.width, size.height) * 0.31;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * readiness,
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant _MissionMapPainter oldDelegate) {
    return oldDelegate.readiness != readiness || oldDelegate.isDark != isDark;
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.snapshot});

  final MissionControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Future Timeline',
            subtitle: 'Near-term path from capture to execution.',
          ),
          const SizedBox(height: 18),
          _TimelineStep(
            label: 'Capture',
            detail: 'Voice, camera, and NFC feed memory.',
            color: AlterPalette.cyan,
            active: true,
          ),
          _TimelineStep(
            label: 'Reason',
            detail: 'Council and simulator test the move.',
            color: AlterPalette.iris,
            active: true,
          ),
          _TimelineStep(
            label: 'Route',
            detail: 'Radar and graph find leverage.',
            color: AlterPalette.mint,
            active: true,
          ),
          _TimelineStep(
            label: 'Trust',
            detail: 'Reputation engine measures follow-through.',
            color: AlterPalette.amber,
            active: snapshot.readiness > 0.88,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.detail,
    required this.color,
    required this.active,
  });

  final String label;
  final String detail;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 2,
                height: 44,
                color: color.withValues(alpha: 0.22),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.35,
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

class _EventPanel extends StatelessWidget {
  const _EventPanel({required this.events});

  final List<MissionEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Command Feed',
            subtitle: 'Cross-device intelligence stream.',
          ),
          const SizedBox(height: 14),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      event.time,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AlterPalette.iris,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.impact,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PremiumChip(label: event.source),
                      ],
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

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

IconData _moduleIcon(String id) {
  return switch (id) {
    'voice' => LucideIcons.mic,
    'camera' => LucideIcons.scan_eye,
    'nfc' => LucideIcons.nfc,
    'timelines' => LucideIcons.route,
    'council' => LucideIcons.messages_square,
    'radar' => LucideIcons.radar,
    'social' => LucideIcons.network,
    'reputation' => LucideIcons.trophy,
    _ => LucideIcons.activity,
  };
}

Color _moduleColor(String id) {
  return switch (id) {
    'voice' => AlterPalette.iris,
    'camera' => AlterPalette.cyan,
    'nfc' => AlterPalette.mint,
    'timelines' => AlterPalette.violet,
    'council' => AlterPalette.aura,
    'radar' => AlterPalette.amber,
    'social' => AlterPalette.cyan,
    'reputation' => AlterPalette.mint,
    _ => AlterPalette.iris,
  };
}
