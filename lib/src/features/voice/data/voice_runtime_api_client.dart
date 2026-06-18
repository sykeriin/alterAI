import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/errors/alter_service_exception.dart';
import '../../profile/domain/user_profile.dart';

class VoiceRuntimeApiClient {
  VoiceRuntimeApiClient({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AlterGatewayConfig.normalizedBaseUrl;

  Future<VoiceRuntimeResult> run({
    required String transcript,
    required String locale,
    String? userId,
    UserProfile? profile,
    String memoryContext = '',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/voice/action-runtime'),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, Object>{
            if (userId != null && userId.isNotEmpty) 'user_id': userId,
            'transcript': transcript,
            'locale': locale,
            'device_surface': 'phone',
            'user_profile': _profilePayload(profile),
            'skills': _skills(profile),
            'goals': _goals(profile),
            'interests': _interests(profile),
            if (memoryContext.isNotEmpty) 'memory_context': memoryContext,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlterServiceException(
        'Voice runtime HTTP ${response.statusCode}',
        kind: _kindForStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const AlterServiceException(
        'Voice runtime invalid JSON',
        kind: ServiceErrorKind.parse,
      );
    }
    return VoiceRuntimeResult.fromJson(body);
  }

  void close() => _client.close();
}

ServiceErrorKind _kindForStatus(int code) {
  if (code == 401 || code == 403) return ServiceErrorKind.auth;
  if (code == 404) return ServiceErrorKind.notFound;
  if (code == 429) return ServiceErrorKind.quota;
  if (code >= 500) return ServiceErrorKind.server;
  return ServiceErrorKind.unknown;
}

class VoiceRuntimeApiException implements Exception {
  const VoiceRuntimeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VoiceRuntimeResult {
  const VoiceRuntimeResult({
    required this.normalizedText,
    required this.wakeWordDetected,
    required this.inferredIntent,
    required this.intentConfidence,
    required this.spokenResponse,
    required this.displayResponse,
    required this.actionGraph,
    required this.experimentPlan,
    required this.nextActions,
    required this.followUpQuestions,
    required this.signals,
  });

  factory VoiceRuntimeResult.fromJson(Map<String, dynamic> json) {
    return VoiceRuntimeResult(
      normalizedText: _string(json['normalized_text']),
      wakeWordDetected: json['wake_word_detected'] == true,
      inferredIntent: _string(json['inferred_intent'], fallback: 'unknown'),
      intentConfidence: _double(json['intent_confidence']),
      spokenResponse: _string(json['spoken_response']),
      displayResponse: _string(json['display_response']),
      actionGraph: _parseStringList(json['action_graph']),
      experimentPlan: json['experiment_plan'] is Map<String, dynamic>
          ? VoiceExperimentPlan.fromJson(
              json['experiment_plan'] as Map<String, dynamic>,
            )
          : null,
      nextActions: _parseStringList(json['next_actions']),
      followUpQuestions: _parseStringList(json['follow_up_questions']),
      signals: _parseSignals(json['signals']),
    );
  }

  final String normalizedText;
  final bool wakeWordDetected;
  final String inferredIntent;
  final double intentConfidence;
  final String spokenResponse;
  final String displayResponse;
  final List<String> actionGraph;
  final VoiceExperimentPlan? experimentPlan;
  final List<String> nextActions;
  final List<String> followUpQuestions;
  final List<VoiceRuntimeSignal> signals;
}

class VoiceExperimentPlan {
  const VoiceExperimentPlan({
    required this.action,
    required this.whyItMatters,
    required this.deadline,
    required this.successMetric,
  });

  factory VoiceExperimentPlan.fromJson(Map<String, dynamic> json) {
    return VoiceExperimentPlan(
      action: _string(json['action']),
      whyItMatters: _string(json['why_it_matters']),
      deadline: _string(json['deadline']),
      successMetric: _string(json['success_metric']),
    );
  }

  final String action;
  final String whyItMatters;
  final String deadline;
  final String successMetric;
}

class VoiceRuntimeSignal {
  const VoiceRuntimeSignal({
    required this.title,
    required this.status,
    required this.summary,
    required this.latencyMs,
  });

  factory VoiceRuntimeSignal.fromJson(Map<String, dynamic> json) {
    return VoiceRuntimeSignal(
      title: _string(json['title']),
      status: _string(json['status'], fallback: 'unknown'),
      summary: _string(json['summary']),
      latencyMs: json['latency_ms'] is num
          ? (json['latency_ms'] as num).round()
          : null,
    );
  }

  final String title;
  final String status;
  final String summary;
  final int? latencyMs;

  bool get isHealthy => status == 'ok';
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw.whereType<String>().toList(growable: false);
}

List<VoiceRuntimeSignal> _parseSignals(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <VoiceRuntimeSignal>[];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(VoiceRuntimeSignal.fromJson)
      .toList(growable: false);
}

double _double(Object? raw) {
  return raw is num ? raw.toDouble() : 0;
}

String _string(Object? raw, {String fallback = ''}) {
  return raw is String && raw.isNotEmpty ? raw : fallback;
}

Map<String, Object> _profilePayload(UserProfile? profile) {
  if (profile == null || profile.displayName.isEmpty) {
    return const <String, Object>{};
  }
  return <String, Object>{
    'name': profile.displayName,
    if (profile.role.isNotEmpty) 'current_role': profile.role,
    if (profile.careerStage.isNotEmpty) 'career_stage': profile.careerStage,
    if (profile.industry.isNotEmpty) 'industry': profile.industry,
  };
}

List<String> _skills(UserProfile? profile) {
  if (profile?.skills.isNotEmpty == true) return profile!.skills;
  return const <String>[];
}

List<String> _goals(UserProfile? profile) {
  if (profile?.goals.isNotEmpty == true) return profile!.goals;
  return const <String>[];
}

List<String> _interests(UserProfile? profile) {
  if (profile?.interests.isNotEmpty == true) return profile!.interests;
  return const <String>[];
}
