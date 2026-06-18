import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gatewayPrefKey = 'alter.backend.gateway_url';
const _compileTimeGatewayUrl = String.fromEnvironment('ALTER_API_GATEWAY_URL');

final backendConfigProvider =
    AsyncNotifierProvider<BackendConfigController, BackendConfig>(
      BackendConfigController.new,
    );

class BackendConfig {
  const BackendConfig({required this.gatewayUrl});

  final String gatewayUrl;

  bool get hasGateway => gatewayUrl.trim().isNotEmpty;
}

enum BackendService {
  voiceGateway(8070),
  cloneCouncil(8080),
  futureSimulation(8090),
  memorySystem(8100),
  opportunityEngine(8110),
  socialGraph(8120),
  alterLens(8130),
  reputationEngine(8140),
  officeKit(8150);

  const BackendService(this.port);

  final int port;
}

class BackendConfigController extends AsyncNotifier<BackendConfig> {
  @override
  Future<BackendConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_gatewayPrefKey)?.trim() ?? '';
    return BackendConfig(
      gatewayUrl: saved.isNotEmpty ? saved : _defaultGatewayUrl(),
    );
  }

  Future<void> setGatewayUrl(String value) async {
    final normalized = _normalize(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gatewayPrefKey, normalized);
    state = AsyncValue.data(BackendConfig(gatewayUrl: normalized));
  }

  Future<void> resetGatewayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gatewayPrefKey);
    state = AsyncValue.data(BackendConfig(gatewayUrl: _defaultGatewayUrl()));
  }

  String _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final withScheme = trimmed.startsWith(RegExp(r'https?://'))
        ? trimmed
        : 'http://$trimmed';
    return withScheme.replaceFirst(RegExp(r'/$'), '');
  }

  String _defaultGatewayUrl() {
    if (_compileTimeGatewayUrl.trim().isNotEmpty) {
      return _compileTimeGatewayUrl.trim().replaceFirst(RegExp(r'/$'), '');
    }
    return '';
  }
}
