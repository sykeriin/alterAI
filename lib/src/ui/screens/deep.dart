import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/proactive/application/briefing_controller.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';

class DeepAnalysisScreen extends ConsumerWidget {
  const DeepAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(briefingControllerProvider);

    return DeepScaffold(
      title: 'DEEP ANALYSIS',
      bg: const [Color(0xFF1A1430), Color(0xFF0D0A16), Color(0xFF060409)],
      child: briefingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: const [
            InferringEmptyState(
              title: 'Still inferring…',
              subtitle: 'Deep analysis needs memories from your real activity first.',
            ),
          ],
        ),
        data: (briefing) {
          final traces = <_Trace>[
            ...briefing.commitments.map(
              (c) => _Trace('Commitment', c, AppColors.lime),
            ),
            ...briefing.relationships.map(
              (r) => _Trace('Relationship', r, AppColors.cyan),
            ),
            ...briefing.patterns.map(
              (p) => _Trace('Pattern', p, AppColors.orange),
            ),
          ];

          if (traces.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              children: const [
                InferringEmptyState(
                  title: 'Still inferring…',
                  subtitle:
                      'Ask Alter a question or use Lens — reasoning traces appear with cited memories.',
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              Row(children: [
                const StarMark(size: 18),
                const SizedBox(width: 10),
                Text('Reasoning trace · from your memories',
                    style: AppText.body(13, color: AppColors.white(0.6))),
              ]),
              const SizedBox(height: 14),
              Text(
                briefing.headline,
                style: AppText.display(25, weight: FontWeight.w400, height: 1.15),
              ),
              const SizedBox(height: 24),
              Column(
                children: List.generate(traces.length, (i) {
                  final t = traces[i];
                  final last = i == traces.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 5),
                            decoration:
                                BoxDecoration(color: t.c, shape: BoxShape.circle),
                          ),
                          if (!last)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: AppColors.white(0.12),
                              ),
                            ),
                        ]),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: last ? 0 : 18, top: 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.white(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.white(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.k.toUpperCase(), style: AppText.kicker(t.c)),
                                  const SizedBox(height: 4),
                                  Text(t.v,
                                      style: AppText.body(14,
                                          color: AppColors.white(0.85), height: 1.5)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              if (briefing.memoryCitations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Citations: ${briefing.memoryCitations.join(', ')}',
                  style: AppText.body(12, color: AppColors.white(0.45)),
                ),
              ],
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(AlterRoutes.agent),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text('Add to plan',
                          style: AppText.body(14,
                              weight: FontWeight.w700, color: AppColors.bg)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.white(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.white(0.16)),
                      ),
                      child: Text('Dismiss',
                          style: AppText.body(14, weight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _Trace {
  final String k, v;
  final Color c;
  const _Trace(this.k, this.v, this.c);
}
