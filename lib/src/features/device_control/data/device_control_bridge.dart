import 'package:flutter/services.dart';

class DeviceControlResult {
  const DeviceControlResult({required this.ok, required this.message});

  factory DeviceControlResult.fromMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return const DeviceControlResult(ok: false, message: 'No result.');
    }
    return DeviceControlResult(
      ok: raw['ok'] == true,
      message: raw['message']?.toString() ?? '',
    );
  }

  final bool ok;
  final String message;
}

class DeviceAdminStatus {
  const DeviceAdminStatus({
    required this.ok,
    required this.message,
    required this.adminActive,
    required this.deviceOwner,
    required this.profileOwner,
  });

  factory DeviceAdminStatus.fromMap(Object? raw) {
    final map = raw is Map<Object?, Object?> ? raw : const <Object?, Object?>{};
    return DeviceAdminStatus(
      ok: map['ok'] == true,
      message: map['message']?.toString() ?? 'No admin status returned.',
      adminActive: map['adminActive'] == true,
      deviceOwner: map['deviceOwner'] == true,
      profileOwner: map['profileOwner'] == true,
    );
  }

  final bool ok;
  final String message;
  final bool adminActive;
  final bool deviceOwner;
  final bool profileOwner;

  bool get managed => adminActive || deviceOwner || profileOwner;
}

class VisibleNode {
  const VisibleNode({
    required this.nodeId,
    required this.text,
    required this.className,
    required this.viewId,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.bounds,
  });

  factory VisibleNode.fromMap(Object? raw) {
    final map = raw is Map<Object?, Object?> ? raw : const <Object?, Object?>{};
    return VisibleNode(
      nodeId: map['nodeId'] is num ? (map['nodeId'] as num).round() : -1,
      text: map['text']?.toString() ?? '',
      className: map['className']?.toString() ?? '',
      viewId: map['viewId']?.toString() ?? '',
      clickable: map['clickable'] == true,
      editable: map['editable'] == true,
      scrollable: map['scrollable'] == true,
      bounds: Map<Object?, Object?>.from(
        map['bounds'] as Map<Object?, Object?>? ?? const {},
      ),
    );
  }

  final int nodeId;
  final String text;
  final String className;
  final String viewId;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final Map<Object?, Object?> bounds;

  double get centerX => (_number('left') + _number('right')) / 2;

  double get centerY => (_number('top') + _number('bottom')) / 2;

  double _number(String key) {
    final value = bounds[key];
    return value is num ? value.toDouble() : 0;
  }
}

class DeviceScreenSnapshot {
  const DeviceScreenSnapshot({
    required this.ok,
    required this.message,
    required this.packageName,
    required this.className,
    required this.text,
    required this.nodes,
  });

  factory DeviceScreenSnapshot.fromMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return const DeviceScreenSnapshot(
        ok: false,
        message: 'No screen snapshot returned.',
        packageName: '',
        className: '',
        text: '',
        nodes: [],
      );
    }

    final rawNodes = raw['nodes'];
    final nodes = rawNodes is List
        ? rawNodes.map(VisibleNode.fromMap).toList(growable: false)
        : const <VisibleNode>[];
    return DeviceScreenSnapshot(
      ok: raw['ok'] == true,
      message: raw['message']?.toString() ?? '',
      packageName: raw['packageName']?.toString() ?? '',
      className: raw['className']?.toString() ?? '',
      text: raw['text']?.toString() ?? '',
      nodes: nodes,
    );
  }

  final bool ok;
  final String message;
  final String packageName;
  final String className;
  final String text;
  final List<VisibleNode> nodes;
}

class DeviceControlBridge {
  static const _channel = MethodChannel('alter.ai/device_control');

  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<DeviceControlResult> openAccessibilitySettings() async {
    return _result('openAccessibilitySettings');
  }

  Future<DeviceControlResult> openApp({
    String appName = '',
    String packageName = '',
  }) async {
    return _result('openApp', {'appName': appName, 'packageName': packageName});
  }

  Future<DeviceControlResult> openSettings(String screen) async {
    return _result('openSettings', {'screen': screen});
  }

  Future<DeviceControlResult> openDialer(String number) async {
    return _result('openDialer', {'number': number});
  }

  Future<DeviceControlResult> openBrowserSearch(String query) async {
    return _result('openBrowserSearch', {'query': query});
  }

  Future<DeviceControlResult> openSmsDraft({
    required String number,
    required String text,
  }) async {
    return _result('openSmsDraft', {'number': number, 'text': text});
  }

  Future<DeviceAdminStatus> getDeviceAdminStatus() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getDeviceAdminStatus');
      return DeviceAdminStatus.fromMap(raw);
    } on MissingPluginException {
      return const DeviceAdminStatus(
        ok: false,
        message: 'Device Admin is only available on Android.',
        adminActive: false,
        deviceOwner: false,
        profileOwner: false,
      );
    } catch (error) {
      return DeviceAdminStatus(
        ok: false,
        message: error.toString(),
        adminActive: false,
        deviceOwner: false,
        profileOwner: false,
      );
    }
  }

  Future<DeviceControlResult> openDeviceAdmin() async {
    return _result('openDeviceAdmin');
  }

  Future<DeviceControlResult> lockDevice() async {
    return _result('lockDevice');
  }

  Future<DeviceControlResult> globalAction(String action) async {
    return accessibilityAction(action);
  }

  Future<DeviceControlResult> tap({
    required double x,
    required double y,
  }) async {
    return accessibilityAction('tap', {'x': x, 'y': y});
  }

  Future<DeviceControlResult> swipe({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    int durationMs = 420,
  }) async {
    return accessibilityAction('swipe', {
      'startX': startX,
      'startY': startY,
      'endX': endX,
      'endY': endY,
      'durationMs': durationMs,
    });
  }

  Future<DeviceControlResult> clickText(String text) async {
    return accessibilityAction('click_text', {'text': text});
  }

  Future<DeviceControlResult> typeText(String text) async {
    return accessibilityAction('type_text', {'text': text});
  }

  Future<DeviceControlResult> scroll(String direction) async {
    return accessibilityAction('scroll', {'direction': direction});
  }

  Future<DeviceScreenSnapshot> readScreen() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('readScreen');
      return DeviceScreenSnapshot.fromMap(raw);
    } on MissingPluginException {
      return const DeviceScreenSnapshot(
        ok: false,
        message: 'Native device control is only available on Android.',
        packageName: '',
        className: '',
        text: '',
        nodes: [],
      );
    } catch (error) {
      return DeviceScreenSnapshot(
        ok: false,
        message: error.toString(),
        packageName: '',
        className: '',
        text: '',
        nodes: const [],
      );
    }
  }

  Future<DeviceControlResult> accessibilityAction(
    String action, [
    Map<String, Object?> args = const {},
  ]) async {
    return _result('executeAccessibilityAction', {'action': action, ...args});
  }

  Future<DeviceControlResult> _result(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      final raw = await _channel.invokeMethod<Object?>(method, args);
      return DeviceControlResult.fromMap(raw);
    } on MissingPluginException {
      return const DeviceControlResult(
        ok: false,
        message: 'Native device control is only available on Android.',
      );
    } catch (error) {
      return DeviceControlResult(ok: false, message: error.toString());
    }
  }
}
