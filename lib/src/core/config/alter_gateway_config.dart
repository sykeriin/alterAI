import 'package:shared_preferences/shared_preferences.dart';

/// ALTER API Gateway URL resolution.
///
/// Priority: runtime Settings override → `--dart-define` → default Cloudflare.
class AlterGatewayConfig {
  AlterGatewayConfig._();

  static const String defaultUrl = '';

  static const String compileTimeUrl = String.fromEnvironment(
    'ALTER_API_GATEWAY_URL',
    defaultValue: '',
  );

  static const _prefsKey = 'alter_gateway_url';

  static String _runtimeOverride = '';

  /// Load persisted override from SharedPreferences (call before runApp).
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeOverride = prefs.getString(_prefsKey)?.trim() ?? '';
  }

  static Future<void> setRuntimeOverride(String url) async {
    _runtimeOverride = url.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_runtimeOverride.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _runtimeOverride);
    }
  }

  static String get runtimeOverride => _runtimeOverride;

  static bool get hasUserOverride => _runtimeOverride.isNotEmpty;

  static bool get isConfigured => normalizedBaseUrl.trim().isNotEmpty;

  static String get normalizedBaseUrl {
    final raw = _runtimeOverride.isNotEmpty
        ? _runtimeOverride
        : (compileTimeUrl.isNotEmpty ? compileTimeUrl : defaultUrl);
    return raw.replaceFirst(RegExp(r'/$'), '');
  }

  /// True when a non-empty gateway URL is configured (runtime, dart-define, or default).
  static bool get hasGatewayUrl => normalizedBaseUrl.trim().isNotEmpty;
}
