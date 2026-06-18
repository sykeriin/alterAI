import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contextos/application/gemma_model_manager.dart';
import '../privacy/data/context_privacy_filter.dart';

/// On-device AI used by the agent. Backed by the real Gemma model when it is
/// installed and loaded on the phone; otherwise the always-available heuristic.
/// The agent just reads this provider — the swap is invisible to it.
final onDeviceAiProvider = Provider<OnDeviceAi>((ref) {
  const fallback = HeuristicOnDeviceAi();
  final gemma = ref.watch(gemmaModelProvider);
  if (gemma.isReady) {
    return GemmaOnDeviceAi(ref.read(gemmaModelProvider.notifier), fallback);
  }
  return fallback;
});

/// Lightweight, private, on-device tasks. The default implementation is a pure
/// heuristic that always works with no model — the stub/fallback so the app is
/// never blocked when platform AI (Gemini Nano, LiteRT, Apple Foundation
/// Models, on-device Gemma) is unavailable or offline. A model-backed
/// implementation can be swapped in behind this same interface later.
abstract class OnDeviceAi {
  /// A coarse snake_case intent label for [text].
  Future<String> classifyIntent(String text);

  /// Whether the request likely needs heavy cloud reasoning (vs a quick reply).
  /// Used to route to a stronger cloud model only when it's worth it.
  Future<bool> needsDeepReasoning(String text);

  /// An extractive on-device summary, capped to roughly [maxWords] words.
  Future<String> summarize(String text, {int maxWords = 40});

  /// Redact obvious PII before anything leaves the device.
  Future<String> redact(String text);

  /// A short proactive nudge draft from a one-line [context].
  Future<String> draftNudge(String context);
}

class HeuristicOnDeviceAi implements OnDeviceAi {
  const HeuristicOnDeviceAi();

  static const _intents = <String, List<String>>{
    'schedule': ['remind', 'schedule', 'calendar', 'meeting', 'appointment'],
    'message': ['message', 'text', 'whatsapp', 'email', 'reply', 'send'],
    'call': ['call', 'dial', 'phone'],
    'search': ['find', 'search', 'look up', 'discover', 'opportunit'],
    'navigate': ['open', 'go to', 'launch', 'navigate'],
    'decision': [
      'should i',
      'decide',
      'decision',
      'pros and cons',
      'trade-off',
      'tradeoff',
      'weigh',
      'compare',
    ],
    'planning': ['plan', 'roadmap', 'steps to', 'how do i'],
    'reflect': ['analyze', 'why', 'explain', 'reason', 'evaluate'],
  };

  @override
  Future<String> classifyIntent(String text) async {
    final t = text.toLowerCase();
    for (final entry in _intents.entries) {
      if (entry.value.any(t.contains)) return entry.key;
    }
    return 'chat';
  }

  @override
  Future<bool> needsDeepReasoning(String text) async {
    if (text.length > 220) return true;
    final intent = await classifyIntent(text);
    return intent == 'decision' || intent == 'planning' || intent == 'reflect';
  }

  @override
  Future<String> summarize(String text, {int maxWords = 40}) async {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text.trim();
    return '${words.take(maxWords).join(' ')}…';
  }

  @override
  Future<String> redact(String text) async {
    // Reuse the cloud-bound privacy filter, but keep full length (redact only).
    return const ContextPrivacyFilter(maxChars: 1 << 30).filter(text);
  }

  @override
  Future<String> draftNudge(String context) async {
    final clean = context.trim();
    if (clean.isEmpty) return 'Want me to help you plan your next move?';
    final short = clean.length > 90 ? '${clean.substring(0, 90)}…' : clean;
    return 'Based on "$short" — want me to take the next step on this?';
  }
}

/// On-device AI backed by the real Gemma model running on the phone (via
/// flutter_gemma / MediaPipe). Every method degrades to [_fallback] when the
/// model returns nothing or fails, so behaviour is never worse than heuristic.
///
/// Redaction stays deterministic on purpose — PII stripping is a regex job, not
/// something to trust a language model with.
class GemmaOnDeviceAi implements OnDeviceAi {
  GemmaOnDeviceAi(this._gemma, this._fallback);

  final GemmaModelManager _gemma;
  final HeuristicOnDeviceAi _fallback;

  static const _intents = <String>[
    'schedule',
    'message',
    'call',
    'search',
    'navigate',
    'decision',
    'planning',
    'reflect',
    'chat',
  ];

  @override
  Future<String> classifyIntent(String text) async {
    final out = await _gemma.generate(
      'Classify the request into ONE intent from this list: '
      '${_intents.join(', ')}. Reply with only the single intent word.\n\n'
      'Request: "$text"\nIntent:',
      temperature: 0,
      topK: 1,
    );
    if (out != null) {
      final lower = out.toLowerCase();
      for (final intent in _intents) {
        if (lower.contains(intent)) return intent;
      }
    }
    return _fallback.classifyIntent(text);
  }

  @override
  Future<bool> needsDeepReasoning(String text) async {
    final out = await _gemma.generate(
      'Does answering this well require deep multi-step reasoning — weighing '
      'trade-offs, planning, or analysis — rather than a quick reply? '
      'Reply with only YES or NO.\n\nRequest: "$text"\nAnswer:',
      temperature: 0,
      topK: 1,
    );
    if (out != null) {
      final u = out.toUpperCase();
      if (u.contains('YES')) return true;
      if (u.contains('NO')) return false;
    }
    return _fallback.needsDeepReasoning(text);
  }

  @override
  Future<String> summarize(String text, {int maxWords = 40}) async {
    final out = await _gemma.generate(
      'Summarize the text in at most $maxWords words, plain and factual. '
      'Reply with only the summary.\n\nText:\n"$text"\nSummary:',
      temperature: 0.2,
    );
    if (out == null || out.isEmpty) {
      return _fallback.summarize(text, maxWords: maxWords);
    }
    // Enforce the word cap even if the model overran it.
    return _fallback.summarize(out, maxWords: maxWords);
  }

  @override
  Future<String> redact(String text) => _fallback.redact(text);

  @override
  Future<String> draftNudge(String context) async {
    final out = await _gemma.generate(
      'Write ONE short, friendly proactive nudge (max 18 words) suggesting a '
      'helpful next step from this context. No preamble, no quotes.\n\n'
      'Context: "$context"\nNudge:',
      temperature: 0.5,
    );
    if (out == null || out.isEmpty) return _fallback.draftNudge(context);
    // One line only.
    return out.split('\n').first.trim();
  }
}
