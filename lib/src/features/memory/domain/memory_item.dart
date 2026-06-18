enum MemoryKind {
  preference,
  relationship,
  commitment,
  goal,
  decision,
  routine,
  skill,
  event,
  communicationStyle,
  observation,
}

enum MemoryRetention {
  ephemeral,
  durable,
  immediateDelete,
}

enum MemorySensitivity {
  normal,
  sensitive,
  restricted,
}

class MemoryItem {
  const MemoryItem({
    this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.content,
    required this.provenance,
    required this.confidence,
    required this.sensitivity,
    required this.retention,
    this.expiresAt,
    this.sourceIds = const [],
    this.confirmed = false,
    this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      kind: MemoryKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MemoryKind.observation,
      ),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      provenance: json['provenance'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      sensitivity: MemorySensitivity.values.firstWhere(
        (s) => s.name == json['sensitivity'],
        orElse: () => MemorySensitivity.normal,
      ),
      retention: MemoryRetention.values.firstWhere(
        (r) => r.name == json['retention'],
        orElse: () => MemoryRetention.ephemeral,
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      sourceIds:
          (json['source_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      confirmed: json['confirmed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  final String? id;
  final String userId;
  final MemoryKind kind;
  final String title;
  final String content;
  final String provenance;
  final double confidence;
  final MemorySensitivity sensitivity;
  final MemoryRetention retention;
  final DateTime? expiresAt;
  final List<String> sourceIds;
  final bool confirmed;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'kind': kind.name,
        'title': title,
        'content': content,
        'provenance': provenance,
        'confidence': confidence,
        'sensitivity': sensitivity.name,
        'retention': retention.name,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        'source_ids': sourceIds,
        'confirmed': confirmed,
        'updated_at': DateTime.now().toIso8601String(),
      };

  MemoryItem copyWith({
    String? title,
    String? content,
    double? confidence,
    bool? confirmed,
    MemoryRetention? retention,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return MemoryItem(
      id: id,
      userId: userId,
      kind: kind,
      title: title ?? this.title,
      content: content ?? this.content,
      provenance: provenance,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity,
      retention: retention ?? this.retention,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      sourceIds: sourceIds,
      confirmed: confirmed ?? this.confirmed,
      createdAt: createdAt,
    );
  }
}

class MemoryClassification {
  const MemoryClassification({
    required this.relevant,
    required this.sensitive,
    required this.requiresAction,
    required this.shouldRemember,
    required this.retention,
    required this.kind,
    required this.sensitivity,
    required this.confidence,
  });

  final bool relevant;
  final bool sensitive;
  final bool requiresAction;
  final bool shouldRemember;
  final MemoryRetention retention;
  final MemoryKind kind;
  final MemorySensitivity sensitivity;
  final double confidence;
}
