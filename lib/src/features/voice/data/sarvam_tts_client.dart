import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../profile/application/profile_provider.dart';

const _sarvamKeyPref = 'alter_sarvam_api_key';
const _sarvamStreamUrl = 'https://api.sarvam.ai/text-to-speech/stream';

final sarvamTtsClientProvider = Provider<SarvamTtsClient>((ref) {
  final client = SarvamTtsClient(ref);
  ref.onDispose(client.dispose);
  return client;
});

/// Sarvam Bulbul TTS via direct REST API (BYOK from profile or prefs).
class SarvamTtsClient {
  SarvamTtsClient(this._ref);

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  final http.Client _http = http.Client();
  bool _loggedFallback = false;

  Future<void> dispose() async {
    await _player.dispose();
    _http.close();
  }

  static Future<void> saveByokKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_sarvamKeyPref);
    } else {
      await prefs.setString(_sarvamKeyPref, key.trim());
    }
  }

  static Future<String?> loadByokKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sarvamKeyPref);
  }

  Future<String?> _resolveApiKey() async {
    final profileKey =
        _ref.read(userProfileProvider).asData?.value?.sarvamKey.trim();
    if (profileKey != null && profileKey.isNotEmpty) return profileKey;
    return loadByokKey();
  }

  Future<void> speak(
    String text, {
    String targetLanguageCode = 'en-IN',
    String speaker = 'shubh',
    required Future<void> Function(String) onFlutterTtsFallback,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      final apiKey = await _resolveApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Sarvam API key not configured');
      }

      final res = await _http
          .post(
            Uri.parse(_sarvamStreamUrl),
            headers: {
              'Content-Type': 'application/json',
              'api-subscription-key': apiKey,
            },
            body: jsonEncode({
              'text':
                  trimmed.length > 2500 ? trimmed.substring(0, 2500) : trimmed,
              'target_language_code': targetLanguageCode,
              'speaker': speaker,
              'model': 'bulbul:v3',
              'speech_sample_rate': '24000',
              'output_audio_codec': 'mp3',
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw Exception('Sarvam TTS failed (${res.statusCode})');
      }

      final bytes = res.bodyBytes;
      if (bytes.isEmpty) throw Exception('Empty TTS audio');

      await _player.stop();
      await _player.setAudioSource(_BytesAudioSource(bytes));
      await _player.play();
      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
    } catch (e) {
      if (!_loggedFallback && kDebugMode) {
        _loggedFallback = true;
        debugPrint('Sarvam TTS unavailable, using flutter_tts: $e');
      }
      await onFlutterTtsFallback(trimmed);
    }
  }

  Stream<double> get amplitudeStream =>
      _player.positionStream.map((_) => _player.volume);
}

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
