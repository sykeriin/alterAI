/// Supabase project config for auth and cloud profile sync.
///
/// Pass at build time (either works):
/// `flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...`
/// `flutter run --dart-define=SUPABASE_ANON_KEY=eyJ...`
library;

import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AlterSupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Legacy name kept for existing build scripts.
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Client-side API key for Supabase Flutter.
  static String get clientKey {
    final publishable = publishableKey.trim();
    if (publishable.isNotEmpty) return publishable;
    return anonKey.trim();
  }

  /// Non-null when [clientKey] is the wrong key type for the mobile app.
  static String? get misconfiguredKeyMessage {
    final key = clientKey;
    if (key.isEmpty || key == 'replace-me') return null;
    if (key.startsWith('sbp_')) {
      return 'Wrong key: sbp_ is a CLI access token, not an app API key. '
          'In Supabase Dashboard go to Settings → API Keys and copy the '
          'Publishable key (sb_publishable_...) or legacy anon key (eyJ...).';
    }
    if (key.startsWith('sbs_') || key.startsWith('sb_secret_')) {
      return 'Wrong key: secret keys must never be used in the mobile app. '
          'Use the Publishable or anon key from Settings → API Keys.';
    }
    return null;
  }

  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      url.trim() != 'https://your-project.supabase.co' &&
      clientKey.isNotEmpty &&
      clientKey != 'replace-me' &&
      misconfiguredKeyMessage == null;

  static bool get isEnabled => isConfigured;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: url,
      anonKey: clientKey,
    );
  }
}
