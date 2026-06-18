enum LensScanType {
  resume('resume', 'Resume'),
  startupDeck('startup_deck', 'Startup deck'),
  eventPoster('event_poster', 'Event poster'),
  researchPaper('research_paper', 'Research paper'),
  product('product', 'Product');

  const LensScanType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static LensScanType fromApiValue(String value) {
    return LensScanType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => LensScanType.product,
    );
  }
}

enum LensPriority {
  low,
  medium,
  high,
  urgent;

  String get label => name[0].toUpperCase() + name.substring(1);

  static LensPriority fromJson(String value) {
    return LensPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => LensPriority.medium,
    );
  }
}

class LensScanResult {
  const LensScanResult({
    required this.scanId,
    required this.scanType,
    required this.detectedType,
    required this.summary,
    required this.confidence,
    required this.insights,
    required this.opportunities,
    required this.recommendations,
    required this.extractedEntities,
    required this.memoryCandidates,
    required this.createdAt,
  });

  factory LensScanResult.fromJson(Map<String, dynamic> json) {
    return LensScanResult(
      scanId: json['scan_id']?.toString() ?? '',
      scanType: LensScanType.fromApiValue(json['scan_type']?.toString() ?? ''),
      detectedType: json['detected_type']?.toString() ?? 'Unknown',
      summary: json['summary']?.toString() ?? '',
      confidence: _double(json['confidence']),
      insights: _list(json['insights'], LensInsightSignal.fromJson),
      opportunities: _list(json['opportunities'], LensOpportunity.fromJson),
      recommendations: _list(
        json['recommendations'],
        LensRecommendation.fromJson,
      ),
      extractedEntities: _entityMap(json['extracted_entities']),
      memoryCandidates: _stringList(json['memory_candidates']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String scanId;
  final LensScanType scanType;
  final String detectedType;
  final String summary;
  final double confidence;
  final List<LensInsightSignal> insights;
  final List<LensOpportunity> opportunities;
  final List<LensRecommendation> recommendations;
  final Map<String, List<String>> extractedEntities;
  final List<String> memoryCandidates;
  final DateTime createdAt;
}

class LensInsightSignal {
  const LensInsightSignal({
    required this.title,
    required this.detail,
    required this.confidence,
    required this.tags,
  });

  factory LensInsightSignal.fromJson(Map<String, dynamic> json) {
    return LensInsightSignal(
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      confidence: _double(json['confidence']),
      tags: _stringList(json['tags']),
    );
  }

  final String title;
  final String detail;
  final double confidence;
  final List<String> tags;
}

class LensOpportunity {
  const LensOpportunity({
    required this.title,
    required this.whyNow,
    required this.nextStep,
    required this.score,
  });

  factory LensOpportunity.fromJson(Map<String, dynamic> json) {
    return LensOpportunity(
      title: json['title']?.toString() ?? '',
      whyNow: json['why_now']?.toString() ?? '',
      nextStep: json['next_step']?.toString() ?? '',
      score: _double(json['score']),
    );
  }

  final String title;
  final String whyNow;
  final String nextStep;
  final double score;
}

class LensRecommendation {
  const LensRecommendation({
    required this.action,
    required this.priority,
    required this.rationale,
  });

  factory LensRecommendation.fromJson(Map<String, dynamic> json) {
    return LensRecommendation(
      action: json['action']?.toString() ?? '',
      priority: LensPriority.fromJson(json['priority']?.toString() ?? ''),
      rationale: json['rationale']?.toString() ?? '',
    );
  }

  final String action;
  final LensPriority priority;
  final String rationale;
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<T> _list<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! Iterable) {
    return const [];
  }
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

Map<String, List<String>> _entityMap(Object? value) {
  if (value is! Map<dynamic, dynamic>) {
    return const {};
  }
  return value.map((key, item) => MapEntry(key.toString(), _stringList(item)));
}
