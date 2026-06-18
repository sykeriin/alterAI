import '../../profile/domain/user_profile.dart';
import '../data/voice_runtime_api_client.dart';

/// Deterministic voice response when cloud, gateway, and Gemma are unavailable.
class VoiceLocalFallback {
  const VoiceLocalFallback._();

  static VoiceRuntimeResult? respond({
    required String transcript,
    required String memoryBlock,
    required String identityBlock,
    UserProfile? profile,
    required bool offline,
  }) {
    final text = transcript.trim();
    if (text.length < 2) return null;

    final lower = text.toLowerCase();
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName.split(' ').first
        : null;
    var intent = 'conversation';
    var spoken = offline
        ? (name != null
            ? '$name, I\'m answering offline from what I remember on this phone.'
            : 'I\'m answering offline from what I remember on this phone.')
        : "I'm here. I couldn't reach my AI brain just now — tell me what you "
            'need and I\'ll help as soon as I\'m back online.';

    if (RegExp(r'\b(call|dial|phone|ring)\b').hasMatch(lower)) {
      intent = 'call_contact';
      spoken = offline
          ? 'I can help call someone when phone control is available. Who should I dial?'
          : 'I will look up that contact and open the dialer for you.';
    } else if (RegExp(r'\b(text|message|sms|whatsapp)\b').hasMatch(lower)) {
      intent = 'send_message';
      spoken = offline
          ? 'I can draft a message offline. Tell me who and what to send.'
          : 'I will open messages with your contact. Tell me who and what to send.';
    } else if (RegExp(
            r'\b(event|calendar|schedule|appointment|birthday|anniversary)\b')
        .hasMatch(lower)) {
      intent = 'schedule_event';
      spoken = offline
          ? 'Say something like "make an event for my birthday on 6th October 2026".'
          : 'I can add a calendar event. Say the title and date, like "birthday on 6th October 2026".';
    } else if (RegExp(r'\b(remember|note|save)\b').hasMatch(lower)) {
      intent = 'memory_capture';
      final snippet = _firstMemoryLine(memoryBlock);
      spoken = snippet != null
          ? 'Got it. I\'ll remember: $snippet'
          : 'Got it. I will remember the important part and skip private details.';
    } else if (RegExp(
            r'^(hi|hey|hello|yo|hiya|hello there|hey alter|hello alter|hi alter)\b')
        .hasMatch(lower)) {
      intent = 'conversation';
      spoken = name != null
          ? 'Hey $name! Good to hear you. How can I help?'
          : 'Hey! Good to hear you. How can I help?';
    } else {
      final recall = _recallFromMemory(text, memoryBlock);
      if (recall != null) {
        spoken = offline
            ? 'From what I have saved: $recall'
            : 'While I\'m offline from the cloud, from your memories: $recall';
      } else if (identityBlock.isNotEmpty &&
          RegExp(r'\b(who am i|about me|my identity)\b').hasMatch(lower)) {
        spoken = 'From what I\'ve learned: $identityBlock';
      }
    }

    return VoiceRuntimeResult(
      normalizedText: text,
      wakeWordDetected:
          lower.contains('hey alter') || lower.contains('hello alter'),
      inferredIntent: intent,
      intentConfidence: 0.55,
      spokenResponse: spoken,
      displayResponse: spoken,
      actionGraph: const [],
      experimentPlan: null,
      nextActions: const [],
      followUpQuestions: const [],
      signals: const [
        VoiceRuntimeSignal(
          title: 'Inference tier',
          status: 'ok',
          summary: 'heuristic',
          latencyMs: null,
        ),
      ],
    );
  }

  static String? _firstMemoryLine(String memoryBlock) {
    for (final line in memoryBlock.split('\n')) {
      final t = line.trim();
      if (t.startsWith('- ')) {
        final content = t.replaceFirst(RegExp(r'^- \[[^\]]+\]\s*'), '');
        if (content.isNotEmpty) return _truncate(content, 120);
      }
    }
    return null;
  }

  static String? _recallFromMemory(String query, String memoryBlock) {
    if (memoryBlock.isEmpty) return null;
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((t) => t.length > 2)
        .toList();
    if (tokens.isEmpty) return null;

    String? best;
    var bestScore = 0;
    for (final line in memoryBlock.split('\n')) {
      final hay = line.toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (hay.contains(t)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = line.trim().replaceFirst(RegExp(r'^- '), '');
      }
    }
    if (bestScore == 0 || best == null) return null;
    return _truncate(best, 200);
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }
}
