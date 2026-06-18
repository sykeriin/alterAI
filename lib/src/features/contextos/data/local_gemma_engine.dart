import '../domain/contextos_models.dart';

/// First-pass edge model contract. Runs on-device, before any cloud call.
///
/// [HeuristicGemmaEngine] uses regex + heuristics. [GemmaEdgeEngine] (when Gemma 4
/// is loaded) adds LLM verdict on redacted text.
abstract class LocalGemmaEngine {
  /// Strip sensitive tokens locally. Returns redacted text + which field
  /// kinds were removed (e.g. "OTP", "card number"). Never hits the network.
  ({String text, List<String> fields}) redact(String input);

  /// Fast on-device risk triage.
  RiskVerdict classifyRisk(String input);

  /// Short offline summary of the moment.
  String summarize(String input);

  /// Whether this moment is worth escalating to cloud reasoning.
  bool shouldEscalate(String input, RiskVerdict coarse);

  /// One-line plain-language explanation usable fully offline.
  String explainOffline(String input, RiskVerdict coarse);

  /// Convenience: full edge pass (redact → classify → escalate decision).
  EdgeTriage analyze(String input);

  /// Async edge pass. The heuristic engine wraps [analyze].
  Future<EdgeTriage> analyzeAsync(String input);
}

class HeuristicGemmaEngine implements LocalGemmaEngine {
  const HeuristicGemmaEngine();

  // --- Local redaction patterns (sensitive data never leaves the device) ---
  static final _patterns = <String, RegExp>{
    'card number': RegExp(r'\b(?:\d[ -]?){13,16}\b'),
    'OTP / code': RegExp(
      r'\b\d{4,8}\b(?=.*(?:otp|code|pin|verify))',
      caseSensitive: false,
    ),
    'phone': RegExp(r'\b(?:\+?\d{1,3}[ -]?)?\d{10}\b'),
    'email': RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b'),
    'UPI id': RegExp(
      r'\b[\w.-]+@(?:okaxis|oksbi|okhdfcbank|ybl|paytm|upi)\b',
      caseSensitive: false,
    ),
    'account no.': RegExp(
      r'\bac(?:count)?\s*(?:no\.?|number)?\s*[:#]?\s*\d{6,}\b',
      caseSensitive: false,
    ),
  };

  static final _scamSignals = <String, String>{
    r'\b(otp|one[- ]?time\s?password|verification code)\b':
        'Asks for an OTP / verification code',
    r'\b(urgent|immediately|act now|within \d+\s?(min|hour)|expir)':
        'Urgency / time pressure',
    r'\b(blocked|suspended|deactivat|frozen|kyc)\b':
        'Account-threat pressure (block / KYC)',
    r'\b(click|tap)\s+(here|this|link|below)\b': 'Pushes a link tap',
    r'\b(refund|prize|won|lottery|cashback|reward)\b': 'Too-good reward bait',
    r'(bit\.ly|tinyurl|t\.me|\.xyz|\.top|\.live|short)':
        'Shortened / odd domain',
    r'\b(install|download|apk|enable\s+(unknown|accessibility))\b':
        'Wants an install / risky permission',
    r'\b(gift\s?card|google\s?play\s?code|crypto|bitcoin|usdt)\b':
        'Untraceable payment request',
    r'\b(do\s?not\s?(tell|share)|keep\s?(this\s?)?secret)\b':
        'Asks for secrecy',
  };

  @override
  ({String text, List<String> fields}) redact(String input) {
    var text = input;
    final fields = <String>[];
    _patterns.forEach((label, re) {
      if (re.hasMatch(text)) {
        fields.add(label);
        text = text.replaceAll(re, '[$label redacted]');
      }
    });
    return (text: text, fields: fields);
  }

  List<String> _signals(String input) {
    final lower = input.toLowerCase();
    final hits = <String>[];
    _scamSignals.forEach((pattern, label) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        hits.add(label);
      }
    });
    return hits;
  }

  @override
  RiskVerdict classifyRisk(String input) {
    final count = _signals(input).length;
    final asksMoneyOrCode = RegExp(
      r'\b(otp|pay|upi|transfer|card|cvv|password|gift\s?card)\b',
      caseSensitive: false,
    ).hasMatch(input);
    if (count >= 3 || (count >= 2 && asksMoneyOrCode))
      return RiskVerdict.dangerous;
    if (count >= 1 && asksMoneyOrCode) return RiskVerdict.needsVerification;
    if (count >= 1) return RiskVerdict.caution;
    return RiskVerdict.safe;
  }

  @override
  String summarize(String input) {
    final clean = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 140) return clean;
    return '${clean.substring(0, 137)}…';
  }

  @override
  bool shouldEscalate(String input, RiskVerdict coarse) {
    // Escalate anything non-trivially risky, or longer ambiguous content.
    return coarse != RiskVerdict.safe || input.length > 280;
  }

  @override
  String explainOffline(String input, RiskVerdict coarse) {
    final signals = _signals(input);
    switch (coarse) {
      case RiskVerdict.dangerous:
        return 'On-device check flagged multiple scam patterns'
            '${signals.isEmpty ? '' : ': ${signals.first.toLowerCase()}'}. '
            'Do not act until verified.';
      case RiskVerdict.needsVerification:
        return 'This asks for money or a code with a pressure signal. '
            'Verify through an official channel first.';
      case RiskVerdict.caution:
        return 'Some pressure language detected. Read carefully before acting.';
      case RiskVerdict.safe:
        return 'No obvious risk patterns found on-device.';
    }
  }

  @override
  EdgeTriage analyze(String input) {
    final redaction = redact(input);
    final signals = _signals(input);
    final coarse = classifyRisk(input);
    return EdgeTriage(
      redactedText: redaction.text,
      redactedFields: redaction.fields,
      coarseVerdict: coarse,
      signals: signals,
      shouldEscalate: shouldEscalate(input, coarse),
      summary: explainOffline(input, coarse),
    );
  }

  @override
  Future<EdgeTriage> analyzeAsync(String input) async => analyze(input);

  /// Exposed for signal extraction reuse.
  List<String> signalsOf(String input) => _signals(input);
}
