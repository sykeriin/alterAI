import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/alter_gateway_config.dart';
import '../../features/auth/application/auth_provider.dart';
import 'alter_gateway_api_client.dart';

final alterGatewayApiClientProvider = Provider<AlterGatewayApiClient>((ref) {
  final client = AlterGatewayApiClient();
  ref.onDispose(client.close);
  return client;
});

final gatewayHealthProvider = FutureProvider<GatewayHealthSnapshot>((ref) async {
  if (!AlterGatewayConfig.isConfigured) {
    throw StateError('Gateway URL is not configured.');
  }
  return ref.watch(alterGatewayApiClientProvider).fetchHealth();
});

final gatewayLanguagesProvider = FutureProvider<MultilingualCatalog>((ref) async {
  if (!AlterGatewayConfig.isConfigured) {
    return const MultilingualCatalog(
      sarvamEnabled: false,
      indianLanguages: [],
      majorForeignLanguages: [],
    );
  }
  return ref.watch(alterGatewayApiClientProvider).fetchLanguages();
});

final gatewayUserSettingsProvider =
    FutureProvider<UserSettingsSnapshot?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !AlterGatewayConfig.isConfigured) return null;
  return ref.watch(alterGatewayApiClientProvider).fetchUserSettings(
        userId: user.id,
      );
});

final gatewayIntegrationsProvider =
    FutureProvider<IntegrationsSnapshot?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !AlterGatewayConfig.isConfigured) return null;
  return ref.watch(alterGatewayApiClientProvider).fetchIntegrations(
        userId: user.id,
      );
});

final gatewayConsentLedgerProvider =
    FutureProvider<ConsentLedgerSnapshot?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !AlterGatewayConfig.isConfigured) return null;
  return ref.watch(alterGatewayApiClientProvider).fetchConsentLedger(
        userId: user.id,
      );
});
