import 'package:flutter/services.dart';

class NativeAudioCaptureResult {
  const NativeAudioCaptureResult({
    required this.ok,
    required this.message,
    this.audioBase64 = '',
    this.filename = 'alter_sarvam_voice.m4a',
    this.contentType = 'audio/mp4',
    this.durationMs = 0,
  });

  factory NativeAudioCaptureResult.fromMap(Object? raw) {
    final map = raw is Map<Object?, Object?> ? raw : const <Object?, Object?>{};
    return NativeAudioCaptureResult(
      ok: map['ok'] == true,
      message: map['message']?.toString() ?? '',
      audioBase64: map['audioBase64']?.toString() ?? '',
      filename: map['filename']?.toString() ?? 'alter_sarvam_voice.m4a',
      contentType: map['contentType']?.toString() ?? 'audio/mp4',
      durationMs: map['durationMs'] is num
          ? (map['durationMs'] as num).round()
          : 0,
    );
  }

  final bool ok;
  final String message;
  final String audioBase64;
  final String filename;
  final String contentType;
  final int durationMs;
}

class NativeAudioBridge {
  const NativeAudioBridge();

  static const _channel = MethodChannel('alter.ai/audio_capture');

  Future<NativeAudioCaptureResult> startRecording() async {
    return _captureResult('startRecording');
  }

  Future<NativeAudioCaptureResult> stopRecording() async {
    return _captureResult('stopRecording');
  }

  Future<NativeAudioCaptureResult> cancelRecording() async {
    return _captureResult('cancelRecording');
  }

  Future<NativeAudioCaptureResult> playAudioBase64({
    required String audioBase64,
    String filename = 'alter_tts.wav',
  }) async {
    return _captureResult('playAudioBase64', {
      'audioBase64': audioBase64,
      'filename': filename,
    });
  }

  Future<NativeAudioCaptureResult> stopPlayback() async {
    return _captureResult('stopPlayback');
  }

  Future<NativeAudioCaptureResult> _captureResult(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      final raw = await _channel.invokeMethod<Object?>(method, args);
      return NativeAudioCaptureResult.fromMap(raw);
    } on MissingPluginException {
      return const NativeAudioCaptureResult(
        ok: false,
        message: 'Native audio is only available on Android.',
      );
    } catch (error) {
      return NativeAudioCaptureResult(ok: false, message: error.toString());
    }
  }
}
