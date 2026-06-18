import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class PinIncorrectException implements Exception {
  PinIncorrectException([this.message = 'Incorrect PIN']);
  final String message;
  @override
  String toString() => message;
}

class DatabaseKeyService {
  DatabaseKeyService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _saltKey = 'alter_db_salt';
  static const _verifierKey = 'alter_pin_verifier';
  static const _userIdKey = 'alter_local_user_id';
  static const _biometricEnabledKey = 'alter_biometric_enabled';
  static const _wrappedKeyKey = 'alter_biometric_wrapped_key';

  final FlutterSecureStorage _storage;
  Uint8List? _sessionKey;

  Uint8List? get sessionKey => _sessionKey;

  Future<bool> isPinConfigured() async {
    final verifier = await _storage.read(key: _verifierKey);
    return verifier != null && verifier.isNotEmpty;
  }

  Future<bool> isBiometricEnabled() async {
    return (await _storage.read(key: _biometricEnabledKey)) == 'true';
  }

  Future<String?> localUserId() => _storage.read(key: _userIdKey);

  Future<void> setupPin(
    String pin, {
    bool enableBiometric = false,
    String? userId,
  }) async {
    _validatePin(pin);
    final salt = _randomBytes(32);
    final key = _deriveKey(pin, salt);
    final verifier = _verifierHash(pin, salt);

    final resolvedUserId = userId ?? const Uuid().v4();
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _verifierKey, value: base64Encode(verifier));
    await _storage.write(key: _userIdKey, value: resolvedUserId);
    await _storage.write(
      key: _biometricEnabledKey,
      value: enableBiometric ? 'true' : 'false',
    );

    if (enableBiometric) {
      await _storage.write(
        key: _wrappedKeyKey,
        value: base64Encode(key),
      );
    } else {
      await _storage.delete(key: _wrappedKeyKey);
    }

    _sessionKey = key;
  }

  Future<Uint8List> unlockWithPin(String pin) async {
    _validatePin(pin);
    final saltB64 = await _storage.read(key: _saltKey);
    final verifierB64 = await _storage.read(key: _verifierKey);
    if (saltB64 == null || verifierB64 == null) {
      throw PinIncorrectException('PIN not configured');
    }

    final salt = base64Decode(saltB64);
    final expected = base64Decode(verifierB64);
    final actual = _verifierHash(pin, salt);
    if (!listEquals(expected, actual)) {
      throw PinIncorrectException();
    }

    final key = _deriveKey(pin, salt);
    _sessionKey = key;
    return key;
  }

  Future<Uint8List?> unlockWithBiometric() async {
    if (!await isBiometricEnabled()) return null;
    final wrapped = await _storage.read(key: _wrappedKeyKey);
    if (wrapped == null || wrapped.isEmpty) return null;
    final key = base64Decode(wrapped);
    _sessionKey = Uint8List.fromList(key);
    return _sessionKey;
  }

  Future<void> enableBiometricQuickUnlock(Uint8List dbKey) async {
    await _storage.write(
      key: _wrappedKeyKey,
      value: base64Encode(dbKey),
    );
    await _storage.write(key: _biometricEnabledKey, value: 'true');
  }

  Future<void> lock() async {
    _sessionKey = null;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    await unlockWithPin(oldPin);
    final salt = _randomBytes(32);
    final key = _deriveKey(newPin, salt);
    final verifier = _verifierHash(newPin, salt);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _verifierKey, value: base64Encode(verifier));
    if (await isBiometricEnabled()) {
      await _storage.write(key: _wrappedKeyKey, value: base64Encode(key));
    }
    _sessionKey = key;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be 4–8 digits');
    }
  }

  Uint8List _deriveKey(String pin, Uint8List salt) {
    var digest = sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
    for (var i = 0; i < 100000; i++) {
      digest = sha256.convert([...digest, ...salt, i]).bytes;
    }
    return Uint8List.fromList(digest);
  }

  List<int> _verifierHash(String pin, Uint8List salt) {
    return sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
  }

  Uint8List _randomBytes(int length) {
    final seed = utf8.encode('${DateTime.now().microsecondsSinceEpoch}-${const Uuid().v4()}');
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = sha256.convert([...seed, i]).bytes[i % 32];
    }
    return out;
  }
}

String databasePasswordFromKey(Uint8List key) => base64Encode(key);
