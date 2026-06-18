/// Explicit feedback on a decision or suggestion. Stored as structured events
/// (and mirrored into memory) so retrieval and *future* preference learning /
/// contextual bandits have clean signal. This is NOT reinforcement learning —
/// no policy is trained from it today; it is logged, typed signal only.
enum DecisionFeedbackKind {
  accepted,
  rejected,
  postponed,
  completed,
  regretted,
}

enum OutcomeValence { positive, negative, neutral, unknown }

DecisionFeedbackKind feedbackKindFromString(String value) {
  return DecisionFeedbackKind.values.firstWhere(
    (k) => k.name == value.toLowerCase().trim(),
    orElse: () => DecisionFeedbackKind.accepted,
  );
}

OutcomeValence valenceFromString(String value) {
  return OutcomeValence.values.firstWhere(
    (v) => v.name == value.toLowerCase().trim(),
    orElse: () => OutcomeValence.unknown,
  );
}

class FeedbackEvent {
  const FeedbackEvent({
    required this.id,
    required this.decision,
    required this.kind,
    this.outcome = OutcomeValence.unknown,
    this.rating,
    this.note = '',
    this.evidence = '',
    required this.at,
    this.context = const {},
  });

  factory FeedbackEvent.fromJson(Map<String, dynamic> json) {
    return FeedbackEvent(
      id: (json['id'] ?? '').toString(),
      decision: (json['decision'] ?? '').toString(),
      kind: feedbackKindFromString((json['kind'] ?? '').toString()),
      outcome: valenceFromString((json['outcome'] ?? '').toString()),
      rating: json['rating'] is num ? (json['rating'] as num).toInt() : null,
      note: (json['note'] ?? '').toString(),
      evidence: (json['evidence'] ?? '').toString(),
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
      context: json['context'] is Map
          ? Map<String, Object?>.from(json['context'] as Map)
          : const {},
    );
  }

  /// Stable id for the decision/suggestion this feedback is about.
  final String decision;
  final String id;
  final DecisionFeedbackKind kind;
  final OutcomeValence outcome;

  /// Optional 1–5 satisfaction rating.
  final int? rating;

  /// Free-text note / follow-through evidence description.
  final String note;

  /// Optional proof link (URL / artifact).
  final String evidence;
  final DateTime at;

  /// Snapshot of the decision context (options considered, signals, etc.) —
  /// the feature vector a future preference model / bandit would consume.
  final Map<String, Object?> context;

  /// A scalar reward signal in [-1, 1] derived from the feedback. Provided for
  /// *future* preference scoring; nothing trains on it yet.
  double get rewardSignal {
    switch (kind) {
      case DecisionFeedbackKind.completed:
        return outcome == OutcomeValence.negative ? -0.5 : 1.0;
      case DecisionFeedbackKind.accepted:
        return 0.5;
      case DecisionFeedbackKind.postponed:
        return 0.0;
      case DecisionFeedbackKind.rejected:
        return -0.5;
      case DecisionFeedbackKind.regretted:
        return -1.0;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'decision': decision,
        'kind': kind.name,
        'outcome': outcome.name,
        if (rating != null) 'rating': rating,
        'note': note,
        'evidence': evidence,
        'at': at.toIso8601String(),
        'context': context,
      };
}
