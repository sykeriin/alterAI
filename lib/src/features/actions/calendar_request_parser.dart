/// Parses natural-language calendar requests like
/// "make an event for my birthday on 6th oct 2026".
class CalendarRequestParser {
  const CalendarRequestParser._();

  static const _months = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static bool looksLikeCalendarRequest(String text) {
    final lower = text.toLowerCase();
    final hasAction = RegExp(
      r'\b(make|create|add|schedule|set|book|put|plan|remind)\b',
    ).hasMatch(lower);
    final hasCalendarNoun = RegExp(
      r'\b(event|calendar|appointment|meeting|reminder|birthday|anniversary)\b',
    ).hasMatch(lower);
    final hasDate = _parseDate(lower) != null;
    return hasDate && (hasCalendarNoun || hasAction);
  }

  static CalendarRequest? tryParse(String text) {
    final trimmed = _normalizeStt(text.trim());
    if (trimmed.isEmpty) return null;
    if (!looksLikeCalendarRequest(trimmed)) return null;

    final lower = trimmed.toLowerCase();
    final date = _parseDate(lower);
    if (date == null) return null;

    final title = _extractTitle(trimmed, lower);
    final start = DateTime(date.year, date.month, date.day, 9);
    final end = start.add(const Duration(hours: 1));

    return CalendarRequest(
      title: title,
      startIso: start.toIso8601String(),
      endIso: end.toIso8601String(),
      notes: trimmed,
    );
  }

  static DateTime? _parseDate(String lower) {
    final dayMonthYear = RegExp(
      r'(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?'
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|'
      r'dec(?:ember)?)'
      r'(?:\s+(?:of\s+)?(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (dayMonthYear != null) {
      final day = int.tryParse(dayMonthYear.group(1)!);
      final month = _months[dayMonthYear.group(2)!.toLowerCase()];
      final year =
          int.tryParse(dayMonthYear.group(3) ?? '') ?? DateTime.now().year;
      if (day != null && month != null) {
        return _safeDate(year, month, day);
      }
    }

    final monthDayYear = RegExp(
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      r'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|'
      r'dec(?:ember)?)\s+'
      r'(\d{1,2})(?:st|nd|rd|th)?'
      r'(?:\s+(?:of\s+)?(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (monthDayYear != null) {
      final month = _months[monthDayYear.group(1)!.toLowerCase()];
      final day = int.tryParse(monthDayYear.group(2)!);
      final year =
          int.tryParse(monthDayYear.group(3) ?? '') ?? DateTime.now().year;
      if (day != null && month != null) {
        return _safeDate(year, month, day);
      }
    }

    final slash = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(lower);
    if (slash != null) {
      final a = int.tryParse(slash.group(1)!);
      final b = int.tryParse(slash.group(2)!);
      var year = int.tryParse(slash.group(3)!);
      if (a != null && b != null) {
        if (year != null && year < 100) year += 2000;
        year ??= DateTime.now().year;
        final day = a > 12 ? a : b;
        final month = a > 12 ? b : a;
        return _safeDate(year, month, day);
      }
    }

    final isoish = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(lower);
    if (isoish != null) {
      final year = int.tryParse(isoish.group(1)!);
      final month = int.tryParse(isoish.group(2)!);
      final day = int.tryParse(isoish.group(3)!);
      if (year != null && month != null && day != null) {
        return _safeDate(year, month, day);
      }
    }

    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static String _extractTitle(String original, String lower) {
    final forMatch = RegExp(
      r'(?:event|appointment|meeting|reminder|calendar\s+event)\s+for\s+(.+?)\s+on\b',
      caseSensitive: false,
    ).firstMatch(original);
    if (forMatch != null) {
      return _titleCase(forMatch.group(1)!.trim());
    }

    final forShort = RegExp(
      r'\bfor\s+(.+?)\s+on\b',
      caseSensitive: false,
    ).firstMatch(original);
    if (forShort != null) {
      return _titleCase(forShort.group(1)!.trim());
    }

    if (lower.contains('birthday')) {
      if (RegExp(r'\bmy\b').hasMatch(lower)) return 'My Birthday';
      final name = RegExp(
        r"(\w+)'s\s+birthday",
        caseSensitive: false,
      ).firstMatch(lower);
      if (name != null) return "${_titleCase(name.group(1)!)}'s Birthday";
      return 'Birthday';
    }

    if (lower.contains('anniversary')) return 'Anniversary';

    final named = RegExp(
      r'(?:called|named|titled)\s+(.+?)(?:\s+on\b|$)',
      caseSensitive: false,
    ).firstMatch(original);
    if (named != null) return _titleCase(named.group(1)!.trim());

    return 'Event';
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static String _normalizeStt(String text) {
    var out = text;
    for (final entry in _sttReplacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }

  static final _sttReplacements = <RegExp, String>{
    RegExp(r'\bmt\b', caseSensitive: false): 'my',
    RegExp(r'\bbirtheday\b', caseSensitive: false): 'birthday',
    RegExp(r'\bbirth\s*day\b', caseSensitive: false): 'birthday',
    RegExp(r'\bcalender\b', caseSensitive: false): 'calendar',
    RegExp(r'\boctober\b', caseSensitive: false): 'october',
  };
}

class CalendarRequest {
  const CalendarRequest({
    required this.title,
    required this.startIso,
    required this.endIso,
    this.notes = '',
  });

  final String title;
  final String startIso;
  final String endIso;
  final String notes;
}
