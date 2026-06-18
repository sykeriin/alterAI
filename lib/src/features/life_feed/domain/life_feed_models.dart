class LifeFeedTask {
  const LifeFeedTask({
    required this.title,
    required this.meta,
    required this.badge,
    this.done = false,
    this.hot = false,
  });

  factory LifeFeedTask.fromJson(Map<String, dynamic> json) {
    return LifeFeedTask(
      title: json['title'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      hot: json['hot'] as bool? ?? false,
    );
  }

  final String title;
  final String meta;
  final String badge;
  final bool done;
  final bool hot;

  LifeFeedTask copyWith({bool? done}) => LifeFeedTask(
        title: title,
        meta: meta,
        badge: badge,
        done: done ?? this.done,
        hot: hot,
      );
}

class LifeFeedOpportunity {
  const LifeFeedOpportunity({
    required this.tag,
    required this.matchScore,
    required this.title,
    required this.meta,
  });

  factory LifeFeedOpportunity.fromJson(Map<String, dynamic> json) {
    return LifeFeedOpportunity(
      tag: json['tag'] as String? ?? '',
      matchScore: json['match_score'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
    );
  }

  final String tag;
  final int matchScore;
  final String title;
  final String meta;
}

class LifeFeedSnapshot {
  const LifeFeedSnapshot({
    required this.greeting,
    required this.dateSummary,
    required this.focusTitle,
    required this.focusRationale,
    required this.tasks,
    required this.opportunities,
    required this.itemsNeedingAttention,
  });

  factory LifeFeedSnapshot.fromJson(Map<String, dynamic> json) {
    return LifeFeedSnapshot(
      greeting: json['greeting'] as String? ?? 'Good morning',
      dateSummary: json['date_summary'] as String? ?? '',
      focusTitle: json['focus_title'] as String? ?? '',
      focusRationale: json['focus_rationale'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .map((e) => LifeFeedTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      opportunities: (json['opportunities'] as List<dynamic>? ?? const [])
          .map((e) => LifeFeedOpportunity.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemsNeedingAttention: json['items_needing_attention'] as int? ?? 0,
    );
  }

  /// Empty snapshot — nothing inferred yet from user activity.
  static LifeFeedSnapshot empty({String firstName = 'there'}) {
    return LifeFeedSnapshot(
      greeting: firstName == 'there'
          ? 'Still inferring…'
          : 'Still inferring, $firstName.',
      dateSummary: 'Nothing observed yet',
      focusTitle: '',
      focusRationale: '',
      itemsNeedingAttention: 0,
      opportunities: const [],
      tasks: const [],
    );
  }

  bool get hasContent =>
      tasks.isNotEmpty ||
      opportunities.isNotEmpty ||
      focusTitle.isNotEmpty ||
      itemsNeedingAttention > 0;

  final String greeting;
  final String dateSummary;
  final String focusTitle;
  final String focusRationale;
  final List<LifeFeedTask> tasks;
  final List<LifeFeedOpportunity> opportunities;
  final int itemsNeedingAttention;
}
