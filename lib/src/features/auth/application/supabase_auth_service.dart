import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/alter_supabase_config.dart';
import '../../onboarding/application/onboarding_draft_provider.dart';
import '../../profile/domain/user_profile.dart';
import '../data/supabase_profile_repository.dart';

class SupabaseAuthState {
  const SupabaseAuthState({
    required this.initialized,
    required this.configured,
    this.user,
    this.session,
  });

  const SupabaseAuthState.unconfigured()
      : initialized = true,
        configured = false,
        user = null,
        session = null;

  final bool initialized;
  final bool configured;
  final User? user;
  final Session? session;

  bool get isSignedIn => user != null && session != null;

  String? get userId => user?.id;

  SupabaseAuthState copyWith({
    bool? initialized,
    bool? configured,
    User? user,
    Session? session,
    bool clearUser = false,
  }) {
    return SupabaseAuthState(
      initialized: initialized ?? this.initialized,
      configured: configured ?? this.configured,
      user: clearUser ? null : (user ?? this.user),
      session: clearUser ? null : (session ?? this.session),
    );
  }
}

class SupabaseAuthService extends Notifier<SupabaseAuthState> {
  StreamSubscription<AuthState>? _subscription;

  SupabaseClient? get _client {
    if (!AlterSupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  SupabaseProfileRepository? get _profiles {
    final client = _client;
    return client == null ? null : SupabaseProfileRepository(client);
  }

  @override
  SupabaseAuthState build() {
    ref.onDispose(() => _subscription?.cancel());

    if (!AlterSupabaseConfig.isConfigured) {
      return const SupabaseAuthState.unconfigured();
    }

    final client = Supabase.instance.client;
    _subscription = client.auth.onAuthStateChange.listen((event) {
      state = _fromSession(event.session);
    });

    return _fromSession(client.auth.currentSession);
  }

  SupabaseAuthState _fromSession(Session? session) {
    return SupabaseAuthState(
      initialized: true,
      configured: true,
      user: session?.user,
      session: session,
    );
  }

  Future<UserProfile?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('Sign-in failed.');
    }

    await _profiles?.ensureProfileRow(user.id, email: user.email);
    return _profiles?.fetchProfile(user.id);
  }

  Future<UserProfile?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw AuthException('Sign-up failed.');
    }

    if (response.session == null) {
      throw AuthException(
        'Check your email to confirm your account, then sign in.',
      );
    }

    await _profiles?.ensureProfileRow(user.id, email: user.email);
    return _profiles?.fetchProfile(user.id);
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
    state = state.copyWith(clearUser: true);
  }

  void applyProfileToOnboardingDraft(UserProfile? profile) {
    if (profile == null) return;
    ref.read(onboardingDraftProvider.notifier).update(
          OnboardingDraft.fromProfile(profile),
        );
  }
}

final supabaseAuthProvider =
    NotifierProvider<SupabaseAuthService, SupabaseAuthState>(
  SupabaseAuthService.new,
);

final supabaseSignedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(supabaseAuthProvider);
  if (!auth.configured) return true;
  return auth.isSignedIn;
});

String supabaseAuthErrorMessage(Object error) {
  if (_isNetworkError(error)) {
    return 'No internet connection. Turn on Wi‑Fi or mobile data, then try again.';
  }
  if (error is AuthException) {
    final msg = error.message.trim();
    if (msg.toLowerCase().contains('invalid api key')) {
      return 'Invalid API key. Use the Publishable key (sb_publishable_...) '
          'or legacy anon key (eyJ...) from Supabase → Settings → API Keys. '
          'Do not use sbp_ CLI tokens.';
    }
    if (msg.isNotEmpty) return msg;
  }
  if (error is PostgrestException) {
    return error.message;
  }
  if (kDebugMode) return error.toString();
  return 'Authentication failed. Check your email and password.';
}

bool _isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  final raw = error.toString().toLowerCase();
  return raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection timed out') ||
      raw.contains('connection refused') ||
      raw.contains('no address associated with hostname');
}
