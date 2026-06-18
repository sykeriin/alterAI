import 'package:speech_to_text/speech_to_text.dart';

/// Maps profile/gateway locales to a [SpeechToText] locale the OS actually supports.
class VoiceSttHelper {
  const VoiceSttHelper._();

  /// Prefer Indian English, then US English, then any English locale.
  static Future<String> resolveLocale(
    SpeechToText speech, {
    String preferred = 'en-IN',
  }) async {
    final locales = await speech.locales();
    if (locales.isEmpty) return 'en_US';

    final ids = locales.map((l) => l.localeId).toList();
    final normalized = preferred.replaceAll('-', '_');

    if (ids.contains(normalized)) return normalized;
    if (ids.contains(preferred)) return preferred;

    final lower = preferred.toLowerCase();
    for (final id in ids) {
      if (id.toLowerCase() == lower || id.toLowerCase().replaceAll('-', '_') == normalized.toLowerCase()) {
        return id;
      }
    }

    for (final id in ids) {
      if (id.startsWith('en_IN') || id.startsWith('en-IN')) return id;
    }
    for (final id in ids) {
      if (id.startsWith('en_US') || id.startsWith('en-US')) return id;
    }
    for (final id in ids) {
      if (id.toLowerCase().startsWith('en')) return id;
    }
    return locales.first.localeId;
  }
}
