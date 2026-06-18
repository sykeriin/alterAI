import 'package:flutter/foundation.dart';

import '../../features/voice/application/voice_backend_preference.dart';
import 'alter_service_exception.dart';

/// Maps any thrown error to a short, user-safe message (no URLs, codes, or JSON).
class UserFacingError implements Exception {
  UserFacingError(this.message, {this.technicalDetail});

  final String message;
  final String? technicalDetail;

  @override
  String toString() => message;

  static UserFacingError from(
    Object error, {
    VoiceBackend? backend,
  }) {
    if (error is UserFacingError) return error;

    if (error is String) {
      return fromSpeechOrRaw(error);
    }

    if (error is AlterServiceException) {
      return _fromKind(error.kind, backend: backend);
    }

    final raw = error.toString();
    if (kDebugMode) debugPrint('UserFacingError mapping: $raw');

    final lower = raw.toLowerCase();

    if (lower.contains('error_no_match') ||
        lower.contains('error_speech') ||
        RegExp(r'\berror_[a-z_]+\b').hasMatch(lower)) {
      return fromSpeechOrRaw(raw);
    }

    if (_looksLikeNetwork(lower)) {
      return UserFacingError(
        'Can\'t reach ALTER right now. Check your internet connection.',
        technicalDetail: raw,
      );
    }

    if (lower.contains('sign in') ||
        lower.contains('not signed') ||
        lower.contains('session') && lower.contains('null')) {
        return UserFacingError(
          'Unlock ALTER and add your OpenAI key in Settings to use Cloud AI.',
          technicalDetail: raw,
        );
    }

    if (lower.contains('429') || lower.contains('rate limit') || lower.contains('quota')) {
      return UserFacingError(
        'Cloud AI is busy. Try again in a minute or switch backend in Settings.',
        technicalDetail: raw,
      );
    }

    if (lower.contains('on-device') ||
        lower.contains('not installed') ||
        lower.contains('not ready')) {
      return UserFacingError(
        'Voice AI isn\'t ready. Check your backend in Settings.',
        technicalDetail: raw,
      );
    }

    if (lower.contains('gateway') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504')) {
      return UserFacingError(
        'ALTER cloud service is offline. Try another backend in Settings.',
        technicalDetail: raw,
      );
    }

    if (lower.contains('microphone') ||
        lower.contains('record_audio') ||
        lower.contains('speech')) {
      return UserFacingError(
        'Microphone isn\'t available. Check permissions in Settings.',
        technicalDetail: raw,
      );
    }

    if (backend != null) {
      return backendUnavailable(backend, technicalDetail: raw);
    }

    return UserFacingError(
      'Something went wrong. Try again or switch your voice backend in Settings.',
      technicalDetail: raw,
    );
  }

  /// Maps Android/iOS speech recognizer codes (e.g. `error_no_match`) to plain copy.
  static UserFacingError fromSpeechOrRaw(String raw) {
    final code = raw.trim().toLowerCase().replaceAll('-', '_');
    if (code.isEmpty) {
      return UserFacingError(
        'Didn\'t catch that — tap and speak again.',
        technicalDetail: raw,
      );
    }

    if (code.contains('no_match') || code == 'nomatch') {
      return UserFacingError(
        'Didn\'t catch that — tap and speak again.',
        technicalDetail: raw,
      );
    }
    if (code.contains('speech_timeout') || code.contains('timeout')) {
      return UserFacingError(
        'I didn\'t hear anything. Tap the orb and try again.',
        technicalDetail: raw,
      );
    }
    if (code.contains('audio') || code.contains('recording')) {
      return UserFacingError(
        'Microphone problem — check that ALTER can use your mic.',
        technicalDetail: raw,
      );
    }
    if (code.contains('permission') || code.contains('insufficient')) {
      return UserFacingError(
        'Microphone permission required — enable in Settings.',
        technicalDetail: raw,
      );
    }
    if (code.contains('network')) {
      return UserFacingError(
        'Speech needs internet on this device. Check your connection.',
        technicalDetail: raw,
      );
    }
    if (code.contains('busy') || code.contains('recognizer')) {
      return UserFacingError(
        'Speech is busy. Wait a moment and tap to speak again.',
        technicalDetail: raw,
      );
    }
    if (code.contains('language') || code.contains('locale')) {
      return UserFacingError(
        'This language isn\'t supported for voice input on your phone.',
        technicalDetail: raw,
      );
    }
    if (code.startsWith('error_') || RegExp(r'^[a-z]+_[a-z_]+$').hasMatch(code)) {
      return UserFacingError(
        'Didn\'t catch that — tap and speak again.',
        technicalDetail: raw,
      );
    }

    return UserFacingError(sanitize(raw), technicalDetail: raw);
  }

  static UserFacingError backendUnavailable(
    VoiceBackend backend, {
    String? technicalDetail,
  }) {
    switch (backend) {
      case VoiceBackend.onDevice:
        return UserFacingError(
          'Gemma isn\'t loaded. Open Settings → EDGE and tap Load into RAM.',
          technicalDetail: technicalDetail,
        );
      case VoiceBackend.cloudAi:
        return UserFacingError(
          'Cloud AI isn\'t available right now. Check your connection or switch backend in Settings.',
          technicalDetail: technicalDetail,
        );
      case VoiceBackend.gateway:
        return UserFacingError(
          'ALTER Gateway is offline. Try Cloud AI in Settings.',
          technicalDetail: technicalDetail,
        );
    }
  }

  static UserFacingError _fromKind(
    ServiceErrorKind kind, {
    VoiceBackend? backend,
  }) {
    switch (kind) {
      case ServiceErrorKind.network:
        return UserFacingError(
          'Can\'t reach ALTER right now. Check your internet connection.',
        );
      case ServiceErrorKind.auth:
        return UserFacingError(
          'Unlock ALTER and add your OpenAI key in Settings to use Cloud AI.',
        );
      case ServiceErrorKind.quota:
        return UserFacingError(
          'Cloud AI is busy. Try again in a minute or switch backend in Settings.',
        );
      case ServiceErrorKind.notConfigured:
        return UserFacingError(
          'This service isn\'t set up yet. Check Settings.',
        );
      case ServiceErrorKind.notFound:
        return UserFacingError(
          'Cloud AI is not set up yet. Add your key in Settings or switch backend.',
        );
      case ServiceErrorKind.server:
        if (backend == VoiceBackend.gateway) {
          return UserFacingError(
            'ALTER Gateway is offline. Try another backend in Settings.',
          );
        }
        return UserFacingError(
          'ALTER service is temporarily unavailable. Try again shortly.',
        );
      case ServiceErrorKind.parse:
        return UserFacingError(
          'Got an unexpected response. Try again.',
        );
      case ServiceErrorKind.permission:
        return UserFacingError(
          'Permission required. Open Settings → Permission hub.',
        );
      case ServiceErrorKind.unknown:
        if (backend != null) return backendUnavailable(backend);
        return UserFacingError(
          'Something went wrong. Try again or switch your voice backend in Settings.',
        );
    }
  }

  static bool _looksLikeNetwork(String lower) {
    return lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated');
  }

  static String sanitize(String? text) {
    if (text == null || text.isEmpty) return '';
    var s = text.trim();
    final lower = s.toLowerCase();
    if (lower.startsWith('error_') || RegExp(r'^[a-z]+_[a-z_0-9]+$').hasMatch(lower)) {
      return fromSpeechOrRaw(s).message;
    }
    s = s.replaceAll(RegExp(r'https?://\S+'), '');
    s = s.replaceAll(RegExp(r'\b\d{3}\b'), '');
    s = s.replaceAll(RegExp(r'\{.*\}'), '');
    s = s.replaceAll(RegExp(r'Exception:\s*'), '');
    s = s.replaceAll(RegExp(r'StateError:\s*'), '');
    s = s.replaceAll(RegExp(r'Gateway error:\s*'), '');
    s = s.trim();
    if (s.length < 8 || lower.contains('error_')) {
      return 'Something went wrong. Try again or switch your voice backend in Settings.';
    }
    return s;
  }
}
