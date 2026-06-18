import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/routes.dart';
import '../../../ui/widgets.dart';
import '../application/decision_council_controller.dart';
import '../domain/council.dart';

class DecisionCouncilScreen extends ConsumerStatefulWidget {
  const DecisionCouncilScreen({super.key});

  @override
  ConsumerState<DecisionCouncilScreen> createState() =>
      _DecisionCouncilScreenState();
}

class _DecisionCouncilScreenState extends ConsumerState<DecisionCouncilScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seeded = ref.read(decisionCouncilProvider).topic;
    if (seeded.isNotEmpty) {
      _controller.text = seeded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(decisionCouncilProvider).result == null) {
          ref.read(decisionCouncilProvider.notifier).convene();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(decisionCouncilProvider);
    final notifier = ref.read(decisionCouncilProvider.notifier);
    final theme = Theme.of(context);

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'COUNCIL',
        subtitle:
            'Five inner voices for the decisions that matter — Practical, Risk, '
            'Future, Skeptic, Action.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in CouncilAgent.values)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: a.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.icon, size: 13, color: a.color),
                      const SizedBox(width: 6),
                      Text(
                        a.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: a.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: notifier.setTopic,
                  decoration: const InputDecoration(
                    hintText:
                        'The decision or moment to deliberate — e.g. “Accept the offer, or hold out?”',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    label: state.isConvening
                        ? 'Council deliberating…'
                        : 'Convene the council',
                    icon: state.isConvening
                        ? LucideIcons.loader
                        : LucideIcons.users,
                    onPressed: state.isConvening ? null : notifier.convene,
                  ),
                ),
              ],
            ),
          ),
          if (state.error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              state.error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AlterPalette.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 16),
            _CouncilResultView(
              result: state.result!,
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CouncilResultView extends StatelessWidget {
  const _CouncilResultView({required this.result});

  final CouncilResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AlterPalette.iris.withValues(alpha: 0.2),
                AlterPalette.cyan.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AlterPalette.iris.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.gavel, color: AlterPalette.iris, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Consensus',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AlterPalette.iris,
                      ),
                    ),
                    if (!result.cloudUsed) ...[
                      const Spacer(),
                      Text(
                        'Sample simulation',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AlterPalette.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.consensus,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                if (result.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    result.recommendation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...result.voices.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VoiceCard(voice: v),
          ),
        ),
        if (result.dissent.isNotEmpty)
          GlassPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.message_circle_warning,
                  size: 18,
                  color: AlterPalette.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strongest dissent',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AlterPalette.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.dissent,
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
      ],
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.voice});

  final CouncilVoice voice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = voice.agent.color;
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
                  padding: const EdgeInsets.all(10),
                  child: Icon(voice.agent.icon, color: c, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voice.agent.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      voice.stance,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(voice.confidence * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (voice.take.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              voice.take,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
