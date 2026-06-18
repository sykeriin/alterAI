import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alter/src/core/config/alter_gateway_config.dart';
import 'package:alter/src/core/network/backend_health_service.dart';
import 'package:alter/src/features/auth/application/auth_provider.dart';
import 'package:alter/src/features/device_control/application/phone_control_controller.dart';
import 'package:alter/src/features/contextos/application/gemma_model_manager.dart';
import 'package:alter/src/features/voice/application/voice_backend_preference.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';

class SettingsDrawer extends ConsumerStatefulWidget {
  const SettingsDrawer({super.key});
  @override
  ConsumerState<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends ConsumerState<SettingsDrawer> {
  final toggles = <String, bool>{
    'wake': true,
    'calendar': true,
    'resume': true,
    'location': false,
    'notif': true,
    'comm': false,
  };
  bool _showAdvanced = false;
  late final TextEditingController _gatewayUrl;

  @override
  void initState() {
    super.initState();
    _gatewayUrl = TextEditingController(
      text: AlterGatewayConfig.hasUserOverride
          ? AlterGatewayConfig.runtimeOverride
          : '',
    );
  }

  @override
  void dispose() {
    _gatewayUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlterUiTheme.isLight,
      builder: (context, light, __) => _buildDrawer(context, light),
    );
  }

  Widget _buildDrawer(BuildContext context, bool light) {
    final width = MediaQuery.of(context).size.width * 0.9;
    final phone = ref.watch(phoneControlControllerProvider);
    final voiceBackend = ref.watch(voiceBackendPreferenceProvider);
    final gemma = ref.watch(gemmaModelProvider);
    final healthAsync = ref.watch(backendHealthProvider);
    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.0, -1.0),
            radius: 1.3,
            colors: light
                ? const [Color(0xFFECE4F6), Color(0xFFF3EEFB), Color(0xFFECE7F5)]
                : const [Color(0xFF241A40), Color(0xFF120E1C), AppColors.bg],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border(left: BorderSide(color: AppColors.white(0.14))),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Settings',
                        style: AppText.display(26, weight: FontWeight.w500)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white(0.06),
                          border: Border.all(color: AppColors.white(0.16)),
                        ),
                        child: Icon(Icons.close, size: 16, color: AppColors.white(0.9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text('APPEARANCE',
                    style: AppText.kicker(AppColors.white(0.4), size: 11)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.white(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.white(0.1)),
                  ),
                  child: Row(children: [
                    _themeSeg('Dark', Icons.dark_mode_outlined, !light,
                        () async {
                      await AlterUiTheme.setLight(false);
                    }),
                    const SizedBox(width: 8),
                    _themeSeg('Light', Icons.light_mode_outlined, light,
                        () async {
                      await AlterUiTheme.setLight(true);
                    }),
                  ]),
                ),
                const SizedBox(height: 30),
                Text('VOICE & AI',
                    style: AppText.kicker(AppColors.white(0.4), size: 11)),
                const SizedBox(height: 8),
                Text(
                  'Choose which AI powers Voice. Pick Gemma on-device for '
                  'fully local inference after the model is downloaded.',
                  style: AppText.body(12, color: AppColors.white(0.45), height: 1.4),
                ),
                const SizedBox(height: 12),
                ...VoiceBackend.values.map((b) {
                  final selected = voiceBackend == b;
                  final health = healthAsync.asData?.value;
                  String? statusLabel;
                  if (b == VoiceBackend.onDevice) {
                    statusLabel = switch (gemma.status) {
                      GemmaStatus.ready => 'Ready',
                      GemmaStatus.installed => 'Load in EDGE',
                      GemmaStatus.downloading => 'Downloading…',
                      GemmaStatus.loading => 'Loading…',
                      GemmaStatus.notInstalled => 'Download in EDGE',
                      GemmaStatus.error => 'Error',
                      _ => null,
                    };
                  } else if (health != null) {
                    final status = switch (b) {
                      VoiceBackend.cloudAi => health.cloudAi,
                      VoiceBackend.gateway => health.gateway,
                      VoiceBackend.onDevice => null,
                    };
                    if (status != null) statusLabel = healthStatusLabel(status);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await ref
                            .read(voiceBackendPreferenceProvider.notifier)
                            .set(b);
                        if (b == VoiceBackend.onDevice) {
                          await ref
                              .read(gemmaModelProvider.notifier)
                              .ensureLoaded();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lime.withValues(alpha: 0.12)
                              : AppColors.white(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.lime.withValues(alpha: 0.5)
                                : AppColors.white(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.label,
                                      style: AppText.body(14,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(b.description,
                                      style: AppText.body(12,
                                          color: AppColors.white(0.45),
                                          height: 1.35)),
                                ],
                              ),
                            ),
                            if (statusLabel != null)
                              Text(
                                statusLabel,
                                style: AppText.body(11,
                                    color: statusLabel == 'Ready'
                                        ? AppColors.lime
                                        : AppColors.white(0.45)),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: selected
                                  ? AppColors.lime
                                  : AppColors.white(0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                _menuRow('Edge pattern check', 'Local redaction & scam heuristics',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.edge);
                }),
                const SizedBox(height: 8),
                _menuRow('Languages', 'Hindi, English, Kannada, Tamil…',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.languageSettings);
                }),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: AppColors.white(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text('Advanced · Developer',
                          style: AppText.body(13,
                              color: AppColors.white(0.55),
                              weight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _gatewayUrl,
                    style: AppText.body(13),
                    decoration: InputDecoration(
                      labelText: 'Custom cloud endpoint (optional)',
                      hintText: 'Leave blank for default',
                      labelStyle: AppText.body(12, color: AppColors.white(0.5)),
                      filled: true,
                      fillColor: AppColors.white(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.white(0.12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LimeButton(
                    label: 'Save custom endpoint',
                    height: 44,
                    onTap: () async {
                      await AlterGatewayConfig.setRuntimeOverride(
                          _gatewayUrl.text);
                      ref.invalidate(backendHealthProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Cloud endpoint saved')),
                        );
                      }
                    },
                  ),
                ],
                const SizedBox(height: 30),
                Text('GENERAL', style: AppText.kicker(AppColors.white(0.4), size: 11)),
                const SizedBox(height: 8),
                _menuRow('All settings', 'Theme, AI, privacy, account',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.settings);
                }),
                _menuRow('Permission hub', 'Wake, mic, camera, contacts',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.permissions);
                }),
                _menuRow('Phone control queue', 'Confirm Send/Pay actions',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.openclaw);
                }),
                _menuRow('Agent console', 'Natural language + phone tools',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.agent);
                }),
                _menuRow('Edit profile', 'Name, skills, goals, context',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.profileEdit);
                }),
                _menuRow('Advanced · Context OS', 'Developer hub & twin tools',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.contextHub);
                }),
                _menuRow('Memory Ledger', 'Inspect and correct memories',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.memory);
                }),
                _menuRow('Connected platforms', 'Notion, GitHub', onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.integrations);
                }),
                _menuRow('Language & localization', 'Gateway multilingual catalog',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.languageSettings);
                }),
                _menuRow('Data management', 'Export or delete everything',
                    onTap: () {
                  Navigator.of(context).pop();
                  context.push(AlterRoutes.dataManagement);
                }, last: true),
                const SizedBox(height: 30),
                Text('DATA PERMISSIONS',
                    style: AppText.kicker(AppColors.white(0.4), size: 11)),
                const SizedBox(height: 6),
                Text('You own your data. Alter only reads what you allow.',
                    style: AppText.body(12.5, color: AppColors.white(0.4), height: 1.5)),
                const SizedBox(height: 10),
                _toggleRow(
                  'accessibility',
                  'Phone control',
                  phone.accessibilityEnabled
                      ? 'Accessibility service enabled'
                      : 'Tap to open accessibility settings',
                  value: phone.accessibilityEnabled,
                  onChanged: (_) async {
                    if (!phone.accessibilityEnabled) {
                      await ref
                          .read(phoneControlControllerProvider.notifier)
                          .openAccessibilitySettings();
                    }
                    await ref
                        .read(phoneControlControllerProvider.notifier)
                        .refresh();
                  },
                ),
                _toggleRow(
                  'calendar',
                  'Calendar access',
                  'Briefs & deadline intelligence',
                  value: toggles['calendar']!,
                  onChanged: (v) => setState(() => toggles['calendar'] = v),
                ),
                _toggleRow(
                  'resume',
                  'Resume sync',
                  'Skills & gap analysis',
                  value: toggles['resume']!,
                  onChanged: (v) => setState(() => toggles['resume'] = v),
                ),
                _toggleRow(
                  'location',
                  'Location data',
                  'Context-aware prompts',
                  value: toggles['location']!,
                  onChanged: (v) => setState(() => toggles['location'] = v),
                ),
                _toggleRow(
                  'notif',
                  'Notification stream',
                  'Extract commitments & deadlines',
                  value: toggles['notif']!,
                  onChanged: (v) => setState(() => toggles['notif'] = v),
                ),
                _toggleRow(
                  'comm',
                  'Communication threads',
                  'Email & messaging context',
                  value: toggles['comm']!,
                  onChanged: (v) => setState(() => toggles['comm'] = v),
                  last: true,
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      context.go(AlterRoutes.login);
                    }
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text('Sign out',
                        style: AppText.body(14,
                            weight: FontWeight.w600, color: AppColors.danger)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeSeg(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.pill : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: active ? AppColors.pillInk : AppColors.white(0.6)),
              const SizedBox(width: 7),
              Text(label,
                  style: AppText.body(14,
                      weight: FontWeight.w700,
                      color: active ? AppColors.pillInk : AppColors.white(0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(String title, String sub,
      {bool chevron = true, bool last = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 2),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.white(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.body(12.5, color: AppColors.white(0.45))),
              ],
            ),
          ),
          if (chevron)
            Icon(Icons.chevron_right, color: AppColors.white(0.35)),
        ],
      ),
    ),
    );
  }

  Widget _toggleRow(
    String key,
    String title,
    String sub, {
    bool last = false,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.white(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.body(12.5, color: AppColors.white(0.45))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 27,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.lime : AppColors.white(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? AppColors.bg : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
