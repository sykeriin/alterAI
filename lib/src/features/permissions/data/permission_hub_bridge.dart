import 'package:flutter/services.dart';

class PermissionStatusEntry {
  const PermissionStatusEntry({
    required this.granted,
    required this.systemManaged,
  });

  factory PermissionStatusEntry.fromMap(Object? raw) {
    final map = raw is Map<Object?, Object?> ? raw : const <Object?, Object?>{};
    return PermissionStatusEntry(
      granted: map['granted'] == true,
      systemManaged: map['systemManaged'] == true,
    );
  }

  final bool granted;
  final bool systemManaged;
}

class PermissionHubBridge {
  static const _channel = MethodChannel('alter.ai/permissions');

  Future<Map<String, PermissionStatusEntry>> getStatuses() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getPermissionStatuses');
      return _parseStatuses(raw);
    } on MissingPluginException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, PermissionStatusEntry>> request(String permission) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('requestPermission', {
        'permission': permission,
      });
      return _parseStatuses(raw);
    } on MissingPluginException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, PermissionStatusEntry>> openAppSettings() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('openAppSettings');
      return _parseStatuses(raw);
    } on MissingPluginException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Map<String, PermissionStatusEntry> _parseStatuses(Object? raw) {
    if (raw is! Map<Object?, Object?>) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): PermissionStatusEntry.fromMap(entry.value),
    };
  }
}
