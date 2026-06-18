import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/moment.dart';

final contextEngineProvider = Provider<ContextEngine>(
  (ref) => const ContextEngine(),
);

/// Extracts structured understanding from a moment. The local pass runs fully
/// on-device with deterministic heuristics; the cloud pass (merged later via
/// [ContextExtraction.mergeCloud]) deepens it. Surfacing this distinctly is
/// what makes ALTER feel like a context layer rather than a chatbot.
class ContextEngine {
  const ContextEngine();

  static final _url = RegExp(
    r'https?://[^\s]+|\b[\w-]+\.(?:top|xyz|live|info|ru|cn|link)\b',
    caseSensitive: false,
  );
  static final _shortener = RegExp(
    r'\b(bit\.ly|tinyurl|t\.me|cutt\.ly|rb\.gy|is\.gd)\b',
    caseSensitive: false,
  );
  static final _money = RegExp(
    r'(₹|rs\.?\s*\d|inr|\$\d|pay|transfer|fee|charge|deposit)',
    caseSensitive: false,
  );
  static final _identity = RegExp(
    r'\b(otp|kyc|card|cvv|pin|password|aadhaar|pan|verify)\b',
    caseSensitive: false,
  );
  static final _permission = RegExp(
    r'\b(install|apk|accessibility|read\s+sms|read\s+contacts|call\s+logs|unknown\s+source|display\s+over)\b',
    caseSensitive: false,
  );
  static final _upi = RegExp(
    r'\b[\w.-]+@(?:okaxis|oksbi|okhdfcbank|ybl|paytm|upi|ibl)\b',
    caseSensitive: false,
  );
  static final _urgency = RegExp(
    r'\b(urgent|immediately|now|expire|within|suspend|block|deactivat|last\s+chance|hurry)\b',
    caseSensitive: false,
  );
  static final _deadline = RegExp(
    r'\b(today|tomorrow|tonight|in\s+\d+\s*(min|hour|day)s?|by\s+\d{1,2}(:\d{2})?\s*(am|pm)?|\d{1,2}\s*(min|hour)s?)\b',
    caseSensitive: false,
  );
  static final _entity = RegExp(
    r'\b(?:HDFC|SBI|ICICI|Axis|Amazon|Flipkart|Paytm|Google|Apple|FedEx|DHL|BlueDart|India\s?Post|UPI|6E|IndiGo|Uber|Ola)\b',
    caseSensitive: false,
  );
  static final _action = RegExp(
    r'\b(click|tap|pay|scan|share|install|verify|approve|confirm|send|call|reply|download|enter|submit)\b',
    caseSensitive: false,
  );

  ContextExtraction extractLocal(Moment moment) {
    final text = moment.rawContent;
    final lower = text.toLowerCase();

    double scoreOf(RegExp re, {double per = 0.5, double cap = 1}) {
      final n = re.allMatches(lower).length;
      return (n * per).clamp(0, cap).toDouble();
    }

    final risks = <String, double>{
      'Money': scoreOf(_money, per: 0.4),
      'Identity': scoreOf(_identity, per: 0.45),
      'Permission': _permission.hasMatch(lower) ? 0.85 : 0,
      'Link / domain':
          (_shortener.hasMatch(lower) ? 0.8 : 0) +
          (_url.hasMatch(text) ? 0.4 : 0),
      'QR / payment':
          (_upi.hasMatch(lower) ? 0.8 : 0) +
          (moment.sourceType == 'qr' ? 0.4 : 0),
      'Location':
          RegExp(
            r'\b(traffic|delay|eta|cab|airport|commute|boarding)\b',
            caseSensitive: false,
          ).hasMatch(lower)
          ? 0.45
          : 0,
      'Urgency': scoreOf(_urgency, per: 0.4),
    }.map((k, v) => MapEntry(k, v.clamp(0, 1).toDouble()));

    final entities = _entity
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final actionMatch = _action.firstMatch(lower)?.group(0) ?? '';
    final requestedAction = actionMatch.isEmpty
        ? ''
        : '${actionMatch[0].toUpperCase()}${actionMatch.substring(1)} requested';

    final deadline = _deadline.firstMatch(lower)?.group(0) ?? '';

    final missing = <String>[];
    if (_url.hasMatch(text) && entities.isEmpty) {
      missing.add('Who actually owns this link / sender?');
    }
    if (risks['Money']! > 0 && !_identity.hasMatch(lower)) {
      missing.add('Is this an official, verified payee?');
    }
    if (moment.sourceType == 'qr') {
      missing.add('What account will the QR actually credit?');
    }

    final confidence =
        0.45 + (risks.values.fold<double>(0, (a, b) => a + b) * 0.06);

    return ContextExtraction(
      entities: entities,
      requestedAction: requestedAction,
      deadline: deadline,
      risks: risks,
      sensitiveDataRequest: _identity.hasMatch(lower),
      missingInfo: missing,
      confidence: confidence.clamp(0, 0.85),
      cloudEnriched: false,
    );
  }
}
