import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/alter_gateway_config.dart';
import '../../../core/errors/alter_service_exception.dart';

final sarvamSttClientProvider = Provider<SarvamSttClient>((ref) {
  final client = SarvamSttClient();
  ref.onDispose(client.close);
  return client;
});

/// Online STT via ALTER gateway → Sarvam (when network available).
class SarvamSttClient {
  SarvamSttClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> transcribeBytes({
    required List<int> audioBytes,
    String locale = 'en-IN',
    String mimeType = 'audio/wav',
  }) async {
    final base64Audio = base64Encode(audioBytes);
    final response = await _client.post(
      Uri.parse('${AlterGatewayConfig.normalizedBaseUrl}/v1/multilingual/speech-to-text'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(<String, Object>{
        'audio_base64': base64Audio,
        'mime_type': mimeType,
        'language_code': locale,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlterServiceException(
        'STT HTTP ${response.statusCode}',
        kind: ServiceErrorKind.server,
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const SarvamSttException('Invalid STT response.');
    }
    final text = body['transcript']?.toString() ??
        body['text']?.toString() ??
        body['transcription']?.toString() ??
        '';
    if (text.trim().isEmpty) {
      throw const SarvamSttException('Empty transcript from Sarvam STT.');
    }
    return text.trim();
  }

  void close() => _client.close();
}

class SarvamSttException implements Exception {
  const SarvamSttException(this.message);
  final String message;
  @override
  String toString() => message;
}
