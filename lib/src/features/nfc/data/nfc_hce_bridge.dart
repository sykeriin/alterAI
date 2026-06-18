import 'package:flutter/services.dart';

/// Talks to the native Host Card Emulation service so this phone can broadcast
/// the user's ALTER profile as a Type-4 NDEF tag — another phone reads it with
/// a normal NDEF scan on tap. Android-only; no-ops elsewhere.
class NfcHceBridge {
  const NfcHceBridge();

  static const _channel = MethodChannel('alter.ai/nfc_hce');

  Future<bool> isSupported() async {
    try {
      return (await _channel.invokeMethod<bool>('isHceSupported')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start broadcasting [json] (a profile payload) under [mimeType] over HCE.
  Future<bool> enableSharing({
    required String mimeType,
    required String json,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('enableSharing', {
        'mimeType': mimeType,
        'json': json,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableSharing() async {
    try {
      await _channel.invokeMethod<void>('disableSharing');
    } catch (_) {}
  }
}
