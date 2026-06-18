import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/memory/application/memory_store.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/features/profile/application/profile_ready.dart';
import 'package:alter/src/features/reputation/application/reputation_score_provider.dart';
import 'package:alter/src/features/shared/application/alter_data_providers.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/screens/main_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = MainShell.of(context);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final score = ref.watch(reputationScoreProvider).asData?.value;
    final opportunities = ref.watch(opportunitySignalsProvider).asData?.value;
    final memories = ref.watch(memoryStoreProvider).asData?.value;
    final profileReady = isProfileReady(profile);
    final pursued = profileReady ? (opportunities?.length ?? 0) : 0;
    final memoryCount = memories?.length ?? 0;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'Alter user';
    final subtitle = profile?.bio.isNotEmpty == true
        ? profile!.bio
        : (profile?.role.isNotEmpty == true
            ? profile!.role
            : 'Complete your profile');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return GradientScaffold(
      bgColors: const [Color(0xFF2E2052), Color(0xFF150F24), AppColors.bg],
      bgCenter: const Alignment(0.0, -1.0),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 130),
          children: [
            PrimaryHeader(
              title: 'PROFILE',
              showAvatar: false,
              onGear: shell.openSettings,
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.purpleLight, AppColors.pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purpleLight.withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Text(
                      initial,
                      style: AppText.display(38, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: AppText.display(24, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.body(13.5, color: AppColors.white(0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _stat(
                  score?.hasData == true ? '${score!.score}' : '—',
                  'Reputation',
                  AppColors.lime,
                ),
                const SizedBox(width: 10),
                _stat(
                  pursued > 0 ? '$pursued' : '—',
                  'Signals',
                  AppColors.cyan,
                ),
                const SizedBox(width: 10),
                _stat(
                  memoryCount > 0 ? '$memoryCount' : '—',
                  'Memories',
                  AppColors.orange,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Social graph entry
            GestureDetector(
              onTap: () => context.push(AlterRoutes.social),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.16),
                      AppColors.purpleLight.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.pink.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const RadialGradient(
                          center: Alignment(-0.2, -0.2),
                          colors: [AppColors.pink, AppColors.purpleLight],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Social Graph',
                            style: AppText.body(16, weight: FontWeight.w600),
                          ),
                          Text(
                            'Your network, mapped by Alter',
                            style: AppText.body(
                              12.5,
                              color: AppColors.white(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.white(0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            GestureDetector(
              onTap: () => context.push(AlterRoutes.memory),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.purpleLight.withValues(alpha: 0.16),
                      AppColors.purple.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.purpleLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.purpleLight.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.memory_outlined,
                        color: AppColors.purpleLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Memory Ledger',
                            style: AppText.body(16, weight: FontWeight.w600),
                          ),
                          Text(
                            'Inspect, correct, and govern what ALTER remembers',
                            style: AppText.body(
                              12.5,
                              color: AppColors.white(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.white(0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            // NFC
            GestureDetector(
              onTap: () => context.push(AlterRoutes.nfc),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.cyan.withValues(alpha: 0.14),
                      AppColors.cyan.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.contactless_outlined,
                        color: AppColors.cyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tap to connect · NFC',
                            style: AppText.body(16, weight: FontWeight.w600),
                          ),
                          Text(
                            'Share a context-aware profile',
                            style: AppText.body(
                              12.5,
                              color: AppColors.white(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'CONNECTED PLATFORMS',
              style: AppText.kicker(AppColors.white(0.45), size: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _platform('N', 'Notion', circle: false,
                    onTap: () => context.push(AlterRoutes.integrations)),
                const SizedBox(width: 10),
                _platform('GH', 'GitHub', circle: true,
                    onTap: () => context.push(AlterRoutes.integrations)),
              ],
            ),
            const SizedBox(height: 16),
            OutlineButton2(
              label: 'Edit profile',
              onTap: () => context.push(AlterRoutes.profileEdit),
            ),
            const SizedBox(height: 10),
            OutlineButton2(
              label: 'Account & settings',
              onTap: shell.openSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color c) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        radius: 16,
        child: Column(
          children: [
            Text(
              value,
              style: AppText.display(22, weight: FontWeight.w600, color: c),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.body(11, color: AppColors.white(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _platform(String mark, String name,
      {required bool circle, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 14,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circle ? null : BorderRadius.circular(7),
              ),
              child: Text(
                mark,
                style: AppText.body(
                  circle ? 12 : 14,
                  weight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.body(13, weight: FontWeight.w600)),
                Text('Connect', style: AppText.body(10, color: AppColors.white(0.45))),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
