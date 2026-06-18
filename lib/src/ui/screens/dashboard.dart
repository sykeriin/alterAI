import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/contextos/application/council_ambient_controller.dart';
import 'package:alter/src/features/actions/presentation/action_inbox_card.dart';
import 'package:alter/src/features/life_feed/application/life_feed_provider.dart';
import 'package:alter/src/features/life_feed/application/task_completion_provider.dart';
import 'package:alter/src/features/life_feed/domain/life_feed_models.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/features/proactive/application/briefing_controller.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/widgets/council_orbit.dart';
import 'package:alter/src/ui/screens/main_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static Color _tagColor(String tag) {
    final t = tag.toUpperCase();
    if (t.contains('HACK')) return AppColors.lime;
    if (t.contains('INTERN')) return AppColors.cyan;
    if (t.contains('GSoC') || t.contains('OPEN')) return AppColors.orange;
    if (t.contains('GRANT')) return AppColors.pink;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = MainShell.of(context);
    final feedAsync = ref.watch(lifeFeedProvider);
    final briefingAsync = ref.watch(briefingControllerProvider);
    ref.watch(councilAmbientProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final initial = profile?.displayName.isNotEmpty == true
        ? profile!.displayName[0].toUpperCase()
        : 'Y';
    final doneTasks = ref.watch(taskCompletionProvider);

    return GradientScaffold(
      bgColors: const [Color(0xFF241A40), Color(0xFF120E1C), AppColors.bg],
      bgCenter: const Alignment(0.6, -1.0),
      child: SafeArea(
        bottom: false,
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _content(
            context,
            ref,
            shell,
            LifeFeedSnapshot.empty(),
            briefingAsync.asData?.value,
            initial,
            doneTasks,
          ),
          data: (feed) => _content(
            context,
            ref,
            shell,
            feed,
            briefingAsync.asData?.value,
            initial,
            doneTasks,
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    MainShellState shell,
    LifeFeedSnapshot feed,
    DailyBriefing? briefing,
    String userInitial,
    Set<String> doneTasks,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
      children: [
        PrimaryHeader(
          title: 'LIFE FEED',
          starTitle: true,
          onGear: shell.openSettings,
          onAvatar: () => shell.goTab(4),
        ),
        const SizedBox(height: 24),
        Text(
          feed.greeting,
          style: AppText.display(30, height: 1.1, letterSpacing: -0.2),
        ),
        const SizedBox(height: 6),
        Text(feed.dateSummary,
            style: AppText.body(13.5, color: AppColors.white(0.45))),
        const SizedBox(height: 16),
        CouncilOrbit(
          compact: true,
          userInitial: userInitial,
          onConvene: () => context.push(AlterRoutes.council),
        ),
        const SizedBox(height: 16),
        const ActionInboxCard(),
        if (briefing != null &&
            (briefing.commitments.isNotEmpty ||
                briefing.memoryCitations.isNotEmpty)) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily briefing',
                    style: AppText.kicker(AppColors.lime, size: 11)),
                const SizedBox(height: 6),
                Text(briefing.headline,
                    style: AppText.body(14, color: AppColors.white(0.85), height: 1.4)),
                if (briefing.commitments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Commitments: ${briefing.commitments.join(' · ')}',
                      style: AppText.body(12, color: AppColors.white(0.55))),
                ],
                if (briefing.memoryCitations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Based on: ${briefing.memoryCitations.join(', ')}',
                      style: AppText.body(11, color: AppColors.white(0.4)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (!feed.hasContent)
          const InferringEmptyState(
            title: 'Still inferring…',
            subtitle:
                'Your life feed fills in as Alter observes your voice, calendar, and actions.',
          )
        else ...[
          _focusHero(context, shell, feed),
          const SizedBox(height: 30),
          if (feed.opportunities.isNotEmpty) ...[
            _sectionHead('Opportunities for you', 'Radar →',
                () => context.push(AlterRoutes.radar)),
            const SizedBox(height: 14),
            ...feed.opportunities.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _oppCard(context, o),
                )),
            const SizedBox(height: 18),
          ],
          if (feed.tasks.isNotEmpty) ...[
            Text("Today's tasks", style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...feed.tasks.map((t) {
              final id = t.title;
              final done = doneTasks.contains(id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _taskRow(ref, t.copyWith(done: done), id),
              );
            }),
          ],
        ],
      ],
    );
  }

  Widget _focusHero(
    BuildContext context,
    MainShellState shell,
    LifeFeedSnapshot feed,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgRaised,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.white(0.10)),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: Orb(size: 200, blur: 6, colors: const [
            AppColors.lime,
            AppColors.purple,
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FOCUS NOW', style: AppText.kicker(AppColors.lime)),
              const SizedBox(height: 12),
              SizedBox(
                width: 230,
                child: Text(feed.focusTitle,
                    style: AppText.display(23,
                        weight: FontWeight.w500, height: 1.18)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 240,
                child: Text(
                  feed.focusRationale,
                  style: AppText.body(13.5, color: AppColors.white(0.6)),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => shell.goTab(2),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.pill,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ask Alter how',
                        style: AppText.body(14,
                            weight: FontWeight.w700, color: AppColors.pillInk)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.pillInk),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.body(16, weight: FontWeight.w700)),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: AppText.body(13,
                  weight: FontWeight.w600, color: AppColors.lime)),
        ),
      ],
    );
  }

  Widget _oppCard(BuildContext context, LifeFeedOpportunity o) {
    final c = _tagColor(o.tag);
    return GlassCard(
      onTap: () => context.push(AlterRoutes.radar),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c),
          ),
          child: Text('${o.matchScore}',
              style: AppText.display(15, weight: FontWeight.w700, color: c)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.tag, style: AppText.kicker(c, size: 10)),
              const SizedBox(height: 3),
              Text(o.title, style: AppText.body(14.5, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(o.meta, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _taskRow(WidgetRef ref, LifeFeedTask t, String taskId) {
    return GestureDetector(
      onTap: () => ref.read(taskCompletionProvider.notifier).toggle(taskId),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: t.hot
            ? LinearGradient(colors: [
                AppColors.lime.withValues(alpha: 0.12),
                AppColors.white(0.03),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: t.hot ? null : AppColors.white(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: t.hot ? AppColors.lime.withValues(alpha: 0.3) : AppColors.white(0.10)),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.done ? AppColors.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: t.done ? AppColors.lime : AppColors.white(0.3), width: 1.5),
          ),
          child: t.done
              ? const Icon(Icons.check, size: 14, color: AppColors.bg)
              : null,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title,
                  style: AppText.body(14.5,
                      weight: FontWeight.w600,
                      color: t.done ? AppColors.white(0.5) : AppColors.white(0.95))
                      .copyWith(
                          decoration: t.done ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text(t.meta, style: AppText.body(12, color: AppColors.white(0.5))),
            ],
          ),
        ),
        Text(t.badge,
            style: AppText.body(11,
                weight: FontWeight.w700,
                color: t.badge == 'Now' ? AppColors.lime : AppColors.white(0.45))),
      ]),
      ),
    );
  }
}
