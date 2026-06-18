class ScoredMemoryVector {
  const ScoredMemoryVector({
    required this.abstractText,
    required this.kind,
    required this.score,
    this.memoryId,
  });

  final String abstractText;
  final String kind;
  final double score;
  final String? memoryId;
}
