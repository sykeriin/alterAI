/// Minimises and redacts context **before it leaves the device** for cloud
/// reasoning — a privacy guard plus a context budget. Redacts obvious PII
/// patterns (emails, phone numbers, long digit runs like cards/IDs) and caps
/// the length so only the minimum needed context is sent to the cloud.
class ContextPrivacyFilter {
  const ContextPrivacyFilter({this.maxChars = 4000});

  /// Hard cap on how much context is shipped to the cloud per turn.
  final int maxChars;

  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _longNumber = RegExp(r'\b\d{12,19}\b');
  static final _phone = RegExp(r'\+?\d[\d\s().-]{7,}\d');

  String filter(String context) {
    if (context.isEmpty) return context;
    var s = context
        .replaceAll(_email, '[redacted-email]')
        .replaceAll(_longNumber, '[redacted-number]')
        .replaceAll(_phone, '[redacted-phone]');
    if (s.length > maxChars) {
      s = '${s.substring(0, maxChars)}…';
    }
    return s;
  }
}
