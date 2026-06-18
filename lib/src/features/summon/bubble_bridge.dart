import 'package:flutter/services.dart';

/// Controls the native floating-bubble overlay that summons ALTER from any
/// screen. Android-only; methods fail soft elsewhere.
class BubbleBridge {
  const BubbleBridge();

  static const _channel = MethodChannel('alter.ai/bubble');

  Future<bool> isOverlayGranted() => _bool('isOverlayGranted');

  Future<bool> isRunning() => _bool('isRunning');

  /// Opens the system "display over other apps" screen; returns whether the
  /// permission is granted afterwards (usually false until the user toggles it).
  Future<bool> requestOverlay() => _bool('requestOverlay');

  /// Starts the bubble. Returns false if the overlay permission isn't granted.
  Future<bool> start() => _bool('start');

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<bool> _bool(String method) async {
    try {
      return (await _channel.invokeMethod<bool>(method)) ?? false;
    } catch (_) {
      return false;
    }
  }
}
