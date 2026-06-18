import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/futuretwin_controller.dart';
import '../domain/simulations.dart';
import 'sim_widgets.dart';

class FutureTwinScreen extends ConsumerStatefulWidget {
  const FutureTwinScreen({super.key});

  @override
  ConsumerState<FutureTwinScreen> createState() => _FutureTwinScreenState();
}

class _FutureTwinScreenState extends ConsumerState<FutureTwinScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seeded = ref.read(futureTwinControllerProvider).input;
    if (seeded.isNotEmpty) {
      _controller.text = seeded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(futureTwinControllerProvider).result == null) {
          ref.read(futureTwinControllerProvider.notifier).simulate();
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
    final state = ref.watch(futureTwinControllerProvider);
    final notifier = ref.read(futureTwinControllerProvider.notifier);
    final theme = Theme.of(context);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'FutureTwin',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Simulate the bigger decisions — Safe, Smart, and Bold paths, scored for regret.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.git_fork,
                      size: 18,
                      color: AlterPalette.violet,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'The decision you’re weighing',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: notifier.setInput,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. “Should I leave my job to build my startup full-time?”',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    label: state.isSimulating
                        ? 'Simulating…'
                        : 'Simulate futures',
                    icon: state.isSimulating
                        ? LucideIcons.loader
                        : LucideIcons.git_fork,
                    onPressed: state.isSimulating ? null : notifier.simulate,
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
            _FutureResult(
              result: state.result!,
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FutureResult extends StatelessWidget {
  const _FutureResult({required this.result});

  final FutureTwinResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.headline,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        if (result.summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            result.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (!result.cloudUsed)
          SimTag(
            label: 'On-device model',
            color: AlterPalette.mint,
            icon: LucideIcons.cpu,
          ),
        const SizedBox(height: 14),
        ...result.paths.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FuturePathCard(
              path: p,
              recommended: result.recommendedType == p.type,
            ),
          ),
        ),
        if (result.regretMinimizer.isNotEmpty) ...[
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
              child: Row(
                children: [
                  Icon(
                    LucideIcons.shield_check,
                    color: AlterPalette.iris,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Regret minimizer',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AlterPalette.iris,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result.regretMinimizer,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
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
    );
  }
}

class _FuturePathCard extends StatelessWidget {
  const _FuturePathCard({required this.path, required this.recommended});

  final FuturePath path;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = path.type.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: recommended
            ? Border.all(color: c.withValues(alpha: 0.6), width: 1.6)
            : null,
      ),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SimTag(label: path.type.label, color: c),
                const SizedBox(width: 8),
                if (recommended)
                  SimTag(
                    label: 'Recommended',
                    color: c,
                    icon: LucideIcons.star,
                    filled: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              path.thesis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 14),
            SimMetricBar(
              label: 'Effort',
              value: path.effort,
              color: AlterPalette.cyan,
            ),
            SimMetricBar(
              label: 'Risk',
              value: path.risk,
              color: c,
              invertGood: true,
            ),
            SimMetricBar(
              label: 'Upside',
              value: path.upside,
              color: AlterPalette.mint,
            ),
            SimMetricBar(
              label: 'Regret',
              value: path.regret,
              color: c,
              invertGood: true,
            ),
            if (path.roadmap.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...path.roadmap.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.key + 1}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c,
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
          ],
        ),
      ),
    );
  }
}
