import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/features/profile/application/profile_provider.dart';
import '../../../ui/routes.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../application/permission_hub_controller.dart';

class PermissionHubScreen extends ConsumerStatefulWidget {
  const PermissionHubScreen({super.key});

  @override
  ConsumerState<PermissionHubScreen> createState() =>
      _PermissionHubScreenState();
}

class _PermissionHubScreenState extends ConsumerState<PermissionHubScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionHubControllerProvider.notifier).refresh();
    }
  }

  void _continue() {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile?.onboardingDone == true) {
      context.go(AlterRoutes.home);
    } else {
      context.go(AlterRoutes.languages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionHubControllerProvider);
    final controller = ref.read(permissionHubControllerProvider.notifier);
    final progress = state.items.isEmpty
        ? 0.0
        : state.grantedCount / state.items.length;

    return Scaffold(
      body: GradientScaffold(
        bgColors: const [Color(0xFF2A1F4A), Color(0xFF15101F), AppColors.bg],
        bgCenter: const Alignment(0.0, -1.0),
        orbs: [
          PositionedOrb(
            top: -40,
            left: 0,
            right: 0,
            orb: Orb(
              size: 280,
              blur: 20,
              colors: [AppColors.purple.withValues(alpha: 0.6)],
            ),
          ),
          PositionedOrb(
            top: 200,
            right: -30,
            orb: const Orb(
              size: 160,
              blur: 12,
              colors: [AppColors.lime, AppColors.limeDeep],
            ),
          ),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 32, 30, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StarMark(size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'ALTER',
                      style: AppText.display(14,
                          weight: FontWeight.w600, letterSpacing: 3),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text('PERMISSION HUB', style: AppText.kicker(AppColors.lime)),
                const SizedBox(height: 14),
                Text(
                  'Enable ALTER\nlike an assistant.',
                  style: AppText.display(34, weight: FontWeight.w500, height: 1.08),
                ),
                const SizedBox(height: 14),
                Text(
                  'Wake word, phone control, notification context, camera, contacts, and device admin for policy control.',
                  style: AppText.body(16,
                      color: AppColors.white(0.62), height: 1.55),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.essentialsReady
                                      ? 'Essentials ready'
                                      : 'Enable essentials',
                                  style: AppText.display(18,
                                      weight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${state.grantedEssentialCount}/${state.essentialCount} essential permissions enabled.',
                                  style: AppText.body(13,
                                      color: AppColors.white(0.55)),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: state.loading ? null : controller.refresh,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.white(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.white(0.14)),
                              ),
                              child: Icon(
                                Icons.refresh,
                                size: 20,
                                color: state.loading
                                    ? AppColors.white(0.3)
                                    : AppColors.white(0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: progress.clamp(0, 1),
                          backgroundColor: AppColors.white(0.08),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.lime),
                        ),
                      ),
                      if (state.error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error,
                          style: AppText.body(13,
                              color: AppColors.orange, weight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      LimeButton(
                        label: 'Ask runtime permissions',
                        trailing: Icons.shield_outlined,
                        height: 52,
                        onTap: state.loading
                            ? null
                            : controller.requestRuntimePermissions,
                      ),
                      const SizedBox(height: 10),
                      OutlineButton2(
                        label: 'Open app settings',
                        height: 48,
                        onTap: state.loading ? null : controller.openAppSettings,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final item in state.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PermissionRow(
                      item: item,
                      loading: state.loading,
                      onTap: () => controller.request(item.id),
                    ),
                  ),
                const SizedBox(height: 16),
                LimeButton(
                  label: 'Continue to ALTER',
                  onTap: _continue,
                ),
                const SizedBox(height: 12),
                OutlineButton2(
                  label: 'Skip for now',
                  onTap: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.item,
    required this.loading,
    required this.onTap,
  });

  final PermissionHubItem item;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final granted = item.granted;
    final accent = granted ? AppColors.lime : AppColors.purpleLight;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Icon(item.icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppText.body(15, weight: FontWeight.w700),
                      ),
                    ),
                    if (item.essential)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'Essential',
                          style: AppText.body(10,
                              weight: FontWeight.w700, color: AppColors.purpleLight),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: AppText.body(12,
                      color: AppColors.white(0.55), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading || granted ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.lime.withValues(alpha: 0.15)
                    : AppColors.white(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: granted
                      ? AppColors.lime.withValues(alpha: 0.4)
                      : AppColors.white(0.16),
                ),
              ),
              child: Text(
                granted
                    ? 'On'
                    : item.opensSettings
                        ? 'Settings'
                        : 'Allow',
                style: AppText.body(12,
                    weight: FontWeight.w700,
                    color: granted ? AppColors.lime : AppColors.white(0.85)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
