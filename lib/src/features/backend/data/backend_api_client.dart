import 'dart:convert';

import 'package:http/http.dart' as http;

const _backendTimeout = Duration(seconds: 4);

class BackendApiClient {
  BackendApiClient({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<Map<String, dynamic>?> getJson(String path) async {
    if (!isConfigured) return null;
    final response = await _client
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_backendTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>?> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    if (!isConfigured) return null;
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_backendTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>?> patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    if (!isConfigured) return null;
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl$path'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_backendTimeout);
    return _decode(response);
  }

  void close() => _client.close();

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const BackendApiException('Backend returned invalid JSON.');
    }
    return decoded;
  }
}

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
