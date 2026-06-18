class WakeWordMatch {
  const WakeWordMatch({
    required this.detected,
    required this.original,
    required this.command,
  });

  final bool detected;
  final String original;
  final String command;

  bool get hasCommand => command.trim().isNotEmpty;

  String get runtimeTranscript =>
      hasCommand ? 'Hey Alter, ${command.trim()}' : 'Hey Alter';
}

class WakeWord {
  const WakeWord._();

  static final RegExp _wakePattern = RegExp(
    r'\b(?:hey|hi|ok|okay)\s+alter\b[\s,.:;-]*',
    caseSensitive: false,
  );

  static final RegExp _directAlterPattern = RegExp(
    r'^\s*alter\b[\s,.:;-]*',
    caseSensitive: false,
  );

  static WakeWordMatch parse(String transcript) {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty) {
      return const WakeWordMatch(detected: false, original: '', command: '');
    }

    final wake = _wakePattern.firstMatch(cleaned);
    if (wake != null) {
      return WakeWordMatch(
        detected: true,
        original: cleaned,
        command: cleaned.substring(wake.end).trim(),
      );
    }

    final direct = _directAlterPattern.firstMatch(cleaned);
    if (direct != null) {
      return WakeWordMatch(
        detected: true,
        original: cleaned,
        command: cleaned.substring(direct.end).trim(),
      );
    }

    return WakeWordMatch(detected: false, original: cleaned, command: cleaned);
  }
}
