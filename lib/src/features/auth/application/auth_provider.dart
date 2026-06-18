import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/database/alter_database.dart';
import '../../../core/database/database_key_service.dart';
import '../../../core/database/database_providers.dart';

import 'supabase_auth_service.dart';

enum LocalAuthState {
  /// Resolving whether a local PIN vault exists (avoid redirect races on launch).
  bootstrapping,
  locked,
  unlocked,
  pinNotConfigured,
}

/// Minimal user identity for screens that previously used Supabase `User`.
class AlterAuthUser {
  const AlterAuthUser({required this.id});
  final String id;
}

class LocalAuthService extends Notifier<LocalAuthState> {
  String? _localUserId;
  bool _bootstrapStarted = false;

  @override
  LocalAuthState build() {
    _bootstrap();
    return LocalAuthState.bootstrapping;
  }

  DatabaseKeyService get _keyService => ref.read(databaseKeyServiceProvider);
  AlterDatabase get _db => ref.read(alterDatabaseProvider);

  String? get localUserId =>
      state == LocalAuthState.unlocked ? _localUserId : null;

  Future<void> _bootstrap() async {
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    final configured = await _keyService.isPinConfigured();
    state =
        configured ? LocalAuthState.locked : LocalAuthState.pinNotConfigured;
  }

  Future<void> setupAndUnlock(
    String pin, {
    bool enableBiometric = false,
    String? linkedUserId,
  }) async {
    await _keyService.setupPin(
      pin,
      enableBiometric: enableBiometric,
      userId: linkedUserId,
    );
    final key = _keyService.sessionKey;
    if (key == null) {
      throw StateError('PIN setup did not produce a session key');
    }
    if (!_db.isOpen) {
      await _db.open(key);
    }
    final userId = await _keyService.localUserId();
    if (userId != null) {
      await _db.ensureLocalSession(userId: userId);
      _localUserId = userId;
    }
    state = LocalAuthState.unlocked;
  }

  Future<void> unlockWithPin(String pin) async {
    final key = await _keyService.unlockWithPin(pin);
    if (!_db.isOpen) {
      await _db.open(key);
    }
    _localUserId = await _keyService.localUserId();
    state = LocalAuthState.unlocked;
  }

  Future<void> unlockWithBiometric() async {
    if (!await _keyService.isBiometricEnabled()) {
      throw StateError('Biometric unlock is not enabled');
    }
    final localAuth = LocalAuthentication();
    final authenticated = await localAuth.authenticate(
      localizedReason: 'Unlock Alter',
      options: const AuthenticationOptions(biometricOnly: true),
    );
    if (!authenticated) return;

    final key = await _keyService.unlockWithBiometric();
    if (key == null) {
      throw StateError('Biometric unlock failed');
    }
    if (!_db.isOpen) {
      await _db.open(key);
    }
    _localUserId = await _keyService.localUserId();
    state = LocalAuthState.unlocked;
  }

  Future<void> lock() async {
    if (_db.isOpen) {
      await _db.close();
    }
    await _keyService.lock();
    _localUserId = null;
    if (await _keyService.isPinConfigured()) {
      state = LocalAuthState.locked;
    } else {
      state = LocalAuthState.pinNotConfigured;
    }
  }

  Future<bool> canUseBiometricUnlock() async {
    if (!await _keyService.isBiometricEnabled()) return false;
    final localAuth = LocalAuthentication();
    return await localAuth.canCheckBiometrics;
  }
}

final localAuthServiceProvider =
    NotifierProvider<LocalAuthService, LocalAuthState>(LocalAuthService.new);

final isDbUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(localAuthServiceProvider) == LocalAuthState.unlocked;
});

final localUserIdProvider = Provider<String?>((ref) {
  ref.watch(localAuthServiceProvider);
  return ref.read(localAuthServiceProvider.notifier).localUserId;
});

final authStateStreamProvider = StreamProvider<LocalAuthState>((ref) {
  final controller = StreamController<LocalAuthState>.broadcast();
  controller.add(ref.read(localAuthServiceProvider));
  ref.listen(localAuthServiceProvider, (_, next) => controller.add(next));
  ref.onDispose(controller.close);
  return controller.stream;
});

final currentUserProvider = Provider<AlterAuthUser?>((ref) {
  final id = ref.watch(localUserIdProvider);
  return id != null ? AlterAuthUser(id: id) : null;
});

/// Settings and legacy screens call [lock] (or [signOut]) to secure the vault.
class AuthServiceFacade {
  AuthServiceFacade(this._auth, this._supabase);

  final LocalAuthService _auth;
  final SupabaseAuthService _supabase;

  Future<void> lock() => _auth.lock();

  Future<void> signOut() async {
    await _supabase.signOut();
    await _auth.lock();
  }
}

final authServiceProvider = Provider<AuthServiceFacade>((ref) {
  return AuthServiceFacade(
    ref.read(localAuthServiceProvider.notifier),
    ref.read(supabaseAuthProvider.notifier),
  );
});

final localUserIdFutureProvider = FutureProvider<String?>((ref) async {
  final syncId = ref.watch(localUserIdProvider);
  if (syncId != null) return syncId;
  final db = ref.read(alterDatabaseProvider);
  if (!db.isOpen) return null;
  return db.readLocalUserId();
});

// Plain ChangeNotifier used as GoRouter's refreshListenable.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen(localAuthServiceProvider, (_, __) => notifyListeners());
  }
}
