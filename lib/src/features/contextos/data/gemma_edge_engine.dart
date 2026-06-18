import 'package:flutter_gemma/flutter_gemma.dart';

import '../domain/contextos_models.dart';
import 'local_gemma_engine.dart';

/// Real on-device edge engine. Redaction + signal extraction stay deterministic
/// and local (reused from [HeuristicGemmaEngine]); the risk *verdict* and its
/// plain-language reason come from Gemma running on the phone via MediaPipe.
///
/// Any inference failure degrades silently to the heuristic verdict, so the
/// pipeline never blocks on the model.
class GemmaEdgeEngine extends HeuristicGemmaEngine {
  GemmaEdgeEngine(this._model);

  final InferenceModel _model;

  @override
  Future<EdgeTriage> analyzeAsync(String input) async {
    final base = analyze(input); // heuristic: redaction + signals + fallback
    try {
      final session = await _model.createSession(temperature: 0.1, topK: 1);
      await session.addQueryChunk(
        Message.text(text: _prompt(base.redactedText), isUser: true),
      );
      final raw = await session.getResponse();
      await session.close();

      final verdict = _parseVerdict(raw);
      if (verdict == null) return base;

      final reason = _parseReason(raw);
      return EdgeTriage(
        redactedText: base.redactedText,
        redactedFields: base.redactedFields,
        coarseVerdict: verdict,
        signals: base.signals,
        shouldEscalate: verdict != RiskVerdict.safe || input.length > 280,
        summary: reason.isNotEmpty ? 'Gemma on-device: $reason' : base.summary,
      );
    } catch (_) {
      return base;
    }
  }

  String _prompt(String redacted) =>
      'You are an on-device phone safety classifier. Classify the risk of acting '
      'on this message/notification. Reply with EXACTLY one label from '
      '[SAFE, CAUTION, VERIFY, DANGEROUS] then " - " then a short reason '
      '(max 14 words). No other text.\n\nMessage:\n"""\n$redacted\n"""\n\nAnswer:';

  RiskVerdict? _parseVerdict(String raw) {
    final u = raw.toUpperCase();
    // Order matters: check the most severe first.
    if (u.contains('DANGEROUS') || u.contains('DANGER')) {
      return RiskVerdict.dangerous;
    }
    if (u.contains('VERIFY') || u.contains('NEEDS VERIF')) {
      return RiskVerdict.needsVerification;
    }
    if (u.contains('CAUTION')) return RiskVerdict.caution;
    if (u.contains('SAFE')) return RiskVerdict.safe;
    return null;
  }

  String _parseReason(String raw) {
    final idx = raw.indexOf('-');
    if (idx >= 0 && idx + 1 < raw.length) {
      return raw.substring(idx + 1).trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    return '';
  }
}
