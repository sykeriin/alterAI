import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Permissioned OS intents and deep links for phone actions.
class DeviceActions {
  const DeviceActions();

  Future<String> _open(Uri uri, {bool external = true}) async {
    try {
      final ok = await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
      return ok ? 'ok' : 'could_not_open';
    } catch (e) {
      return 'error: $e';
    }
  }

  Future<String> callNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final r = await _open(Uri.parse('tel:$clean'));
    return r == 'ok'
        ? 'Opened the dialer for $clean. The user taps call to confirm.'
        : 'Could not open the dialer ($r).';
  }

  Future<String> sendMessage({
    required String app,
    required String number,
    required String text,
  }) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final enc = Uri.encodeComponent(text);
    final Uri uri;
    if (app.toLowerCase() == 'whatsapp') {
      uri = Uri.parse('https://wa.me/${clean.replaceAll('+', '')}?text=$enc');
    } else {
      uri = Uri.parse('sms:$clean?body=$enc');
    }
    final r = await _open(uri);
    return r == 'ok'
        ? 'Opened $app with the message prefilled. The user presses send.'
        : 'Could not open $app ($r).';
  }

  Future<String> composeEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final params = <String, String>{
      if (to.isNotEmpty) 'to': to,
      'subject': subject,
      'body': body,
    };
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: params,
    );
    final r = await _open(uri);
    return r == 'ok'
        ? 'Opened email composer to ${to.isEmpty ? 'draft' : to}.'
        : 'Could not open email ($r).';
  }

  Future<String> openUrl(String url) async {
    final fixed = url.startsWith('http') ? url : 'https://$url';
    final r = await _open(Uri.parse(fixed));
    return r == 'ok' ? 'Opened $fixed.' : 'Could not open the link ($r).';
  }

  Future<String> webSearch(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
    final r = await _open(uri);
    return r == 'ok'
        ? 'Opened a web search for "$query".'
        : 'Could not open the browser ($r).';
  }

  Future<String> addCalendarEvent({
    required String title,
    String details = '',
    String startIso = '',
  }) async {
    return insertCalendarEvent(
      title: title,
      notes: details,
      startIso: startIso,
    );
  }

  Future<String> insertCalendarEvent({
    required String title,
    String startIso = '',
    String endIso = '',
    String location = '',
    String notes = '',
  }) async {
    final start = DateTime.tryParse(startIso);
    final end = DateTime.tryParse(endIso) ??
        start?.add(const Duration(hours: 1));
    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      if (notes.isNotEmpty) 'details': notes,
      if (location.isNotEmpty) 'location': location,
    };
    if (start != null && end != null) {
      params['dates'] = '${_gcalStamp(start.toUtc())}/${_gcalStamp(end.toUtc())}';
    }
    final uri = Uri.https('calendar.google.com', '/calendar/render', params);
    final r = await _open(uri);
    return r == 'ok'
        ? 'Opened calendar with "$title" prefilled.'
        : 'Could not open calendar ($r).';
  }

  /// Best-effort calendar read — returns guidance when native read unavailable.
  Future<String> readUpcomingEvents({int daysAhead = 3}) async {
    return 'Calendar read requires device calendar permission. '
        'Open your calendar app or share your schedule. '
        '(Looking ahead $daysAhead days.)';
  }

  Future<String> findContact(String name) async {
    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final ok =
          permission == PermissionStatus.granted ||
          permission == PermissionStatus.limited;
      if (!ok) return 'Contacts permission was denied.';
      final all = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      final q = name.toLowerCase().trim();
      final matches = all
          .where((Contact c) => (c.displayName ?? '').toLowerCase().contains(q))
          .take(5)
          .toList();
      if (matches.isEmpty) return 'No contact found matching "$name".';
      return matches
          .map((Contact c) {
            final displayName = c.displayName ?? 'Unnamed contact';
            final num = c.phones.isNotEmpty
                ? c.phones.first.number
                : 'no number';
            return '$displayName: $num';
          })
          .join('; ');
    } catch (e) {
      return 'Could not read contacts: $e';
    }
  }

  String _gcalStamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}${two(dt.second)}Z';
  }
}
