import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/contextos/application/council_ambient_controller.dart';
import 'package:alter/src/features/memory/application/memory_store.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/features/proactive/application/briefing_controller.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/widgets/council_orbit.dart';
import 'package:alter/src/ui/screens/main_shell.dart';

class FutureScreen extends ConsumerWidget {
  const FutureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = MainShell.of(context);
    final memories = ref.watch(memoryStoreProvider).asData?.value ?? const [];
    final briefing = ref.watch(briefingControllerProvider).asData?.value;
    final ambient = ref.watch(councilAmbientProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final initial = profile?.displayName.isNotEmpty == true
        ? profile!.displayName[0].toUpperCase()
        : 'Y';
    final hasForecast = briefing != null &&
        (briefing.patterns.isNotEmpty || briefing.commitments.isNotEmpty);

    return GradientScaffold(
      bgColors: const [Color(0xFF2A1D52), Color(0xFF130F22), AppColors.bg],
      bgCenter: const Alignment(-0.4, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'FUTURE',
              onGear: shell.openSettings,
              onAvatar: () => shell.goTab(4),
            ),
            const SizedBox(height: 16),
            Text('CLONE COUNCIL',
                style: AppText.kicker(AppColors.purpleLight, size: 11)),
            const SizedBox(height: 8),
            CouncilOrbit(
              userInitial: initial,
              onConvene: () => context.push(AlterRoutes.council),
              onPersonaTap: (_) => context.push(AlterRoutes.council),
            ),
            if (ambient.shouldShowPulse && ambient.warmedTopic.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Council warmed on: ${ambient.warmedTopic}',
                textAlign: TextAlign.center,
                style: AppText.body(12, color: AppColors.lime),
              ),
            ],
            const SizedBox(height: 22),
            RichText(
              text: TextSpan(
                style: AppText.display(30, height: 1.08, letterSpacing: -0.2),
                children: const [
                  TextSpan(text: "Build the future\nyou're "),
                  TextSpan(
                      text: 'simulating',
                      style: TextStyle(color: AppColors.lime)),
                  TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (hasForecast)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.orange.withValues(alpha: 0.16),
                    const Color(0xFFFF4D2D).withValues(alpha: 0.10),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INFERRED FROM YOUR ACTIVITY',
                        style: AppText.kicker(AppColors.orange, size: 11)),
                    const SizedBox(height: 10),
                    Text(
                      briefing!.patterns.isNotEmpty
                          ? briefing.patterns.first
                          : briefing.commitments.first,
                      style: AppText.body(14.5, color: AppColors.white(0.85), height: 1.5),
                    ),
                  ],
                ),
              )
            else
              const InferringEmptyState(
                title: 'Still inferring…',
                subtitle:
                    'Forecasts appear once Alter has enough memories from your actions.',
                icon: Icons.timeline_outlined,
              ),
            const SizedBox(height: 28),
            Text('Explore your futures', style: AppText.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            _entry(context, 'Clone Council', 'Five personas debate your decision',
                AppColors.purpleLight, AppColors.purpleDeep, AlterRoutes.council),
            const SizedBox(height: 12),
            _entry(context, 'Future Simulator', 'Compare parallel paths',
                AppColors.cyan, AppColors.cyanDeep, AlterRoutes.simulator),
            const SizedBox(height: 12),
            _entry(context, 'Opportunity Radar', 'Signals from your activity',
                AppColors.green, AppColors.greenDeep, AlterRoutes.radar),
            if (memories.isEmpty) ...[
              const SizedBox(height: 24),
              const InferringEmptyState(
                title: 'No recommendations yet',
                subtitle: 'Alter will suggest next steps once it knows you from real interactions.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, String title, String sub, Color c1,
      Color c2, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c1.withValues(alpha: 0.18),
            c1.withValues(alpha: 0.04),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c1.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.2),
                colors: [c1, c2],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(17, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.body(12.5, color: AppColors.white(0.6))),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: AppColors.white(0.5), size: 20),
        ]),
      ),
    );
  }
}
