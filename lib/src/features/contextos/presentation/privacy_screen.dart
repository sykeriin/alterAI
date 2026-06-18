import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../data/gateway/alter_gateway_providers.dart';
import '../../../ui/routes.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../ui/widgets.dart';
import '../application/memory_engine.dart';
import '../application/preferences_controller.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/contextos_models.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static const _surfaces = [
    MomentSource.notification,
    MomentSource.shareSheet,
    MomentSource.camera,
    MomentSource.mic,
    MomentSource.screenshot,
    MomentSource.sms,
    MomentSource.whatsapp,
    MomentSource.social,
    MomentSource.notes,
    MomentSource.photos,
    MomentSource.contacts,
    MomentSource.calendar,
    MomentSource.email,
    MomentSource.browser,
    MomentSource.location,
    MomentSource.files,
    MomentSource.qr,
    MomentSource.call,
    MomentSource.payment,
    MomentSource.install,
    MomentSource.manual,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(preferencesProvider);
    final prefs = prefsAsync.asData?.value ?? const ContextOsPrefs();
    final notifier = ref.read(preferencesProvider.notifier);
    final consentAsync = ref.watch(gatewayConsentLedgerProvider);
    final consent = consentAsync.asData?.value;

    return AmbientScaffold(
      header: ShellPageHeader(
        title: 'PRIVACY',
        subtitle:
            'You control what ALTER senses and what leaves the phone. '
            'Sensitive data is redacted on-device before any cloud call.',
        onGear: () => context.push(AlterRoutes.settings),
      ),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            child: Column(
              children: [
                _SwitchRow(
                  icon: LucideIcons.lock,
                  title: 'Private Mode by default',
                  subtitle: 'New moments stay on-device — no cloud reasoning.',
                  value: prefs.privateModeDefault,
                  onChanged: notifier.setPrivateDefault,
                ),
                const Divider(height: 22),
                _SwitchRow(
                  icon: LucideIcons.cloud,
                  title: 'Allow cloud reasoning',
                  subtitle:
                      'Escalate redacted moments for deeper proof — only with consent.',
                  value: prefs.cloudConsent,
                  onChanged: (value) async {
                    await notifier.setCloudConsent(value);
                    await _syncCloudConsent(ref, value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.toggle_right,
                      size: 18,
                      color: AlterPalette.iris,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Per-source sensing',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Disable any surface you don’t want ALTER to read.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 6),
                for (final s in _surfaces)
                  _SwitchRow(
                    icon: s.icon,
                    title: s.label,
                    subtitle: '',
                    value: prefs.isSurfaceEnabled(s),
                    onChanged: (_) => notifier.toggleSurface(s),
                    dense: true,
                  ),
              ],
            ),
          ),
          if (AlterGatewayConfig.isConfigured && consent != null) ...[
            const SizedBox(height: 14),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consent ledger',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    consent.auditNote.isNotEmpty
                        ? consent.auditNote
                        : 'Gateway-tracked consent grants for assistant features.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final grant in consent.grants.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            grant.granted
                                ? LucideIcons.circle_check
                                : LucideIcons.circle_off,
                            size: 16,
                            color: grant.granted
                                ? AlterPalette.mint
                                : AlterPalette.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grant.source,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${grant.accessLevel} · ${grant.retentionDays}d retention',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.58),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          GlassPanel(
            onTap: () => context.push(AlterRoutes.dataManagement),
            child: Row(
              children: [
                Icon(LucideIcons.database, size: 18, color: AlterPalette.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export & delete data',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Privacy export, consent ledger, and gateway delete.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevron_right, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            onTap: () => context.go(AlterRoutes.mission),
            child: Row(
              children: [
                Icon(
                  LucideIcons.scroll_text,
                  size: 18,
                  color: AlterPalette.cyan,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action audit log',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Every edge/cloud/consent/action event — in Mission Control.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.58,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevron_right, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete memory',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Forget every trusted source. ALTER will re-evaluate all sources from scratch.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.trash_2, size: 16),
                  label: const Text('Delete all memories'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AlterPalette.danger,
                  ),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _syncCloudConsent(WidgetRef ref, bool granted) async {
    if (!AlterGatewayConfig.isConfigured) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    try {
      await ref.read(alterGatewayApiClientProvider).recordConsent(
            userId: userId,
            source: 'cloud_reasoning',
            granted: granted,
            accessLevel: granted ? 'redacted_cloud' : 'metadata',
            reason: granted
                ? 'User enabled cloud reasoning from privacy screen.'
                : 'User disabled cloud reasoning.',
          );
      ref.invalidate(gatewayConsentLedgerProvider);
    } catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all memories?'),
        content: const Text(
          'This removes every trusted source. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AlterPalette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null && AlterGatewayConfig.isConfigured) {
        try {
          await ref.read(alterGatewayApiClientProvider).deletePrivacy(
                userId: userId,
                scopes: const <String>['memory'],
              );
        } catch (_) {}
      }
      await ref.read(memoryProvider.notifier).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All memories deleted.')));
      }
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AlterPalette.iris),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.56,
                      ),
                      height: 1.25,
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
