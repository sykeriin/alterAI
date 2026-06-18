import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/routes.dart';
import '../../../core/config/alter_gateway_config.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../data/gateway/alter_gateway_providers.dart';
import '../../../app/app_state.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets.dart';
import '../../auth/application/auth_provider.dart';
import '../../memory/application/memory_review_controller.dart';
import '../../profile/application/profile_provider.dart';
import '../../profile/domain/user_profile.dart';
import '../../actions/presentation/action_inbox_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _keyObscured = true;
  bool _keySaved = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing key when profile loads
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile?.openaiKey.isNotEmpty == true) {
      _keyController.text = profile!.openaiKey;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(alterAppControllerProvider);
    final controller = ref.read(alterAppControllerProvider.notifier);
    final theme = Theme.of(context);
    final userId = ref.watch(localUserIdProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final hasKey = profile?.openaiKey.isNotEmpty == true;
    final gatewayHealth = ref.watch(gatewayHealthProvider);
    final pendingAsync = ref.watch(memoryPendingCountProvider);
    final pendingReview = pendingAsync.asData?.value ?? 0;
    final gatewayIntegrations = ref.watch(gatewayIntegrationsProvider);

    // Sync key controller when profile loads
    ref.listen(userProfileProvider, (_, next) {
      final p = next.asData?.value;
      if (p != null && _keyController.text.isEmpty && p.openaiKey.isNotEmpty) {
        _keyController.text = p.openaiKey;
      }
    });

    return DeepScaffold(
      title: 'SETTINGS',
      subtitle:
          'Tune theme, privacy, model stack, voice preferences, and connected systems.',
      child: ListView(
        children: [
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              MetricTile(
                label: 'Model routing',
                value: hasKey ? 'Your key' : 'Not set up',
                icon: LucideIcons.brain_circuit,
                accent: AlterPalette.mint,
              ),
              GestureDetector(
                onTap: () => context.push(AlterRoutes.memory),
                child: MetricTile(
                  label: 'Memory review',
                  value: pendingReview > 0
                      ? '$pendingReview pending'
                      : 'All clear',
                  icon: LucideIcons.brain,
                  accent: AlterPalette.aura,
                  detail: 'Swipe to keep or forget what ALTER learned',
                ),
              ),
              const MetricTile(
                label: 'Latency target',
                value: '<300 ms',
                icon: LucideIcons.zap,
                accent: AlterPalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Appearance',
                  subtitle: 'Use system theme or force a precise mode.',
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: AlterUiTheme.isLight,
                  builder: (context, themeLight, _) {
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(LucideIcons.sun),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(LucideIcons.moon),
                        ),
                      ],
                      selected: {
                        themeLight ? ThemeMode.light : ThemeMode.dark,
                      },
                      onSelectionChanged: (s) async {
                        final mode = s.first;
                        await AlterUiTheme.setLight(mode == ThemeMode.light);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'AI Configuration',
                  subtitle: hasKey
                      ? 'Using your own OpenAI key — billed to your account.'
                      : 'Add your OpenAI API key below to enable Cloud AI voice and chat.',
                  trailing: PremiumChip(
                    label: hasKey ? 'Your key' : 'BYOK',
                    selected: true,
                    icon: LucideIcons.circle_check,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _keyController,
                  obscureText: _keyObscured,
                  decoration: InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'sk-...',
                    prefixIcon: const Icon(LucideIcons.key_round),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _keyObscured
                                ? LucideIcons.eye
                                : LucideIcons.eye_off,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _keyObscured = !_keyObscured),
                        ),
                        if (_keyController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _keyController.clear();
                              setState(() => _keySaved = false);
                            },
                          ),
                      ],
                    ),
                    helperText: _keySaved
                        ? 'Key saved — your requests now use your own key'
                        : 'Optional. Get a key at platform.openai.com for unlimited use',
                    helperStyle: TextStyle(
                      color: _keySaved ? AlterPalette.mint : null,
                    ),
                  ),
                  onChanged: (_) => setState(() => _keySaved = false),
                ),
                const SizedBox(height: 14),
                PremiumButton(
                  label: 'Save API Key',
                  icon: LucideIcons.save,
                  compact: true,
                  onPressed: _saveApiKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: SectionHeader(
              title: 'Memory review',
              subtitle:
                  'Review facts ALTER inferred about you — keep what matters, '
                  'forget the rest.',
              trailing: PremiumButton(
                label: pendingReview > 0 ? '$pendingReview pending' : 'Open',
                compact: true,
                icon: LucideIcons.brain,
                onPressed: () => context.push(AlterRoutes.memory),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: SectionHeader(
              title: 'Performance & offline models',
              subtitle:
                  'Device tier, RAM telemetry, edge pattern check, and offline voice packs.',
              trailing: PremiumButton(
                label: 'Open',
                compact: true,
                icon: LucideIcons.gauge,
                onPressed: () => context.push(AlterRoutes.performance),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: SectionHeader(
              title: 'Language & localization',
              subtitle:
                  'Choose spoken and written languages for voice, gateway, and translation.',
              trailing: PremiumButton(
                label: 'Open',
                compact: true,
                icon: LucideIcons.languages,
                onPressed: () => context.push(AlterRoutes.languageSettings),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: SectionHeader(
              title: 'Permissions',
              subtitle:
                  'Review microphone, notifications, Accessibility, camera, contacts, and notification access.',
              trailing: PremiumButton(
                label: 'Open hub',
                compact: true,
                icon: LucideIcons.shield_check,
                onPressed: () => context.go(AlterRoutes.permissions),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ResponsiveGrid(
            mediumColumns: 2,
            expandedColumns: 2,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Privacy',
                      subtitle:
                          'Agent actions stay permissioned and auditable.',
                    ),
                    const SizedBox(height: 14),
                    _SwitchRow(
                      icon: LucideIcons.shield_check,
                      title: 'Privacy shield',
                      subtitle: 'Require confirmation before external actions.',
                      value: appState.privacyShield,
                      onChanged: controller.setPrivacyShield,
                    ),
                    _SwitchRow(
                      icon: LucideIcons.bell,
                      title: 'Proactive briefs',
                      subtitle: 'Let ALTER prepare daily next-move briefings.',
                      value: appState.proactiveBriefs,
                      onChanged: controller.setProactiveBriefs,
                    ),
                    const SizedBox(height: 16),
                    const ActionAutonomySettings(),
                  ],
                ),
              ),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Connected systems',
                      subtitle: 'Production adapters ready to replace mocks.',
                    ),
                    const SizedBox(height: 14),
                    if (AlterGatewayConfig.isConfigured)
                      gatewayHealth.when(
                        data: (health) {
                          final okCount = health.services
                              .where((service) => service.status == 'ok')
                              .length;
                          return _SystemRow(
                            'ALTER Gateway',
                            '${health.status.toUpperCase()} · $okCount/${health.services.length} services healthy',
                          );
                        },
                        loading: () => const _SystemRow(
                          'ALTER Gateway',
                          'Checking backend health…',
                        ),
                        error: (_, __) => const _SystemRow(
                          'ALTER Gateway',
                          'Offline',
                        ),
                      ),
                    const _SystemRow(
                      'Local vault',
                      'SQLCipher on-device',
                    ),
                    _SystemRow(
                      'OpenAI',
                      hasKey ? 'Your key (BYOK)' : 'Add key in Settings',
                    ),
                    if (AlterGatewayConfig.isConfigured)
                      gatewayIntegrations.when(
                        data: (snapshot) {
                          if (snapshot == null) {
                            return const _SystemRow(
                              'Integrations',
                              'Sign in to load platform connections.',
                            );
                          }
                          final connected = snapshot.platforms
                              .where((platform) => platform.connected)
                              .length;
                          return _SystemRow(
                            'Integrations',
                            '$connected/${snapshot.platforms.length} platforms connected',
                          );
                        },
                        loading: () => const _SystemRow(
                          'Integrations',
                          'Loading platform connections…',
                        ),
                        error: (_, __) => const _SystemRow(
                          'Integrations',
                          'Gateway integrations unavailable.',
                        ),
                      ),
                    const _SystemRow('Neo4j', 'Social graph (planned)'),
                    const _SystemRow('Qdrant', 'Semantic memory (planned)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Account',
                  subtitle: 'Manage your ALTER identity.',
                ),
                const SizedBox(height: 14),
                if (profile != null && profile.displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AlterPalette.iris.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              LucideIcons.user,
                              color: AlterPalette.iris,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                profile.role.isNotEmpty
                                    ? profile.role
                                    : 'Local profile',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.58,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          label: const Text('Edit'),
                          onPressed: () => context.go(AlterRoutes.profileEdit),
                        ),
                      ],
                    ),
                  )
                else if (userId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AlterPalette.iris.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              LucideIcons.user,
                              color: AlterPalette.iris,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vault unlocked',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Local ID · ${userId.substring(0, 8)}…',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.58,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(LucideIcons.user_cog, size: 16),
                          label: const Text('Set up profile'),
                          onPressed: () => context.go(AlterRoutes.profileEdit),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.lock, size: 18),
                    label: const Text('Lock ALTER'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AlterPalette.danger,
                      side: BorderSide(
                        color: AlterPalette.danger.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await ref.read(authServiceProvider).lock();
                      if (context.mounted) context.go(AlterRoutes.pinUnlock);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveApiKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    final notifier = ref.read(userProfileProvider.notifier);
    final existing = ref.read(userProfileProvider).asData?.value;
    final userId = ref.read(localUserIdProvider) ?? '';

    final toSave = existing != null
        ? existing.copyWith(openaiKey: key)
        : UserProfile(
            id: userId,
            displayName: '',
            role: '',
            careerStage: '',
            industry: '',
            bio: '',
            skills: const [],
            goals: const [],
            interests: const [],
            languages: const ['English'],
            location: '',
            availability: '',
            openaiKey: key,
            sarvamKey: '',
            onboardingDone: false,
          );

    await notifier.save(toSave);
    if (mounted) setState(() => _keySaved = true);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AlterPalette.iris.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AlterPalette.iris, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow(this.name, this.detail);

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.check, color: AlterPalette.mint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
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
