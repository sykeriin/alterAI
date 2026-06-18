import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/life_feed_models.dart';

class LifeFeedApiClient {
  LifeFeedApiClient({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<LifeFeedSnapshot?> fetch({required String userId}) async {
    if (_baseUrl.isEmpty) return null;
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/life-feed?user_id=$userId'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LifeFeedSnapshot.fromJson(json);
  }

  void close() => _client.close();
}
