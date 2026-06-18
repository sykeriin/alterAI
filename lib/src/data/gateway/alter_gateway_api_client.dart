import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/alter_gateway_config.dart';
import '../../core/errors/alter_service_exception.dart';

class AlterGatewayApiClient {
  AlterGatewayApiClient({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = (baseUrl ?? AlterGatewayConfig.normalizedBaseUrl),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<GatewayHealthSnapshot> fetchHealth() async {
    final body = await _getJson('/v1/system/health');
    final services = (body['services'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => GatewayServiceHealth(
            name: row['name']?.toString() ?? 'unknown',
            status: row['status']?.toString() ?? 'unknown',
            latencyMs: row['latency_ms'] is num
                ? (row['latency_ms'] as num).round()
                : null,
          ),
        )
        .toList(growable: false);
    return GatewayHealthSnapshot(
      status: body['status']?.toString() ?? 'unknown',
      services: services,
    );
  }

  Future<MultilingualCatalog> fetchLanguages() async {
    final body = await _getJson('/v1/multilingual/languages');
    return MultilingualCatalog.fromJson(body);
  }

  Future<UserSettingsSnapshot> fetchUserSettings({required String userId}) async {
    final body = await _getJson('/v1/user/settings?user_id=$userId');
    return UserSettingsSnapshot.fromJson(body);
  }

  Future<UserSettingsSnapshot> patchUserSettings({
    required String userId,
    List<String>? languages,
    String? role,
    Map<String, bool>? permissions,
  }) async {
    final payload = <String, Object>{};
    if (languages != null) payload['languages'] = languages;
    if (role != null) payload['role'] = role;
    if (permissions != null) payload['permissions'] = permissions;
    final body = await _patchJson('/v1/user/settings?user_id=$userId', payload);
    return UserSettingsSnapshot.fromJson(body);
  }

  Future<IntegrationsSnapshot> fetchIntegrations({required String userId}) async {
    final body = await _getJson('/v1/integrations?user_id=$userId');
    return IntegrationsSnapshot.fromJson(body);
  }

  Future<ConsentLedgerSnapshot> fetchConsentLedger({required String userId}) async {
    final body = await _getJson('/v1/security/consent-ledger?user_id=$userId');
    return ConsentLedgerSnapshot.fromJson(body);
  }

  Future<PrivacyExportSnapshot> exportPrivacy({required String userId}) async {
    final body = await _getJson('/v1/privacy/export?user_id=$userId');
    return PrivacyExportSnapshot.fromJson(body);
  }

  Future<AgentPlanSnapshot> planAgent({
    required String goal,
    String? userId,
    Map<String, Object>? deviceState,
    List<String>? allowedTools,
  }) async {
    final payload = <String, Object>{
      'goal': goal,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (deviceState != null) 'device_state': deviceState,
      if (allowedTools != null) 'allowed_tools': allowedTools,
    };
    final body = await _postJson('/v1/agent/plan', payload);
    return AgentPlanSnapshot.fromJson(body);
  }

  Future<List<GatewayRoute>> fetchRoutes() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/gateway/routes'),
      headers: const {'Accept': 'application/json'},
    );
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlterServiceException(
        'Gateway HTTP ${response.statusCode}',
        kind: _gatewayKindForStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    if (body is! List<dynamic>) return const [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(GatewayRoute.fromJson)
        .toList(growable: false);
  }

  Future<ConsentGrant> recordConsent({
    required String userId,
    required String source,
    required bool granted,
    String accessLevel = 'metadata',
    int retentionDays = 30,
    String reason = '',
  }) async {
    final body = await _postJson('/v1/security/consent', <String, Object>{
      'user_id': userId,
      'source': source,
      'access_level': accessLevel,
      'granted': granted,
      'retention_days': retentionDays,
      'reason': reason,
    });
    return ConsentGrant.fromJson(body);
  }

  Future<PrivacyDeleteResult> deletePrivacy({
    required String userId,
    List<String> scopes = const <String>['memory', 'settings', 'integrations'],
    bool confirm = true,
  }) async {
    final body = await _postJson('/v1/privacy/delete', <String, Object>{
      'user_id': userId,
      'scopes': scopes,
      'confirm': confirm,
    });
    return PrivacyDeleteResult.fromJson(body);
  }

  Future<DataIngestionResult> ingestData({
    required String userId,
    required String source,
    required List<Map<String, Object>> items,
    String importMode = 'manual_import',
    bool metadataOnly = true,
  }) async {
    final body = await _postJson('/v1/data-ingestion/import', <String, Object>{
      'user_id': userId,
      'source': source,
      'import_mode': importMode,
      'items': items,
      'metadata_only': metadataOnly,
    });
    return DataIngestionResult.fromJson(body);
  }

  Future<MultilingualTranslateResult> translate({
    required String text,
    String targetLanguageCode = 'hi-IN',
    String sourceLanguageCode = 'auto',
  }) async {
    final body = await _postJson('/v1/multilingual/translate', <String, Object>{
      'text': text,
      'target_language_code': targetLanguageCode,
      'source_language_code': sourceLanguageCode,
    });
    return MultilingualTranslateResult.fromJson(body);
  }

  Future<LanguageDetectResult> detectLanguage(String text) async {
    final body = await _postJson('/v1/multilingual/detect-language', <String, Object>{
      'text': text,
    });
    return LanguageDetectResult.fromJson(body);
  }

  Future<MultilingualChatResult> multilingualChat({
    required List<Map<String, String>> messages,
    String targetLanguageCode = 'en-IN',
  }) async {
    final body = await _postJson('/v1/multilingual/chat', <String, Object>{
      'messages': messages,
      'target_language_code': targetLanguageCode,
    });
    return MultilingualChatResult.fromJson(body);
  }

  Future<List<WebResearchHit>> researchWeb({
    required String query,
    int limit = 5,
  }) async {
    final body = await _postJson('/v1/web/research', <String, Object>{
      'query': query,
      'limit': limit,
    });
    return (body['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WebResearchHit.fromJson)
        .toList(growable: false);
  }

  Future<WebPageSnapshot> fetchPage({required String url}) async {
    final body = await _postJson('/v1/web/fetch', <String, Object>{'url': url});
    return WebPageSnapshot.fromJson(body);
  }

  Future<List<MarketplaceListing>> searchMarketplace({
    required String query,
    required String platform,
    int limit = 5,
  }) async {
    final body = await _postJson('/v1/web/marketplace', <String, Object>{
      'query': query,
      'platform': platform,
      'limit': limit,
    });
    return (body['listings'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MarketplaceListing.fromJson)
        .toList(growable: false);
  }

  Future<List<OpportunityHit>> searchOpportunities({
    required String query,
    int limit = 5,
  }) async {
    final body = await _postJson('/v1/opportunities/query', <String, Object>{
      'query': query,
      'limit': limit,
    });
    return (body['opportunities'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OpportunityHit.fromJson)
        .toList(growable: false);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: const {'Accept': 'application/json'},
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, Object> payload,
  ) async {
    final request = http.Request('PATCH', Uri.parse('$_baseUrl$path'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(payload);
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlterServiceException(
        'Gateway HTTP ${response.statusCode}',
        kind: _gatewayKindForStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const AlterServiceException(
        'Gateway invalid JSON',
        kind: ServiceErrorKind.parse,
      );
    }
    return body;
  }
}

ServiceErrorKind _gatewayKindForStatus(int code) {
  if (code == 401 || code == 403) return ServiceErrorKind.auth;
  if (code == 404) return ServiceErrorKind.notFound;
  if (code == 429) return ServiceErrorKind.quota;
  if (code >= 500) return ServiceErrorKind.server;
  return ServiceErrorKind.unknown;
}

class AlterGatewayApiException implements Exception {
  const AlterGatewayApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GatewayHealthSnapshot {
  const GatewayHealthSnapshot({required this.status, required this.services});
  final String status;
  final List<GatewayServiceHealth> services;
}

class GatewayServiceHealth {
  const GatewayServiceHealth({
    required this.name,
    required this.status,
    this.latencyMs,
  });
  final String name;
  final String status;
  final int? latencyMs;
}

class MultilingualCatalog {
  const MultilingualCatalog({
    required this.sarvamEnabled,
    required this.indianLanguages,
    required this.majorForeignLanguages,
  });

  factory MultilingualCatalog.fromJson(Map<String, dynamic> json) {
    return MultilingualCatalog(
      sarvamEnabled: json['sarvam_enabled'] == true,
      indianLanguages: _languageRows(json['indian_languages']),
      majorForeignLanguages: _languageRows(json['major_foreign_languages']),
    );
  }

  final bool sarvamEnabled;
  final List<GatewayLanguage> indianLanguages;
  final List<GatewayLanguage> majorForeignLanguages;

  List<GatewayLanguage> get allLanguages =>
      [...indianLanguages, ...majorForeignLanguages];

  static List<GatewayLanguage> _languageRows(Object? raw) {
    if (raw is! List<dynamic>) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(GatewayLanguage.fromJson)
        .toList(growable: false);
  }
}

class GatewayLanguage {
  const GatewayLanguage({
    required this.code,
    required this.name,
    required this.region,
  });

  factory GatewayLanguage.fromJson(Map<String, dynamic> json) {
    return GatewayLanguage(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
    );
  }

  final String code;
  final String name;
  final String region;
}

class UserSettingsSnapshot {
  const UserSettingsSnapshot({
    required this.userId,
    required this.languages,
    required this.role,
    required this.permissions,
    required this.themeLight,
  });

  factory UserSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];
    final permissions = permissionsRaw is Map
        ? permissionsRaw.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : const <String, bool>{};
    return UserSettingsSnapshot(
      userId: json['user_id']?.toString() ?? '',
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      role: json['role']?.toString() ?? '',
      permissions: permissions,
      themeLight: json['theme_light'] == true,
    );
  }

  final String userId;
  final List<String> languages;
  final String role;
  final Map<String, bool> permissions;
  final bool themeLight;
}

class IntegrationsSnapshot {
  const IntegrationsSnapshot({
    required this.userId,
    required this.platforms,
  });

  factory IntegrationsSnapshot.fromJson(Map<String, dynamic> json) {
    final rows = json['platforms'] as List<dynamic>? ?? const [];
    return IntegrationsSnapshot(
      userId: json['user_id']?.toString() ?? '',
      platforms: rows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => PlatformIntegration(
              id: row['id']?.toString() ?? '',
              name: row['name']?.toString() ?? '',
              connected: row['connected'] == true,
              status: row['status']?.toString() ?? 'disconnected',
            ),
          )
          .toList(growable: false),
    );
  }

  final String userId;
  final List<PlatformIntegration> platforms;
}

class PlatformIntegration {
  const PlatformIntegration({
    required this.id,
    required this.name,
    required this.connected,
    required this.status,
  });
  final String id;
  final String name;
  final bool connected;
  final String status;
}

class ConsentLedgerSnapshot {
  const ConsentLedgerSnapshot({
    required this.userId,
    required this.grants,
    required this.requiredForFullAssistant,
    required this.auditNote,
  });

  factory ConsentLedgerSnapshot.fromJson(Map<String, dynamic> json) {
    final grantsRaw = json['grants'] as List<dynamic>? ?? const [];
    return ConsentLedgerSnapshot(
      userId: json['user_id']?.toString() ?? '',
      grants: grantsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => ConsentGrant(
              source: row['source']?.toString() ?? '',
              accessLevel: row['access_level']?.toString() ?? '',
              granted: row['granted'] == true,
              retentionDays: row['retention_days'] is num
                  ? (row['retention_days'] as num).round()
                  : 0,
              reason: row['reason']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
      requiredForFullAssistant:
          (json['required_for_full_assistant'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      auditNote: json['audit_note']?.toString() ?? '',
    );
  }

  final String userId;
  final List<ConsentGrant> grants;
  final List<String> requiredForFullAssistant;
  final String auditNote;
}

class ConsentGrant {
  const ConsentGrant({
    required this.source,
    required this.accessLevel,
    required this.granted,
    required this.retentionDays,
    required this.reason,
  });

  factory ConsentGrant.fromJson(Map<String, dynamic> json) {
    return ConsentGrant(
      source: json['source']?.toString() ?? '',
      accessLevel: json['access_level']?.toString() ?? '',
      granted: json['granted'] == true,
      retentionDays: json['retention_days'] is num
          ? (json['retention_days'] as num).round()
          : 0,
      reason: json['reason']?.toString() ?? '',
    );
  }

  final String source;
  final String accessLevel;
  final bool granted;
  final int retentionDays;
  final String reason;
}

class PrivacyExportSnapshot {
  const PrivacyExportSnapshot({
    required this.exportId,
    required this.includedSections,
    required this.downloadReady,
    required this.summary,
  });

  factory PrivacyExportSnapshot.fromJson(Map<String, dynamic> json) {
    return PrivacyExportSnapshot(
      exportId: json['export_id']?.toString() ?? '',
      includedSections:
          (json['included_sections'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      downloadReady: json['download_ready'] == true,
      summary: json['summary'] is Map<String, dynamic>
          ? json['summary'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  final String exportId;
  final List<String> includedSections;
  final bool downloadReady;
  final Map<String, dynamic> summary;
}

class AgentPlanSnapshot {
  const AgentPlanSnapshot({
    required this.goal,
    required this.readyToExecute,
    required this.steps,
    required this.policyWarnings,
  });

  factory AgentPlanSnapshot.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['steps'] as List<dynamic>? ?? const [];
    return AgentPlanSnapshot(
      goal: json['goal']?.toString() ?? '',
      readyToExecute: json['ready_to_execute'] == true,
      steps: stepsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => AgentPlanStep(
              title: row['title']?.toString() ?? '',
              toolName: row['tool_name']?.toString() ?? '',
              rationale: row['rationale']?.toString() ?? '',
              status: row['status']?.toString() ?? 'planned',
            ),
          )
          .toList(growable: false),
      policyWarnings: (json['policy_warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final String goal;
  final bool readyToExecute;
  final List<AgentPlanStep> steps;
  final List<String> policyWarnings;
}

class AgentPlanStep {
  const AgentPlanStep({
    required this.title,
    required this.toolName,
    required this.rationale,
    required this.status,
  });
  final String title;
  final String toolName;
  final String rationale;
  final String status;
}

class GatewayRoute {
  const GatewayRoute({
    required this.name,
    required this.baseUrl,
    required this.healthUrl,
  });

  factory GatewayRoute.fromJson(Map<String, dynamic> json) {
    return GatewayRoute(
      name: json['name']?.toString() ?? '',
      baseUrl: json['base_url']?.toString() ?? '',
      healthUrl: json['health_url']?.toString() ?? '',
    );
  }

  final String name;
  final String baseUrl;
  final String healthUrl;
}

class PrivacyDeleteResult {
  const PrivacyDeleteResult({
    required this.accepted,
    required this.deletedScopes,
    required this.blockedReasons,
    required this.auditEvent,
  });

  factory PrivacyDeleteResult.fromJson(Map<String, dynamic> json) {
    return PrivacyDeleteResult(
      accepted: json['accepted'] == true,
      deletedScopes: (json['deleted_scopes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      blockedReasons: (json['blocked_reasons'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      auditEvent: json['audit_event']?.toString() ?? '',
    );
  }

  final bool accepted;
  final List<String> deletedScopes;
  final List<String> blockedReasons;
  final String auditEvent;
}

class DataIngestionResult {
  const DataIngestionResult({
    required this.accepted,
    required this.importedCount,
    required this.blockedReasons,
  });

  factory DataIngestionResult.fromJson(Map<String, dynamic> json) {
    return DataIngestionResult(
      accepted: json['accepted'] == true,
      importedCount: json['imported_count'] is num
          ? (json['imported_count'] as num).round()
          : 0,
      blockedReasons: (json['blocked_reasons'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  final bool accepted;
  final int importedCount;
  final List<String> blockedReasons;
}

class MultilingualTranslateResult {
  const MultilingualTranslateResult({
    required this.text,
    required this.targetLanguageCode,
    required this.languageDisplayName,
  });

  factory MultilingualTranslateResult.fromJson(Map<String, dynamic> json) {
    return MultilingualTranslateResult(
      text: json['text']?.toString() ?? '',
      targetLanguageCode: json['target_language_code']?.toString() ?? '',
      languageDisplayName: json['language_display_name']?.toString() ?? '',
    );
  }

  final String text;
  final String targetLanguageCode;
  final String languageDisplayName;
}

class LanguageDetectResult {
  const LanguageDetectResult({required this.languageCode});

  factory LanguageDetectResult.fromJson(Map<String, dynamic> json) {
    return LanguageDetectResult(
      languageCode: json['language_code']?.toString() ?? 'en-IN',
    );
  }

  final String languageCode;
}

class MultilingualChatResult {
  const MultilingualChatResult({required this.text});

  factory MultilingualChatResult.fromJson(Map<String, dynamic> json) {
    return MultilingualChatResult(text: json['text']?.toString() ?? '');
  }

  final String text;
}

class WebResearchHit {
  const WebResearchHit({
    required this.title,
    required this.url,
    required this.snippet,
  });

  factory WebResearchHit.fromJson(Map<String, dynamic> json) {
    return WebResearchHit(
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? '',
    );
  }

  final String title;
  final String url;
  final String snippet;
}

class WebPageSnapshot {
  const WebPageSnapshot({
    required this.title,
    required this.url,
    required this.excerpt,
  });

  factory WebPageSnapshot.fromJson(Map<String, dynamic> json) {
    return WebPageSnapshot(
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
    );
  }

  final String title;
  final String url;
  final String excerpt;
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.title,
    required this.price,
    required this.url,
    required this.snippet,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      title: json['title']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? '',
    );
  }

  final String title;
  final String price;
  final String url;
  final String snippet;
}

class OpportunityHit {
  const OpportunityHit({
    required this.title,
    required this.organization,
    required this.url,
    required this.summary,
  });

  factory OpportunityHit.fromJson(Map<String, dynamic> json) {
    return OpportunityHit(
      title: json['title']?.toString() ?? '',
      organization: json['organization']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }

  final String title;
  final String organization;
  final String url;
  final String summary;
}
