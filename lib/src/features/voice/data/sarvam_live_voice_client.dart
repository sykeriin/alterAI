import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'native_audio_capture.dart';

const _sarvamLiveVoiceTimeout = Duration(seconds: 45);

class SarvamLiveVoiceClient {
  SarvamLiveVoiceClient({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<SarvamSttResult> transcribe(
    NativeAudioCaptureResult audio, {
    String languageCode = 'unknown',
    String mode = 'transcribe',
  }) async {
    final bytes = base64Decode(audio.audioBase64);
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/v1/multilingual/speech-to-text'),
          )
          ..fields['language_code'] = languageCode
          ..fields['mode'] = mode
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: audio.filename,
              contentType: MediaType.parse(audio.contentType),
            ),
          );
    final streamed = await _client
        .send(request)
        .timeout(_sarvamLiveVoiceTimeout);
    final response = await http.Response.fromStream(streamed);
    final json = _decode(response);
    return SarvamSttResult.fromJson(json);
  }

  Future<SarvamTtsResult> synthesize({
    required String text,
    required String targetLanguageCode,
    String speaker = 'shubh',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/v1/multilingual/text-to-speech'),
          headers: const <String, String>{
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(<String, Object?>{
            'text': text,
            'target_language_code': targetLanguageCode,
            'speaker': speaker,
            'speech_sample_rate': 24000,
          }),
        )
        .timeout(_sarvamLiveVoiceTimeout);
    return SarvamTtsResult.fromJson(_decode(response));
  }

  void close() => _client.close();

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SarvamLiveVoiceException(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SarvamLiveVoiceException('Backend returned invalid JSON.');
    }
    return decoded;
  }
}

class SarvamSttResult {
  const SarvamSttResult({
    required this.transcript,
    required this.provider,
    required this.sarvamEnabled,
    required this.fallback,
    required this.languageCode,
    required this.error,
  });

  factory SarvamSttResult.fromJson(Map<String, dynamic> json) {
    return SarvamSttResult(
      transcript: _string(json['transcript']),
      provider: _string(json['provider'], fallback: 'alter-local'),
      sarvamEnabled: json['sarvam_enabled'] == true,
      fallback: json['fallback'] == true,
      languageCode: _string(json['language_code'], fallback: 'unknown'),
      error: _string(json['error']),
    );
  }

  final String transcript;
  final String provider;
  final bool sarvamEnabled;
  final bool fallback;
  final String languageCode;
  final String error;
}

class SarvamTtsResult {
  const SarvamTtsResult({
    required this.audioBase64,
    required this.provider,
    required this.sarvamEnabled,
    required this.fallback,
    required this.targetLanguageCode,
    required this.error,
  });

  factory SarvamTtsResult.fromJson(Map<String, dynamic> json) {
    return SarvamTtsResult(
      audioBase64: _string(json['audio_base64']),
      provider: _string(json['provider'], fallback: 'alter-local'),
      sarvamEnabled: json['sarvam_enabled'] == true,
      fallback: json['fallback'] == true,
      targetLanguageCode: _string(
        json['target_language_code'],
        fallback: 'en-IN',
      ),
      error: _string(json['error']),
    );
  }

  final String audioBase64;
  final String provider;
  final bool sarvamEnabled;
  final bool fallback;
  final String targetLanguageCode;
  final String error;
}

class SarvamLiveVoiceException implements Exception {
  const SarvamLiveVoiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _string(Object? raw, {String fallback = ''}) {
  return raw is String && raw.isNotEmpty ? raw : fallback;
}
