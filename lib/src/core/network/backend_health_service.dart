import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/alter_gateway_config.dart';
import '../../data/gateway/alter_gateway_api_client.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/profile/application/profile_provider.dart';

enum BackendHealthStatus { checking, ready, notSetUp, offline }

class BackendHealthSnapshot {
  const BackendHealthSnapshot({
    required this.cloudAi,
    required this.gateway,
  });

  final BackendHealthStatus cloudAi;
  final BackendHealthStatus gateway;
}

final backendHealthProvider = FutureProvider<BackendHealthSnapshot>((ref) async {
  final profile = ref.watch(userProfileProvider).asData?.value;
  final unlocked = ref.watch(isDbUnlockedProvider);

  BackendHealthStatus cloud;
  if (!unlocked) {
    cloud = BackendHealthStatus.notSetUp;
  } else if (profile?.openaiKey.isNotEmpty == true) {
    cloud = BackendHealthStatus.ready;
  } else {
    cloud = BackendHealthStatus.notSetUp;
  }

  BackendHealthStatus gateway = BackendHealthStatus.offline;
  if (AlterGatewayConfig.isConfigured) {
    try {
      final client = AlterGatewayApiClient();
      final health = await client.fetchHealth().timeout(
            const Duration(seconds: 5),
          );
      client.close();
      gateway = health.status == 'ok' || health.status == 'degraded'
          ? BackendHealthStatus.ready
          : BackendHealthStatus.offline;
    } catch (_) {
      gateway = BackendHealthStatus.offline;
    }
  }

  return BackendHealthSnapshot(
    cloudAi: cloud,
    gateway: gateway,
  );
});

String healthStatusLabel(BackendHealthStatus status) => switch (status) {
      BackendHealthStatus.checking => 'Checking…',
      BackendHealthStatus.ready => 'Ready',
      BackendHealthStatus.notSetUp => 'Not set up',
      BackendHealthStatus.offline => 'Offline',
    };
