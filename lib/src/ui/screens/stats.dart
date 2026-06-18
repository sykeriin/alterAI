import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alter/src/features/profile/application/profile_ready.dart';
import 'package:alter/src/features/reputation/application/reputation_score_provider.dart';
import 'package:alter/src/features/shared/application/alter_data_providers.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/screens/main_shell.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = MainShell.of(context);
    final profileReady = ref.watch(profileReadyProvider);
    final scoreAsync = ref.watch(reputationScoreProvider);
    final eventsAsync = ref.watch(reputationEventsProvider);

    if (!profileReady) {
      return GradientScaffold(
        bgColors: const [Color(0xFF2A1F55), Color(0xFF1A1338), Color(0xFF0D0A16)],
        bgCenter: const Alignment(0.0, -1.0),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
            children: [
              PrimaryHeader(
                title: 'STATS',
                onGear: shell.openSettings,
                onAvatar: () => shell.goTab(4),
              ),
              const SizedBox(height: 24),
              const InferringEmptyState(
                title: 'Complete your profile first',
                subtitle:
                    'Reputation and stats appear after you finish onboarding.',
                icon: Icons.insights_outlined,
              ),
            ],
          ),
        ),
      );
    }

    return GradientScaffold(
      bgColors: const [Color(0xFF2A1F55), Color(0xFF1A1338), Color(0xFF0D0A16)],
      bgCenter: const Alignment(0.0, -1.0),
      child: SafeArea(
        bottom: false,
        child: scoreAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
            children: [
              PrimaryHeader(
                title: 'STATS',
                onGear: shell.openSettings,
                onAvatar: () => shell.goTab(4),
              ),
              const SizedBox(height: 24),
              const InferringEmptyState(
                title: 'Still inferring…',
                subtitle: 'Reputation builds from your real actions and follow-through.',
                icon: Icons.insights_outlined,
              ),
            ],
          ),
          data: (score) {
            if (!score.hasData) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
                children: [
                  PrimaryHeader(
                    title: 'STATS',
                    onGear: shell.openSettings,
                    onAvatar: () => shell.goTab(4),
                  ),
                  const SizedBox(height: 24),
                  const InferringEmptyState(
                    title: 'Still inferring…',
                    subtitle:
                        'Complete actions, follow-ups, and opportunities — your reputation score will appear here.',
                    icon: Icons.insights_outlined,
                  ),
                ],
              );
            }

            final eventCount = eventsAsync.asData?.value.length ?? 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
              children: [
                PrimaryHeader(
                  title: 'STATS',
                  onGear: shell.openSettings,
                  onAvatar: () => shell.goTab(4),
                ),
                const SizedBox(height: 18),
                Text('Reputation',
                    style: AppText.body(13, color: AppColors.white(0.55))),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${score.score}',
                        style: AppText.display(64,
                            weight: FontWeight.w500, height: 0.9)),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (score.recentDelta != 0)
                            Text(
                              '${score.recentDelta >= 0 ? '▲' : '▼'} ${score.recentDelta.abs()}',
                              style: AppText.body(13,
                                  weight: FontWeight.w700,
                                  color: score.recentDelta >= 0
                                      ? AppColors.lime
                                      : AppColors.danger),
                            ),
                          Text(
                            eventCount > 0
                                ? '$eventCount events tracked'
                                : 'From your profile signals',
                            style: AppText.body(12,
                                color: AppColors.white(0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (score.topDomain.isNotEmpty)
                  _statRow(Icons.arrow_upward, AppColors.lime, 'Top signal',
                      score.topDomain,
                      score.topDomainFit > 0
                          ? '${score.topDomainFit} fit'
                          : 'Observed'),
                if (score.focusArea.isNotEmpty)
                  _statRow(Icons.arrow_downward, AppColors.orange, 'Focus area',
                      score.focusArea,
                      score.focusAreaFit > 0
                          ? '${score.focusAreaFit} fit'
                          : 'Observed'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statRow(
      IconData icon, Color c, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.white(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(width: 10),
            Text(label, style: AppText.body(13, color: AppColors.white(0.6))),
          ]),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    textAlign: TextAlign.end,
                    style: AppText.display(20, weight: FontWeight.w500)),
                Text(sub,
                    style: AppText.body(12, color: AppColors.white(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
