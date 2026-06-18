import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/theme/alter_palette.dart';
import '../../../domain/entities/alter_models.dart' as alter;
import '../../lens/domain/alter_lens_models.dart';
import '../../profile/domain/user_profile.dart';

const _featureBackendTimeout = Duration(seconds: 20);

class BackendFeatureApiClient {
  BackendFeatureApiClient({
    required String baseUrl,
    http.Client? client,
    Duration timeout = _featureBackendTimeout,
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/$'), ''),
       _client = client ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _client;
  final Duration _timeout;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<List<alter.OpportunitySignal>> fetchOpportunities({
    UserProfile? profile,
  }) async {
    if (!_hasProfileSignal(profile)) {
      return const <alter.OpportunitySignal>[];
    }
    final body = await _postJson(
      '/v1/opportunities/pipeline',
      <String, Object?>{
        'profile': _opportunityProfile(profile),
        'crawl': <String, Object?>{
          'sources': const <String>[],
          'query': _profileQuery(profile),
          'limit_per_source': 6,
          'mode': 'seed',
        },
        'limit': 6,
      },
    );
    final rawRecommendations = body['recommendations'] is Map<String, dynamic>
        ? (body['recommendations'] as Map<String, dynamic>)['recommendations']
        : body['recommendations'];
    final recommendations = _list(rawRecommendations)
        .cast<Map<String, dynamic>>()
        .map((json) => _opportunityFromRecommendation(json))
        .toList(growable: false);
    return recommendations;
  }

  Future<List<alter.FutureScenario>> simulateFutures({
    UserProfile? profile,
    double riskTolerance = 0.62,
    int horizonMonths = 36,
  }) async {
    if (!_hasProfileSignal(profile)) {
      return const <alter.FutureScenario>[];
    }
    final body = await _postJson(
      '/v1/future-simulation/simulate',
      _futureSimulationPayload(
        profile: profile,
        riskTolerance: riskTolerance,
        horizonMonths: horizonMonths,
      ),
    );
    final futures = _list(body['futures'])
        .cast<Map<String, dynamic>>()
        .map((json) => _futureFromProjection(json, body))
        .toList(growable: false);
    return futures;
  }

  Future<List<alter.CloneAgent>> fetchCloneAgents() async {
    final body = await _getJson('/v1/clone-council/agents');
    final agents = _list(body['agents']);
    return [
      for (final entry in agents.indexed)
        _cloneAgentFromSpec(entry.$2, entry.$1),
    ];
  }

  Future<BackendCouncilDebate> runCouncilDebate({
    required String topic,
    UserProfile? profile,
    String? userId,
  }) async {
    final body = await _postJson('/v1/clone-council/debate', <String, Object?>{
      'question': topic,
      'user_id': userId,
      'context': <String, Object?>{
        'user_profile': _profileSummary(profile),
        'surface': 'flutter',
      },
    });
    final opinions = _list(body['updated_opinions']).isNotEmpty
        ? _list(body['updated_opinions'])
        : _list(body['initial_opinions']);
    final entries = <BackendCouncilDebateEntry>[
      for (final entry in opinions.indexed)
        _debateEntryFromOpinion(entry.$2, entry.$1),
    ];
    return BackendCouncilDebate(
      entries: entries,
      consensus: _string(body['final_recommendation']),
      steps: _stringList(body['action_plan']).take(3).toList(growable: false),
    );
  }

  Future<List<alter.ReputationEvent>> fetchReputationEvents({
    required String userId,
  }) async {
    final body = await _getJson('/v1/reputation/users/$userId/events');
    return _list(body['events'])
        .cast<Map<String, dynamic>>()
        .map(_reputationEventFromJson)
        .toList(growable: false);
  }

  Future<LensScanResult> analyzeLensCapture({
    required LensScanType scanType,
    required List<int> imageBytes,
    required String filename,
    required String mimeType,
    String userContext = '',
  }) async {
    if (!isConfigured) {
      throw const BackendFeatureApiException('Backend URL is empty.');
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/v1/alter-lens/analyze'),
          )
          ..fields['scan_type'] = scanType.apiValue
          ..fields['user_context'] = userContext
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              imageBytes,
              filename: filename,
              contentType: _mediaType(mimeType),
            ),
          );
    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);
    return LensScanResult.fromJson(body);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _getJson(String path) async {
    if (!isConfigured) {
      throw const BackendFeatureApiException('Backend URL is empty.');
    }
    final response = await _client
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    if (!isConfigured) {
      throw const BackendFeatureApiException('Backend URL is empty.');
    }
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendFeatureApiException(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const BackendFeatureApiException('Backend returned invalid JSON.');
    }
    return decoded;
  }
}

class BackendCouncilDebate {
  const BackendCouncilDebate({
    required this.entries,
    required this.consensus,
    required this.steps,
  });

  final List<BackendCouncilDebateEntry> entries;
  final String consensus;
  final List<String> steps;
}

class BackendCouncilDebateEntry {
  const BackendCouncilDebateEntry({
    required this.name,
    required this.role,
    required this.accent,
    required this.response,
  });

  final String name;
  final String role;
  final Color accent;
  final String response;
}

class BackendFeatureApiException implements Exception {
  const BackendFeatureApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, Object?> _futureSimulationPayload({
  required UserProfile? profile,
  required double riskTolerance,
  required int horizonMonths,
}) {
  final skills = _stringsOr(profile?.skills, const <String>[]);
  final goals = _stringsOr(profile?.goals, const <String>[]);
  return <String, Object?>{
    'user_profile': <String, Object?>{
      'name': _nonEmpty(profile?.displayName, ''),
      'current_role': _nonEmpty(profile?.role, ''),
      'industry': _nonEmpty(profile?.industry, ''),
      'risk_tolerance': riskTolerance,
    },
    'skills': [
      for (final skill in skills)
        <String, Object?>{
          'name': skill,
          'category': 'domain',
          'level': 0.64,
          'years': 1.0,
        },
    ],
    'goals': [
      for (final goal in goals)
        <String, Object?>{
          'title': goal,
          'category': 'career',
          'horizon_months': horizonMonths,
          'priority': 4,
        },
    ],
    'experience': const <Map<String, Object?>>[],
    'interests': _stringsOr(profile?.interests, const <String>[]),
    'horizon_months': horizonMonths,
    'currency': null,
  };
}

Map<String, Object?> _opportunityProfile(UserProfile? profile) {
  return <String, Object?>{
    'career_stage': _nonEmpty(profile?.careerStage, ''),
    'skills': _stringsOr(profile?.skills, const <String>[]),
    'goals': _stringsOr(profile?.goals, const <String>[]),
    'interests': _stringsOr(profile?.interests, const <String>[]),
    'preferred_locations': const <String>[],
    'preferred_categories': const <String>[],
  };
}

Map<String, Object?> _profileSummary(UserProfile? profile) {
  return <String, Object?>{
    'name': _nonEmpty(profile?.displayName, ''),
    'role': _nonEmpty(profile?.role, ''),
    'career_stage': _nonEmpty(profile?.careerStage, ''),
    'industry': _nonEmpty(profile?.industry, ''),
    'skills': _stringsOr(profile?.skills, const <String>[]),
    'goals': _stringsOr(profile?.goals, const <String>[]),
    'interests': _stringsOr(profile?.interests, const <String>[]),
  };
}

String _profileQuery(UserProfile? profile) {
  final terms = [
    ..._stringsOr(profile?.goals, const <String>[]),
    ..._stringsOr(profile?.skills, const <String>[]),
    ..._stringsOr(profile?.interests, const <String>[]),
  ];
  return terms.take(6).join(' ');
}

alter.OpportunitySignal _opportunityFromRecommendation(
  Map<String, dynamic> json,
) {
  final opportunity = json['opportunity'] is Map<String, dynamic>
      ? json['opportunity'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final category = _string(opportunity['category'], fallback: 'program');
  final deadline = _string(opportunity['deadline_text']).isNotEmpty
      ? _string(opportunity['deadline_text'])
      : _string(opportunity['deadline'], fallback: 'Open window');
  return alter.OpportunitySignal(
    title: _string(opportunity['title'], fallback: 'Recommended opportunity'),
    category: category,
    score: _double(json['score']) / 100,
    source: _string(opportunity['source'], fallback: 'Opportunity Engine'),
    window: deadline,
    evidence: _string(
      json['why_now'],
      fallback: _string(json['recommendation']),
    ),
  );
}

alter.FutureScenario _futureFromProjection(
  Map<String, dynamic> json,
  Map<String, dynamic> envelope,
) {
  final horizon = envelope['horizon_months'] is num
      ? '${(envelope['horizon_months'] as num).round()} months'
      : '36 months';
  final opportunities = _stringList(json['key_opportunities']);
  final risks = _stringList(json['key_risks']);
  final actions = _stringList(json['recommended_next_actions']);
  return alter.FutureScenario(
    title: _string(json['name'], fallback: _string(json['future_id'])),
    horizon: horizon,
    probability: _double(json['success_probability']).clamp(0.0, 1.0),
    upside: opportunities.isNotEmpty
        ? opportunities.first
        : _string(json['thesis'], fallback: 'High-upside path identified.'),
    risk: risks.isNotEmpty
        ? risks.first
        : 'Execution quality is the main variable.',
    levers: actions.isNotEmpty
        ? actions.take(3).toList(growable: false)
        : const ['Skill growth', 'Network leverage', 'Proof capture'],
  );
}

alter.CloneAgent _cloneAgentFromSpec(Object? raw, int index) {
  final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  return alter.CloneAgent(
    name: _string(json['name'], fallback: 'Council Agent'),
    role: _string(json['mandate'], fallback: 'Strategic reasoning'),
    state: 'Ready',
    confidence: 0.78 + (index % 4) * 0.04,
    accent: _accent(index),
    summary: _string(
      json['operating_style'],
      fallback: _string(
        json['blind_spots_to_watch'],
        fallback: 'Ready to debate.',
      ),
    ),
  );
}

BackendCouncilDebateEntry _debateEntryFromOpinion(Object? raw, int index) {
  final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  final reasoning = _stringList(json['reasoning']);
  final recommendation = _string(json['recommendation']);
  final response = [
    _string(json['stance']),
    if (reasoning.isNotEmpty) reasoning.first,
    if (recommendation.isNotEmpty) recommendation,
  ].where((item) => item.isNotEmpty).join(' ');
  return BackendCouncilDebateEntry(
    name: _string(json['agent_name'], fallback: 'Council Agent'),
    role: _string(json['agent_id'], fallback: 'Backend council'),
    accent: _accent(index),
    response: response,
  );
}

alter.ReputationEvent _reputationEventFromJson(Map<String, dynamic> json) {
  return alter.ReputationEvent(
    title: _string(json['title'], fallback: 'Reputation event'),
    delta: json['impact_score'] is num
        ? (json['impact_score'] as num).round()
        : 0,
    description: _string(json['description']),
    timestamp: _relativeTimestamp(_string(json['occurred_at'])),
  );
}

Color _accent(int index) {
  const colors = [
    AlterPalette.iris,
    AlterPalette.cyan,
    AlterPalette.aura,
    AlterPalette.mint,
    AlterPalette.amber,
  ];
  return colors[index % colors.length];
}

List<dynamic> _list(Object? raw) {
  if (raw is! List<dynamic>) return const <dynamic>[];
  return raw;
}

List<String> _stringList(Object? raw) {
  if (raw is! Iterable) return const <String>[];
  return raw
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

List<String> _stringsOr(List<String>? values, List<String> fallback) {
  final clean = values
      ?.map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return clean == null || clean.isEmpty ? fallback : clean;
}

bool _hasProfileSignal(UserProfile? profile) {
  if (profile == null) return false;
  return [
    profile.displayName,
    profile.role,
    profile.careerStage,
    profile.industry,
    ...profile.skills,
    ...profile.goals,
    ...profile.interests,
  ].any((item) => item.trim().isNotEmpty);
}

double _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0;
}

String _string(Object? raw, {String fallback = ''}) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String _nonEmpty(String? raw, String fallback) {
  final value = raw?.trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String _relativeTimestamp(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return 'Recently';
  final delta = DateTime.now().difference(parsed.toLocal());
  if (delta.inMinutes < 2) return 'Just now';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

MediaType _mediaType(String mimeType) {
  final parts = mimeType.split('/');
  if (parts.length != 2) return MediaType('image', 'jpeg');
  return MediaType(parts.first, parts.last);
}
