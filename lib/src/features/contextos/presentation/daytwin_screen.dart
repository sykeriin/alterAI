import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/premium_controls.dart';
import '../application/daytwin_controller.dart';
import '../domain/simulations.dart';
import 'sim_widgets.dart';

class DayTwinScreen extends ConsumerStatefulWidget {
  const DayTwinScreen({super.key});

  @override
  ConsumerState<DayTwinScreen> createState() => _DayTwinScreenState();
}

class _DayTwinScreenState extends ConsumerState<DayTwinScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seeded = ref.read(dayTwinControllerProvider).input;
    if (seeded.isNotEmpty) {
      _controller.text = seeded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(dayTwinControllerProvider).result == null) {
          ref.read(dayTwinControllerProvider.notifier).simulate();
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
    final state = ref.watch(dayTwinControllerProvider);
    final notifier = ref.read(dayTwinControllerProvider.notifier);
    final theme = Theme.of(context);

    return AmbientScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'DayTwin',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A living model of today — Default, Risk, and Optimized paths, with the next best move.',
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
                      LucideIcons.calendar_clock,
                      size: 18,
                      color: AlterPalette.cyan,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Describe today',
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
                        'Plans, deadlines, meetings, commute, energy — e.g. “Ship deck by 5, then airport for a 7:55 flight.”',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    label: state.isSimulating ? 'Modeling…' : 'Model my day',
                    icon: state.isSimulating
                        ? LucideIcons.loader
                        : LucideIcons.calendar_range,
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
            _DayResult(
              result: state.result!,
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DayResult extends StatelessWidget {
  const _DayResult({required this.result});

  final DayTwinResult result;

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
        const SizedBox(height: 6),
        if (!result.cloudUsed)
          SimTag(
            label: 'On-device model',
            color: AlterPalette.mint,
            icon: LucideIcons.cpu,
          ),
        if (result.nextBestMove.isNotEmpty) ...[
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AlterPalette.mint.withValues(alpha: 0.2),
                  AlterPalette.cyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AlterPalette.mint.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.compass, color: AlterPalette.mint, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next best move',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AlterPalette.mint,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result.nextBestMove,
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
        if (result.pressurePoints.isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.triangle_alert,
                      size: 16,
                      color: AlterPalette.amber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pressure points',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...result.pressurePoints.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AlterPalette.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p,
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
          ),
        ],
        const SizedBox(height: 14),
        ...result.paths.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayPathCard(path: p),
          ),
        ),
      ],
    );
  }
}

class _DayPathCard extends StatelessWidget {
  const _DayPathCard({required this.path});

  final DayPath path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = path.type.color;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SimTag(label: path.type.label, color: c),
              const Spacer(),
              Text(
                'day score ${(path.dayScore * 100).round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            path.summary,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          ...path.blocks.map((b) => _TimelineBlock(block: b, color: c)),
        ],
      ),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({required this.block, required this.color});

  final DayBlock block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stressColor = block.stress >= 0.66
        ? AlterPalette.danger
        : block.stress >= 0.33
        ? AlterPalette.amber
        : AlterPalette.mint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              block.time,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: stressColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 26,
                color: color.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (block.note.isNotEmpty)
                  Text(
                    block.note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.56,
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
