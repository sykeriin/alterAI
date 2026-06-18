import '../profile/domain/user_profile.dart';

/// Shapes outbound messages/emails with channel-appropriate structure.
class ActionComposer {
  const ActionComposer._();

  static String polishMessage({
    required String intent,
    required String body,
    UserProfile? profile,
    String tone = 'friendly',
    String channel = 'whatsapp',
    int maxChars = 500,
  }) {
    final trimmed = body.trim();
    if (trimmed.isNotEmpty && trimmed.length >= 12) {
      return _cap(trimmed, maxChars);
    }

    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName.split(' ').first
        : '';
    final greeting = tone == 'formal' ? 'Hello' : 'Hi';
    final signOff = tone == 'formal'
        ? (name.isNotEmpty ? 'Best regards,\n$name' : 'Best regards')
        : (name.isNotEmpty ? 'Thanks,\n$name' : 'Thanks');

    final core = intent.trim().isNotEmpty
        ? intent.trim()
        : 'Just reaching out to connect.';
    final composed = '$greeting,\n\n$core\n\n$signOff';
    return _cap(composed, maxChars);
  }

  static ({String subject, String body}) polishEmail({
    required String intent,
    required String subject,
    required String body,
    UserProfile? profile,
    String tone = 'professional',
  }) {
    final sub = subject.trim().isNotEmpty
        ? subject.trim()
        : _subjectFromIntent(intent);
    final polishedBody = body.trim().isNotEmpty
        ? body.trim()
        : polishMessage(
            intent: intent,
            body: '',
            profile: profile,
            tone: tone,
            channel: 'email',
            maxChars: 2000,
          );
    return (subject: sub, body: polishedBody);
  }

  static String _subjectFromIntent(String intent) {
    final words = intent.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'Quick note';
    final preview = words.take(8).join(' ');
    return preview.length > 60 ? '${preview.substring(0, 57)}...' : preview;
  }

  static String _cap(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 3)}...';
  }
}
