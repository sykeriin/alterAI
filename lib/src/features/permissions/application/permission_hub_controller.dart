import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/application/backend_config_controller.dart';
import '../../backend/data/backend_api_client.dart';
import '../data/permission_hub_bridge.dart';

final permissionHubBridgeProvider = Provider<PermissionHubBridge>((ref) {
  return PermissionHubBridge();
});

final permissionHubControllerProvider =
    NotifierProvider<PermissionHubController, PermissionHubState>(
      PermissionHubController.new,
    );

class PermissionHubController extends Notifier<PermissionHubState> {
  @override
  PermissionHubState build() {
    Future.microtask(refresh);
    return PermissionHubState(items: PermissionHubItem.defaults());
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: '');
    try {
      final statuses = await ref
          .read(permissionHubBridgeProvider)
          .getStatuses();
      state = state.copyWith(
        loading: false,
        items: _merge(statuses),
        error: statuses.isEmpty
            ? 'Permission status is available on Android.'
            : '',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> request(String id) async {
    state = state.copyWith(loading: true, error: '');
    try {
      final statuses = await ref.read(permissionHubBridgeProvider).request(id);
      final items = _merge(statuses);
      state = state.copyWith(loading: false, items: items);
      final item = items.where((entry) => entry.id == id).firstOrNull;
      if (item != null) {
        await _syncConsent(item);
      }
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> requestRuntimePermissions() async {
    for (final id in const [
      'microphone',
      'notifications',
      'camera',
      'contacts',
    ]) {
      await request(id);
    }
    await refresh();
  }

  Future<void> openAppSettings() async {
    state = state.copyWith(loading: true, error: '');
    final statuses = await ref
        .read(permissionHubBridgeProvider)
        .openAppSettings();
    state = state.copyWith(loading: false, items: _merge(statuses));
  }

  List<PermissionHubItem> _merge(Map<String, PermissionStatusEntry> statuses) {
    return [
      for (final item in PermissionHubItem.defaults())
        item.copyWith(status: statuses[item.id]),
    ];
  }

  Future<void> _syncConsent(PermissionHubItem item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final config = await ref.read(backendConfigProvider.future);
    if (!config.hasGateway) return;
    final client = BackendApiClient(baseUrl: config.gatewayUrl);
    try {
      await client.postJson('/v1/security/consent', {
        'user_id': userId,
        'source': item.id,
        'access_level': item.systemManaged
            ? 'system_setting'
            : 'runtime_permission',
        'granted': item.granted,
        'retention_days': 365,
        'reason': 'Updated from Android Permission Hub.',
      });
    } catch (_) {
      // Native permission state remains authoritative; consent sync can retry later.
    } finally {
      client.close();
    }
  }
}

class PermissionHubState {
  const PermissionHubState({
    required this.items,
    this.loading = false,
    this.error = '',
  });

  final List<PermissionHubItem> items;
  final bool loading;
  final String error;

  int get grantedCount => items.where((item) => item.granted).length;

  int get essentialCount => items.where((item) => item.essential).length;

  int get grantedEssentialCount =>
      items.where((item) => item.essential && item.granted).length;

  bool get essentialsReady => grantedEssentialCount == essentialCount;

  PermissionHubState copyWith({
    List<PermissionHubItem>? items,
    bool? loading,
    String? error,
  }) {
    return PermissionHubState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class PermissionHubItem {
  const PermissionHubItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.essential,
    required this.systemManaged,
    this.status,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool essential;
  final bool systemManaged;
  final PermissionStatusEntry? status;

  bool get granted => status?.granted == true;

  bool get opensSettings => systemManaged || status?.systemManaged == true;

  PermissionHubItem copyWith({PermissionStatusEntry? status}) {
    return PermissionHubItem(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      essential: essential,
      systemManaged: systemManaged,
      status: status ?? this.status,
    );
  }

  static List<PermissionHubItem> defaults() => const [
    PermissionHubItem(
      id: 'microphone',
      title: 'Microphone',
      subtitle: 'Required for Hey Alter and live voice commands.',
      icon: LucideIcons.mic,
      essential: true,
      systemManaged: false,
    ),
    PermissionHubItem(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Required for the foreground wake service status.',
      icon: LucideIcons.bell,
      essential: true,
      systemManaged: false,
    ),
    PermissionHubItem(
      id: 'accessibility',
      title: 'Phone Control',
      subtitle:
          'Required to read visible screens, tap, type, scroll, and navigate.',
      icon: LucideIcons.accessibility,
      essential: true,
      systemManaged: true,
    ),
    PermissionHubItem(
      id: 'notification_listener',
      title: 'Notification Access',
      subtitle:
          'Required for proactive chat/app monitoring from notifications.',
      icon: LucideIcons.bell_ring,
      essential: true,
      systemManaged: true,
    ),
    PermissionHubItem(
      id: 'device_admin',
      title: 'Device Admin',
      subtitle: 'Required for managed-device and AVD Device Owner testing.',
      icon: LucideIcons.shield,
      essential: true,
      systemManaged: true,
    ),
    PermissionHubItem(
      id: 'camera',
      title: 'Camera',
      subtitle:
          'Required for ALTER Lens, QR/payment checks, and visual context.',
      icon: LucideIcons.camera,
      essential: false,
      systemManaged: false,
    ),
    PermissionHubItem(
      id: 'contacts',
      title: 'Contacts',
      subtitle: 'Required to call or message people by name.',
      icon: LucideIcons.users,
      essential: false,
      systemManaged: false,
    ),
  ];
}
