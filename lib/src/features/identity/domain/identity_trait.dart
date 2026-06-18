class IdentityTrait {
  const IdentityTrait({
    this.id,
    required this.userId,
    required this.dimension,
    required this.value,
    required this.confidence,
    this.sourceMemoryIds = const [],
  });

  factory IdentityTrait.fromJson(Map<String, dynamic> json) {
    return IdentityTrait(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      dimension: json['dimension'] as String? ?? '',
      value: json['value'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      sourceMemoryIds: (json['source_memory_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  final String? id;
  final String userId;
  final String dimension;
  final String value;
  final double confidence;
  final List<String> sourceMemoryIds;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'dimension': dimension,
        'value': value,
        'confidence': confidence,
        'source_memory_ids': sourceMemoryIds,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
