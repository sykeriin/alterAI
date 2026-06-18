import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to OpenAI, preferring the secure `openai-chat` Supabase Edge Function
/// (platform key stays server-side, usage is metered).
///
/// Fallback: if the function isn't deployed yet (404 / unreachable) **and** the
/// user has set their own key ([byokKey]), the call goes directly to OpenAI
/// with that key. A user's own key on their own device is safe to use directly;
/// the shared platform key is never exposed because the platform-key path
/// always requires the function.
class OpenAIService {
  OpenAIService({SupabaseClient? client, this.byokKey})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String? byokKey;

  bool get _hasByok => byokKey != null && byokKey!.isNotEmpty;

  Future<String> chat({
    required List<Map<String, dynamic>> messages,
    String model = 'gpt-4o-mini',
    double temperature = 0.7,
    int maxTokens = 1200,
    bool jsonMode = false,
  }) async {
    final body = <String, dynamic>{
      'messages': messages,
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'json_mode': jsonMode,
      if (_hasByok) 'byok_key': byokKey,
    };

    try {
      final response = await _client.functions.invoke(
        'openai-chat',
        body: body,
      );
      final data = response.data;
      if (data is! Map) throw const FormatException('Unexpected AI response.');
      final content = data['content'];
      if (content is! String || content.isEmpty) {
        final err = data['error'];
        throw Exception(err is String ? err : 'AI returned an empty response.');
      }
      return content;
    } on FunctionException catch (e) {
      // Function exists but returned an error (quota, bad key, etc.) — surface
      // it. Only fall back to a direct call when the function is *absent*.
      final notDeployed = e.status == 404;
      if (notDeployed && _hasByok) {
        return _directChat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
          jsonMode: jsonMode,
        );
      }
      if (notDeployed) {
        throw Exception(
          'AI service not deployed yet. Add your OpenAI key in Settings to use '
          'ALTER now, or deploy the openai-chat Edge Function.',
        );
      }
      throw Exception(
        _messageFromDetails(e.details) ?? 'AI request failed (${e.status}).',
      );
    } catch (e) {
      // Network-level failure reaching the function. Fall back if we can.
      if (_hasByok) {
        return _directChat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
          jsonMode: jsonMode,
        );
      }
      throw Exception('Could not reach the AI service. Check your connection.');
    }
  }

  /// Semantic memory: returns one embedding vector per input string, in order.
  /// Returns an empty list on any failure so callers can fall back to keyword
  /// search instead of breaking.
  Future<List<List<double>>> embed(List<String> inputs) async {
    if (inputs.isEmpty) return const [];
    final body = <String, dynamic>{
      'embed': inputs,
      if (_hasByok) 'byok_key': byokKey,
    };
    try {
      final response = await _client.functions.invoke('openai-chat', body: body);
      final data = response.data;
      if (data is! Map) return const [];
      final raw = data['embeddings'];
      if (raw is! List) return const [];
      return raw
          .map<List<double>>(
            (v) => (v as List).map<double>((n) => (n as num).toDouble()).toList(),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Agent function-calling. [messages] is the full OpenAI-format conversation
  /// (may include assistant tool_calls and role:"tool" results). Returns the
  /// raw assistant message map: { content: String, tool_calls: List? }.
  Future<Map<String, dynamic>> chatWithTools({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    String model = 'gpt-4o-mini',
    double temperature = 0.4,
    int maxTokens = 900,
  }) async {
    final body = <String, dynamic>{
      'messages': messages,
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'tools': tools,
      'tool_choice': 'auto',
      if (_hasByok) 'byok_key': byokKey,
    };
    try {
      final response = await _client.functions.invoke(
        'openai-chat',
        body: body,
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const FormatException('Unexpected AI response.');
    } on FunctionException catch (e) {
      if (e.status == 404 && _hasByok) {
        return _directTools(messages, tools, model, temperature, maxTokens);
      }
      throw Exception(
        _messageFromDetails(e.details) ?? 'AI request failed (${e.status}).',
      );
    } catch (_) {
      if (_hasByok) {
        return _directTools(messages, tools, model, temperature, maxTokens);
      }
      throw Exception('Could not reach the AI service.');
    }
  }

  Future<Map<String, dynamic>> _directTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    String model,
    double temperature,
    int maxTokens,
  ) async {
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $byokKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'tools': tools,
        'tool_choice': 'auto',
      }),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception('OpenAI request failed (${res.statusCode})');
    }
    final msg = ((decoded as Map)['choices'] as List).first['message'] as Map;
    return {'content': msg['content'] ?? '', 'tool_calls': msg['tool_calls']};
  }

  /// Direct browser/device → OpenAI call using the user's own key.
  Future<String> _directChat({
    required List<Map<String, dynamic>> messages,
    required String model,
    required double temperature,
    required int maxTokens,
    required bool jsonMode,
  }) async {
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $byokKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        if (jsonMode) 'response_format': {'type': 'json_object'},
      }),
    );

    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final msg = (decoded is Map && decoded['error'] is Map)
          ? (decoded['error']['message']?.toString() ??
                'OpenAI request failed (${res.statusCode})')
          : 'OpenAI request failed (${res.statusCode})';
      throw Exception(msg);
    }
    final choices = (decoded as Map)['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('OpenAI returned no choices.');
    }
    return ((choices.first as Map)['message'] as Map)['content'] as String;
  }

  String? _messageFromDetails(Object? details) {
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return null;
  }

  void dispose() {}
}
