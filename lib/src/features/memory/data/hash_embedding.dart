import 'dart:math';

/// Deterministic 384-dim embedding from text (no extra model download).
class HashEmbedding {
  const HashEmbedding._();

  static const dim = 384;

  static List<double> embed(String text) {
    final normalized = text.toLowerCase().trim();
    final vec = List<double>.filled(dim, 0);
    if (normalized.isEmpty) return vec;

    final tokens = normalized.split(RegExp(r'\W+')).where((t) => t.length > 1);
    var i = 0;
    for (final token in tokens) {
      final h = token.hashCode;
      for (var j = 0; j < 8; j++) {
        final idx = ((h >> (j * 4)) & 0xFFF) % dim;
        vec[idx] += 1.0 / (1 + i * 0.1);
      }
      i++;
    }
    for (var c = 0; c < normalized.length; c++) {
      vec[(normalized.codeUnitAt(c) * 17 + c) % dim] += 0.05;
    }
    return _normalize(vec);
  }

  static double cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < min(a.length, b.length); i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  static List<double> _normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    if (sum == 0) return v;
    final inv = 1 / sqrt(sum);
    return [for (final x in v) x * inv];
  }
}
