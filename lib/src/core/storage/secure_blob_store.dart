import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key/value blob storage. Implementations encrypt at rest where the
/// platform supports it and degrade gracefully otherwise, so the local memory
/// layer keeps working on any device. This is the seam a future local vector DB
/// (e.g. ObjectBox) can slot behind without touching callers.
abstract class SecureBlobStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

const _encPrefix = 'enc1:';

/// Pure AES-256-GCM codec for the encrypted blob store. Separated from the
/// keystore glue so the security-critical path is unit-testable without the
/// platform. Packed layout: nonce(12) | mac(16) | ciphertext, base64, tagged.
class MemoryCipher {
  MemoryCipher(this.key);

  final SecretKey key;
  final AesGcm _algo = AesGcm.with256bits();

  static const tag = _encPrefix;

  static SecretKey keyFromBytes(List<int> bytes) => SecretKey(bytes);

  Future<String> seal(String plaintext) async {
    final box = await _algo.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: _algo.newNonce(),
    );
    final packed = <int>[...box.nonce, ...box.mac.bytes, ...box.cipherText];
    return '$tag${base64Encode(packed)}';
  }

  Future<String> open(String sealed) async {
    final packed = base64Decode(sealed.substring(tag.length));
    final clear = await _algo.decrypt(
      SecretBox(
        packed.sublist(28),
        nonce: packed.sublist(0, 12),
        mac: Mac(packed.sublist(12, 28)),
      ),
      secretKey: key,
    );
    return utf8.decode(clear);
  }
}

/// AES-256-GCM encrypted blob store. The data key lives in the platform
/// keystore (via flutter_secure_storage); the ciphertext lives in
/// SharedPreferences tagged with [_encPrefix]. Legacy plaintext values are
/// transparently re-encrypted the first time they're read. Any failure (e.g. a
/// platform without secure storage) falls back to plaintext so persistence
/// never breaks — privacy degrades, the app does not.
class EncryptedBlobStore implements SecureBlobStore {
  EncryptedBlobStore(this._prefs, this._secure);

  /// Builds the store, sharing a single SharedPreferences instance.
  static Future<EncryptedBlobStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return EncryptedBlobStore(prefs, const FlutterSecureStorage());
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  static const _keyId = 'alter.mem.aeskey.v1';
  MemoryCipher? _cipher;

  Future<MemoryCipher> _cipherFor() async {
    final cached = _cipher;
    if (cached != null) return cached;
    var b64 = await _secure.read(key: _keyId);
    if (b64 == null || b64.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      b64 = base64Encode(bytes);
      await _secure.write(key: _keyId, value: b64);
    }
    final cipher = MemoryCipher(MemoryCipher.keyFromBytes(base64Decode(b64)));
    _cipher = cipher;
    return cipher;
  }

  @override
  Future<String?> read(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    if (!raw.startsWith(_encPrefix)) {
      // Legacy plaintext written before encryption — migrate it now.
      try {
        await write(key, raw);
      } catch (_) {}
      return raw;
    }
    try {
      return await (await _cipherFor()).open(raw);
    } catch (_) {
      return null; // unreadable → treat as empty rather than crash
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _prefs.setString(key, await (await _cipherFor()).seal(value));
    } catch (_) {
      // Secure storage / crypto unavailable: keep working, unencrypted.
      await _prefs.setString(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}
