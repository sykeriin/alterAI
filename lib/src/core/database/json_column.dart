import 'dart:convert';

List<String> decodeStringList(Object? raw) {
  if (raw == null) return const [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }
  return const [];
}

Map<String, dynamic> decodeJsonMap(Object? raw) {
  if (raw == null) return const {};
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

String encodeStringList(List<String> values) => jsonEncode(values);

String encodeJsonMap(Map<String, dynamic> values) => jsonEncode(values);

bool dbBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is int) return raw != 0;
  if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
  return false;
}

int dbBoolInt(bool value) => value ? 1 : 0;
