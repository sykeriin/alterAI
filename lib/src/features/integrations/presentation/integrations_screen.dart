import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/theme/alter_palette.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/premium_controls.dart';
import '../../../ui/widgets.dart';
import '../../auth/application/auth_provider.dart';
import '../../../data/gateway/alter_gateway_api_client.dart';
import '../../../data/gateway/alter_gateway_providers.dart';

class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  final _busy = <String>{};

  Future<void> _toggle(PlatformIntegration platform, bool connect) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _busy.add(platform.id));
    try {
      await ref.read(alterGatewayApiClientProvider).recordConsent(
            userId: user.id,
            source: platform.id,
            granted: connect,
            accessLevel: connect ? 'read_write' : 'metadata',
            reason: connect
                ? 'User connected ${platform.name} from integrations screen.'
                : 'User disconnected ${platform.name}.',
          );
      ref.invalidate(gatewayIntegrationsProvider);
      ref.invalidate(gatewayConsentLedgerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connect ? '${platform.name} connected.' : '${platform.name} disconnected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(UserFacingError.from(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(platform.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final integrations = ref.watch(gatewayIntegrationsProvider);

    return DeepScaffold(
      title: 'CONNECTED PLATFORMS',
      subtitle: AlterGatewayConfig.isConfigured
          ? 'Grant consent per platform. ALTER routes data through the gateway.'
          : 'Cloud sync is not available yet. Finish setup and try again from Settings.',
      child: integrations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Unable to load: $error')),
              data: (snapshot) {
                final platforms = snapshot?.platforms ?? const [];
                if (platforms.isEmpty) {
                  return const Center(child: Text('No platforms returned by gateway.'));
                }
                return ListView.separated(
                  itemCount: platforms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final platform = platforms[index];
                    final busy = _busy.contains(platform.id);
                    return GlassPanel(
                      child: Row(
                        children: [
                          Icon(
                            platform.connected
                                ? LucideIcons.link
                                : LucideIcons.unlink,
                            color: platform.connected
                                ? AlterPalette.mint
                                : AlterPalette.iris,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  platform.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  platform.status,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.58),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Switch(
                              value: platform.connected,
                              onChanged: (value) => _toggle(platform, value),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
