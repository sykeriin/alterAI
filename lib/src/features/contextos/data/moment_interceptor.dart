import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contextos_models.dart';
import '../domain/moment.dart';

final momentInterceptorProvider = Provider<MomentInterceptor>(
  (ref) => const MomentInterceptor(),
);

/// The single entry point for every captured moment. Each surface has its own
/// adapter so real OS hooks (notification listener, share target, camera, mic)
/// can be wired in later without changing anything downstream — they just need
/// to produce a [Moment].
class MomentInterceptor {
  const MomentInterceptor();

  // Quick on-device sensitivity scan (no network) to set the privacy level.
  static final _sensitive = RegExp(
    r'\b(otp|cvv|password|pin|aadhaar|pan|card\s*number|account\s*number|upi)\b',
    caseSensitive: false,
  );

  Moment _build({
    required MomentSource surface,
    required String sourceType,
    required String content,
  }) {
    final now = DateTime.now();
    final privacy = _sensitive.hasMatch(content)
        ? PrivacyLevel.sensitive
        : PrivacyLevel.normal;
    return Moment(
      id: 'm_${now.microsecondsSinceEpoch}',
      sourceSurface: surface,
      sourceType: sourceType,
      rawContent: content.trim(),
      timestamp: now,
      deviceContext: _deviceContext(now, surface),
      privacyLevel: privacy,
    );
  }

  Map<String, String> _deviceContext(DateTime now, MomentSource surface) {
    final h = now.hour;
    final partOfDay = h < 6
        ? 'night'
        : h < 12
        ? 'morning'
        : h < 17
        ? 'afternoon'
        : h < 21
        ? 'evening'
        : 'night';
    return {
      'surface': surface.label,
      'time_of_day': partOfDay,
      'network': surface == MomentSource.call ? 'cellular' : 'wifi',
      'locale': 'en-IN',
      'edge': 'on-device first-pass',
    };
  }

  // --- Surface adapters ---------------------------------------------------

  Moment fromNotification(String text) => _build(
    surface: MomentSource.notification,
    sourceType: 'sms',
    content: text,
  );

  Moment fromShare(String text) {
    final isLink = RegExp(r'https?://').hasMatch(text);
    return _build(
      surface: MomentSource.shareSheet,
      sourceType: isLink ? 'link' : 'text',
      content: text,
    );
  }

  Moment fromCameraText(String ocrText, {bool isQr = false}) => _build(
    surface: isQr ? MomentSource.qr : MomentSource.camera,
    sourceType: isQr ? 'qr' : 'image_text',
    content: ocrText,
  );

  Moment fromVoiceTranscript(String transcript, {bool isCall = false}) =>
      _build(
        surface: isCall ? MomentSource.call : MomentSource.mic,
        sourceType: 'transcript',
        content: transcript,
      );

  Moment fromInstall(String permissionScreen) => _build(
    surface: MomentSource.install,
    sourceType: 'permissions',
    content: permissionScreen,
  );

  Moment fromDayContext(String summary) => _build(
    surface: MomentSource.notification,
    sourceType: 'day',
    content: summary,
  );

  Moment fromManual(String text) =>
      _build(surface: MomentSource.manual, sourceType: 'text', content: text);

  /// Generic intake when only the surface is known (used by the capture UI).
  Moment intake(MomentSource surface, String text) {
    switch (surface) {
      case MomentSource.notification:
        return fromNotification(text);
      case MomentSource.shareSheet:
        return fromShare(text);
      case MomentSource.camera:
        return fromCameraText(text);
      case MomentSource.qr:
        return fromCameraText(text, isQr: true);
      case MomentSource.mic:
        return fromVoiceTranscript(text);
      case MomentSource.call:
        return fromVoiceTranscript(text, isCall: true);
      case MomentSource.install:
        return fromInstall(text);
      case MomentSource.payment:
        return fromCameraText(text, isQr: true);
      case MomentSource.screenshot:
        return fromShare(text);
      case MomentSource.sms:
        return _build(surface: surface, sourceType: 'sms', content: text);
      case MomentSource.whatsapp:
        return _build(surface: surface, sourceType: 'chat', content: text);
      case MomentSource.social:
        return _build(surface: surface, sourceType: 'social', content: text);
      case MomentSource.notes:
        return _build(surface: surface, sourceType: 'note', content: text);
      case MomentSource.photos:
        return _build(
          surface: surface,
          sourceType: 'photo_context',
          content: text,
        );
      case MomentSource.contacts:
        return _build(
          surface: surface,
          sourceType: 'contact_context',
          content: text,
        );
      case MomentSource.calendar:
        return _build(
          surface: surface,
          sourceType: 'calendar_context',
          content: text,
        );
      case MomentSource.email:
        return _build(surface: surface, sourceType: 'email', content: text);
      case MomentSource.browser:
        return _build(
          surface: surface,
          sourceType: 'browser_context',
          content: text,
        );
      case MomentSource.location:
        return _build(
          surface: surface,
          sourceType: 'location_context',
          content: text,
        );
      case MomentSource.files:
        return _build(
          surface: surface,
          sourceType: 'file_context',
          content: text,
        );
      case MomentSource.manual:
        return fromManual(text);
    }
  }
}
