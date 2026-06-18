import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/daytwin_controller.dart';
import '../application/decision_council_controller.dart';
import '../application/futuretwin_controller.dart';
import '../application/gemma_model_manager.dart';
import '../application/lifeshield_controller.dart';
import '../application/memory_engine.dart';
import '../application/openclaw_adapter.dart';
import '../domain/contextos_models.dart';
import '../domain/moment.dart';

class LifeShieldScreen extends ConsumerStatefulWidget {
  const LifeShieldScreen({super.key});

  @override
  ConsumerState<LifeShieldScreen> createState() => _LifeShieldScreenState();
}

class _LifeShieldScreenState extends ConsumerState<LifeShieldScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _haptic(RiskVerdict v) {
    switch (v) {
      case RiskVerdict.dangerous:
        HapticFeedback.heavyImpact();
      case RiskVerdict.needsVerification:
        HapticFeedback.mediumImpact();
      case RiskVerdict.caution:
        HapticFeedback.selectionClick();
      case RiskVerdict.safe:
        HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifeShieldControllerProvider);
    final notifier = ref.read(lifeShieldControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(lifeShieldControllerProvider, (prev, next) {
      final pv = prev?.analysis?.verdict;
      final nv = next.analysis?.verdict;
      if (nv != null && nv != pv) _haptic(nv);
    });

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
                      'LifeShield',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Understands the moment before you act — tap, pay, reply, scan, install.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PrivateModeToggle(
                on: state.privateMode,
                onTap: notifier.togglePrivateMode,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CaptureCard(
            controller: _controller,
            state: state,
            realGemma: ref.watch(edgeIsRealGemmaProvider),
            onChanged: notifier.setInput,
            onSelectSurface: notifier.setSource,
            onAnalyze: () {
              FocusScope.of(context).unfocus();
              notifier.capture();
            },
          ),
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InlineNote(
              icon: LucideIcons.triangle_alert,
              color: AlterPalette.amber,
              text: state.error,
            ),
          ],
          if (state.category != null) ...[
            const SizedBox(height: 16),
            _MomentTypeBar(
              category: state.category!,
              moment: state.moment,
            ).animate().fadeIn(duration: 280.ms),
          ],
          if (state.routedElsewhere) ...[
            const SizedBox(height: 12),
            _RoutedCard(
              category: state.category!,
              momentText: state.moment?.rawContent ?? state.input,
            ),
            if (state.extraction.activeRisks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ContextCard(extraction: state.extraction),
            ],
          ] else if (state.analysis != null) ...[
            const SizedBox(height: 12),
            _VerdictBanner(
              analysis: state.analysis!,
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05),
            const SizedBox(height: 12),
            _EdgeCheckCard(state: state, onRunCloud: notifier.runCloud),
            if (state.extraction.activeRisks.isNotEmpty ||
                state.extraction.requestedAction.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ContextCard(extraction: state.extraction),
            ],
            const SizedBox(height: 12),
            _MomentCard(analysis: state.analysis!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: LucideIcons.scan_search,
                    label: 'Proof',
                    color: AlterPalette.cyan,
                    onTap: () => _openProof(context, state.analysis!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: LucideIcons.shield_check,
                    label: state.analysis!.actions.isEmpty
                        ? 'Safe steps'
                        : 'Safe actions',
                    color: AlterPalette.mint,
                    onTap: () => _openActions(
                      context,
                      state.analysis!,
                      state.moment?.rawContent ?? state.input,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SecondaryActions(state: state),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openProof(BuildContext context, MomentAnalysis a) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProofSheet(analysis: a),
    );
  }

  void _openActions(BuildContext context, MomentAnalysis a, String excerpt) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(analysis: a, momentExcerpt: excerpt),
    );
  }
}

class _PrivateModeToggle extends StatelessWidget {
  const _PrivateModeToggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumChip(
      label: on ? 'Private' : 'Private off',
      selected: on,
      icon: on ? LucideIcons.lock : LucideIcons.lock_open,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.controller,
    required this.state,
    required this.realGemma,
    required this.onChanged,
    required this.onSelectSurface,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final LifeShieldState state;
  final bool realGemma;
  final ValueChanged<String> onChanged;
  final ValueChanged<MomentSource> onSelectSurface;
  final VoidCallback onAnalyze;

  static const _surfaces = [
    MomentSource.notification,
    MomentSource.shareSheet,
    MomentSource.camera,
    MomentSource.mic,
    MomentSource.qr,
    MomentSource.install,
    MomentSource.manual,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(state.source.icon, size: 18, color: AlterPalette.iris),
              const SizedBox(width: 8),
              Text(
                'Capture a moment',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _Pill(
                icon: LucideIcons.cpu,
                text: realGemma ? 'Gemma on-device' : 'Edge heuristics',
                color: realGemma ? AlterPalette.cyan : AlterPalette.mint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final s in _surfaces)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PremiumChip(
                      label: s.label,
                      icon: s.icon,
                      selected: state.source == s,
                      onTap: () => onSelectSurface(s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText:
                  'Paste a message, link, payment request, install prompt, or call note…',
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              label: state.isAnalyzing ? 'Analyzing…' : 'Analyze moment',
              icon: state.isAnalyzing ? LucideIcons.loader : LucideIcons.shield,
              onPressed: state.isAnalyzing ? null : onAnalyze,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.analysis});

  final MomentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = analysis.verdict.color;
    final icon = switch (analysis.verdict) {
      RiskVerdict.dangerous => LucideIcons.octagon_x,
      RiskVerdict.needsVerification => LucideIcons.shield_question_mark,
      RiskVerdict.caution => LucideIcons.triangle_alert,
      RiskVerdict.safe => LucideIcons.shield_check,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: c, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        analysis.verdict.label.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: c,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'risk ${(analysis.riskScore * 100).round()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    analysis.headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  if (analysis.whyItMatters.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      analysis.whyItMatters,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeCheckCard extends StatelessWidget {
  const _EdgeCheckCard({required this.state, required this.onRunCloud});

  final LifeShieldState state;
  final VoidCallback onRunCloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = state.analysis!;
    final edge = a.edgeState;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.cpu, size: 18, color: edge.color),
              const SizedBox(width: 8),
              Text(
                'Edge check',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _StatusDot(label: edge.label, color: edge.color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.triage?.summary ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
          if (a.redactedFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in a.redactedFields)
                  _Pill(
                    icon: LucideIcons.eye_off,
                    text: '$f redacted',
                    color: AlterPalette.iris,
                  ),
              ],
            ),
          ],
          if (state.needsCloud) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AlterPalette.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AlterPalette.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.cloud_upload,
                          size: 16,
                          color: AlterPalette.cyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cloud reasoning can add proof & consequences. '
                            'This is exactly what will leave your device:',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.cloudPreview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [],
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PremiumButton(
                            label: state.isAnalyzing
                                ? 'Reasoning…'
                                : 'Consent & run cloud',
                            icon: LucideIcons.cloud,
                            compact: true,
                            onPressed: state.isAnalyzing ? null : onRunCloud,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.analysis});

  final MomentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flags = analysis.redFlags;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.eye, size: 18, color: AlterPalette.aura),
              const SizedBox(width: 8),
              Text(
                'What ALTER noticed',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (flags.isEmpty)
            Text(
              'No risk signals stood out.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            ...flags
                .take(5)
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.flag,
                          size: 14,
                          color: analysis.verdict.color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions({required this.state});

  final LifeShieldState state;

  String? _trustCandidate() {
    if (state.extraction.entities.isNotEmpty) {
      return state.extraction.entities.first;
    }
    final m = RegExp(
      r'\b[\w-]+\.(?:com|in|org|net|top|xyz|live|info)\b',
      caseSensitive: false,
    ).firstMatch(state.moment?.rawContent ?? '');
    return m?.group(0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidate = _trustCandidate();
    final alreadyTrusted = state.trustedMatch != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alreadyTrusted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Pill(
              icon: LucideIcons.shield_check,
              text: 'Muted — you trust ${state.trustedMatch}',
              color: AlterPalette.mint,
            ),
          ),
        Row(
          children: [
            if (candidate != null && !alreadyTrusted)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.shield_check, size: 16),
                  label: Text(
                    'Trust $candidate',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(memoryProvider.notifier)
                        .addTrusted(
                          candidate.contains('.') ? 'domain' : 'contact',
                          candidate,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Trusted $candidate — re-analyze to apply',
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (candidate != null && !alreadyTrusted) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.users, size: 16),
                label: const Text('Convene Council'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(decisionCouncilProvider.notifier)
                      .seed(state.moment?.rawContent ?? state.input);
                  context.go('/decision-council');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MomentTypeBar extends StatelessWidget {
  const _MomentTypeBar({required this.category, required this.moment});

  final MomentCategory category;
  final Moment? moment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: category.color.withValues(alpha: 0.34)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 15, color: category.color),
              const SizedBox(width: 7),
              Text(
                category.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (moment != null)
          Text(
            '${moment!.sourceSurface.label} · ${moment!.timeLabel} · ${moment!.privacyLevel.label}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _RoutedCard extends ConsumerWidget {
  const _RoutedCard({required this.category, required this.momentText});

  final MomentCategory category;
  final String momentText;

  void _open(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    if (category.mode == 'daytwin') {
      ref.read(dayTwinControllerProvider.notifier).seed(momentText);
      context.go('/daytwin');
    } else if (category.mode == 'futuretwin') {
      ref.read(futureTwinControllerProvider.notifier).seed(momentText);
      context.go('/futuretwin');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = category.color;
    final dest = category.mode == 'daytwin'
        ? 'DayTwin'
        : category.mode == 'futuretwin'
        ? 'FutureTwin'
        : 'Reminders';
    final desc = category.mode == 'daytwin'
        ? 'This is a pressure point on your day. DayTwin will fold it into your '
              'living timeline and simulate Default / Risk / Optimized paths.'
        : category.mode == 'futuretwin'
        ? 'This is a bigger decision. FutureTwin will simulate safe, smart, '
              'and bold paths with a regret score and a roadmap.'
        : 'Captured as an action item — ALTER can set a reminder for it.';
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(category.icon, color: c, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Routed to $dest',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LifeShield saw no immediate danger here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          const SizedBox(height: 14),
          if (category.isRoutedElsewhere)
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: 'Open in $dest',
                icon: LucideIcons.arrow_right,
                compact: true,
                onPressed: () => _open(context, ref),
              ),
            )
          else
            _Pill(
              icon: LucideIcons.circle_dot,
              text: 'Captured as an action item',
              color: c,
            ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.extraction});

  final ContextExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.scan_text, size: 18, color: AlterPalette.iris),
              const SizedBox(width: 8),
              Text(
                'Context engine',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _StatusDot(
                label: extraction.cloudEnriched ? 'edge + cloud' : 'on-device',
                color: extraction.cloudEnriched
                    ? AlterPalette.cyan
                    : AlterPalette.mint,
              ),
            ],
          ),
          if (extraction.requestedAction.isNotEmpty ||
              extraction.deadline.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (extraction.requestedAction.isNotEmpty)
                  _Pill(
                    icon: LucideIcons.pointer,
                    text: extraction.requestedAction,
                    color: AlterPalette.aura,
                  ),
                if (extraction.deadline.isNotEmpty)
                  _Pill(
                    icon: LucideIcons.clock,
                    text: 'Deadline: ${extraction.deadline}',
                    color: AlterPalette.amber,
                  ),
                if (extraction.sensitiveDataRequest)
                  _Pill(
                    icon: LucideIcons.shield_alert,
                    text: 'Asks for sensitive data',
                    color: AlterPalette.danger,
                  ),
              ],
            ),
          ],
          if (extraction.entities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in extraction.entities.take(6))
                  _Pill(
                    icon: LucideIcons.at_sign,
                    text: e,
                    color: AlterPalette.iris,
                  ),
              ],
            ),
          ],
          if (extraction.activeRisks.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...extraction.activeRisks.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RiskBar(label: r.key, value: r.value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskBar extends StatelessWidget {
  const _RiskBar({required this.label, required this.value});

  final String label;
  final double value;

  Color get _color => value >= 0.66
      ? AlterPalette.danger
      : value >= 0.33
      ? AlterPalette.amber
      : AlterPalette.mint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 7,
              backgroundColor: _color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(value * 100).round()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: _color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProofSheet extends StatelessWidget {
  const _ProofSheet({required this.analysis});

  final MomentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SheetShell(
      title: 'Proof Mode',
      accent: AlterPalette.cyan,
      icon: LucideIcons.scan_search,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                icon: analysis.cloudUsed ? LucideIcons.cloud : LucideIcons.cpu,
                text: analysis.cloudUsed
                    ? 'Edge + cloud reasoning'
                    : 'On-device only',
                color: analysis.edgeState.color,
              ),
              const SizedBox(width: 8),
              _Pill(
                icon: LucideIcons.gauge,
                text: '${(analysis.confidence * 100).round()}% confidence',
                color: AlterPalette.iris,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProofBlock(
            title: 'Facts',
            icon: LucideIcons.file_text,
            items: analysis.facts,
            color: AlterPalette.cyan,
            empty: 'No hard facts extracted.',
          ),
          _ProofBlock(
            title: 'Red flags',
            icon: LucideIcons.flag,
            items: analysis.redFlags,
            color: AlterPalette.danger,
            empty: 'No red flags.',
          ),
          _ProofBlock(
            title: 'Assumptions',
            icon: LucideIcons.brain,
            items: analysis.assumptions,
            color: AlterPalette.amber,
            empty: 'None.',
          ),
          _ProofBlock(
            title: 'Missing info',
            icon: LucideIcons.circle_question_mark,
            items: analysis.missingInfo,
            color: AlterPalette.violet,
            empty: 'Nothing critical missing.',
          ),
          if (analysis.whatCouldMakeWrong.isNotEmpty) ...[
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AlterPalette.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AlterPalette.danger.withValues(alpha: 0.25),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.shield_alert,
                      size: 16,
                      color: AlterPalette.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What could make ALTER wrong',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            analysis.whatCouldMakeWrong,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProofBlock extends StatelessWidget {
  const _ProofBlock({
    required this.title,
    required this.icon,
    required this.items,
    required this.color,
    required this.empty,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color color;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              empty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            ...items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        it,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionSheet extends ConsumerWidget {
  const _ActionSheet({required this.analysis, required this.momentExcerpt});

  final MomentAnalysis analysis;
  final String momentExcerpt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final steps = analysis.verificationSteps;
    return _SheetShell(
      title: 'Safe actions',
      accent: AlterPalette.mint,
      icon: LucideIcons.shield_check,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (analysis.actions.isEmpty && steps.isEmpty)
            Text(
              'No actions needed — this looks safe.',
              style: theme.textTheme.bodyMedium,
            ),
          ...analysis.actions.map(
            (a) => _ActionRow(action: a, momentExcerpt: momentExcerpt),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Verify safely',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key + 1}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AlterPalette.mint,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'ALTER never sends, pays, installs, or shares without your explicit '
            'confirmation. No final medical, legal, or financial decisions.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.action, required this.momentExcerpt});

  final SafeAction action;
  final String momentExcerpt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final danger = action.irreversible;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (action.detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        action.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.62,
                          ),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger
                      ? AlterPalette.danger.withValues(alpha: 0.16)
                      : AlterPalette.mint.withValues(alpha: 0.16),
                  foregroundColor: danger
                      ? AlterPalette.danger
                      : AlterPalette.mint,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: () => _enqueue(context, ref),
                child: const Text(
                  'Queue',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enqueue(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    ref
        .read(openClawQueueProvider.notifier)
        .enqueue(action, momentExcerpt: momentExcerpt);
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued “${action.title}” in OpenClaw'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.go('/openclaw'),
        ),
      ),
    );
  }
}

// ---- Shared small widgets ----

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.accent,
    required this.icon,
    required this.child,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilterPanel(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class BackdropFilterPanel extends StatelessWidget {
  const BackdropFilterPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (isDark ? AlterPalette.graphite : AlterPalette.white).withValues(
          alpha: 0.96,
        ),
        border: Border(
          top: BorderSide(
            color: AlterPalette.iris.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            text,
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

class _InlineNote extends StatelessWidget {
  const _InlineNote({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
