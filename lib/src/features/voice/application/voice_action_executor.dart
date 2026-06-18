import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/application/agent_tools.dart';
import '../data/voice_runtime_api_client.dart';

final voiceActionExecutorProvider = Provider<VoiceActionExecutor>((ref) {
  return VoiceActionExecutor(ref);
});

/// Executes phone actions from voice runtime intents.
class VoiceActionExecutor {
  VoiceActionExecutor(this._ref);

  final Ref _ref;

  Future<String?> execute(VoiceRuntimeResult result, String transcript) async {
    final intent = result.inferredIntent.toLowerCase();
    final text = transcript.toLowerCase();

    if (intent == 'call_contact' || _looksLikeCall(text)) {
      return _callContact(text, result);
    }
    if (intent == 'send_message' || _looksLikeMessage(text)) {
      return _sendMessage(text, result);
    }
    return null;
  }

  bool _looksLikeCall(String text) =>
      RegExp(r'\b(call|dial|phone|ring)\b').hasMatch(text);

  bool _looksLikeMessage(String text) =>
      RegExp(r'\b(text|message|sms|whatsapp|send)\b').hasMatch(text) &&
      !RegExp(r'\b(send me|send a reminder)\b').hasMatch(text);

  Future<String?> _callContact(String text, VoiceRuntimeResult result) async {
    final name = _extractContactName(text) ??
        _extractFromGraph(result, r'contact[:\s]+(\w+)');
    if (name == null || name.isEmpty) {
      return 'Who should I call? Say a name like "call Dad".';
    }
    final found = await executeAgentTool(
      _ref,
      'find_contact',
      {'name': name},
    );
    final number = _extractPhone(found);
    if (number == null) {
      return 'I could not find $name in your contacts.';
    }
    await executeAgentTool(_ref, 'call_number', {'number': number});
    return 'Calling $name.';
  }

  Future<String?> _sendMessage(String text, VoiceRuntimeResult result) async {
    final name = _extractContactName(text);
    final body = _extractMessageBody(text) ??
        result.normalizedText.replaceFirst(
          RegExp(r'^.*?(message|text|sms)\s+', caseSensitive: false),
          '',
        );
    if (name == null || name.isEmpty) {
      return 'Who should I message?';
    }
    if (body.trim().length < 2) {
      return 'What should the message say?';
    }
    final found = await executeAgentTool(
      _ref,
      'find_contact',
      {'name': name},
    );
    final number = _extractPhone(found);
    if (number == null) {
      return 'I could not find $name in your contacts.';
    }
    final app = text.contains('whatsapp') ? 'whatsapp' : 'sms';
    await executeAgentTool(_ref, 'send_message', {
      'app': app,
      'number': number,
      'text': body.trim(),
    });
    return 'Opening $app to message $name.';
  }

  String? _extractContactName(String text) {
    final patterns = [
      RegExp(r'call\s+(?:my\s+)?(\w+)', caseSensitive: false),
      RegExp(r'dial\s+(?:my\s+)?(\w+)', caseSensitive: false),
      RegExp(r'message\s+(?:my\s+)?(\w+)', caseSensitive: false),
      RegExp(r'text\s+(?:my\s+)?(\w+)', caseSensitive: false),
      RegExp(r'send\s+(?:a\s+)?(?:message|text)\s+to\s+(?:my\s+)?(\w+)',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractMessageBody(String text) {
    final m = RegExp(
      r'(?:message|text|sms)\s+\w+\s+(?:to\s+say\s+|saying\s+|that\s+)?(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _extractFromGraph(VoiceRuntimeResult result, String pattern) {
    for (final step in result.actionGraph) {
      final m = RegExp(pattern, caseSensitive: false).firstMatch(step);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractPhone(String findResult) {
    final m = RegExp(r'(\+?\d[\d\s\-()]{7,}\d)').firstMatch(findResult);
    if (m != null) return m.group(1)!.replaceAll(RegExp(r'[\s\-()]'), '');
    final plain = RegExp(r'(\+?\d{10,15})').firstMatch(findResult);
    return plain?.group(1);
  }
}
