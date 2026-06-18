import 'package:flutter/services.dart';

class DeviceOwnerBridge {
  static const _channel = MethodChannel('alter.ai/device_owner');

  Future<bool> isDeviceOwner() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceOwner');
      return result == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDeviceAdminActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceAdminActive');
      return result == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getDeviceOwnerComponent() async {
    try {
      return await _channel.invokeMethod<String>('getDeviceOwnerComponent');
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Opens the system dialog to enable ALTER as device admin (not device owner).
  Future<void> requestDeviceAdminSetup() async {
    try {
      await _channel.invokeMethod<void>('requestDeviceAdminSetup');
    } on MissingPluginException {
      return;
    }
  }

  /// @deprecated Use [requestDeviceAdminSetup].
  Future<void> requestDeviceOwnerSetup() => requestDeviceAdminSetup();

  Future<void> whitelistAccessibilityService() async {
    try {
      await _channel.invokeMethod<void>('whitelistAccessibilityService');
    } on MissingPluginException {
      return;
    }
  }
}
