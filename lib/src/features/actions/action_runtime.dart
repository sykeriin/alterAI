import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../profile/application/profile_provider.dart';
import '../voice/application/voice_backend_preference.dart';
import 'action_runtime_result.dart';
import 'action_system_prompt.dart';
import 'action_tools.dart';
import 'calendar_request_parser.dart';
import 'gemma_action_runtime.dart';

/// Shared action loop — Gemma on-device by default, Cloud AI when explicitly selected.
class ActionRuntime {
  const ActionRuntime._();

  static Future<ActionRuntimeResult> runTurn({
    required Ref ref,
    required List<Map<String, dynamic>> apiMessages,
    required String userInput,
    bool deep = false,
    String memoryBlock = '',
    String identityBlock = '',
    void Function(String toolName)? onToolStart,
    void Function(String toolName, String result)? onToolComplete,
  }) async {
    final calendar = CalendarRequestParser.tryParse(userInput);
    if (calendar != null) {
      onToolStart?.call('schedule_event');
      final result = await executeActionTool(ref, 'schedule_event', {
        'title': calendar.title,
        'start_iso': calendar.startIso,
        'end_iso': calendar.endIso,
        'notes': calendar.notes,
      });
      onToolComplete?.call('schedule_event', result);
      final start = DateTime.tryParse(calendar.startIso);
      final when = start == null
          ? calendar.startIso
          : '${start.day} ${_monthName(start.month)} ${start.year}';
      final queued = result.toLowerCase().contains('queue') ||
          result.toLowerCase().contains('pending') ||
          result.toLowerCase().contains('confirm');
      final reply = queued
          ? 'I queued "${calendar.title}" for $when. Check Pending actions and tap Confirm to add it to your calendar.'
          : 'I opened your calendar for "${calendar.title}" on $when.';
      return ActionRuntimeResult(
        reply: reply,
        toolsUsed: const ['schedule_event'],
      );
    }

    final backend = ref.read(voiceBackendPreferenceProvider);
    if (backend == VoiceBackend.onDevice || !_cloudAvailable(ref)) {
      return GemmaActionRuntime.runTurn(
        ref: ref,
        userInput: deep
            ? '$userInput\n\n[Think step by step before replying.]'
            : userInput,
        memoryBlock: memoryBlock,
        identityBlock: identityBlock,
        onToolStart: onToolStart,
        onToolComplete: onToolComplete,
      );
    }

    return _runCloudTurn(
      ref: ref,
      apiMessages: apiMessages,
      userInput: userInput,
      deep: deep,
      onToolStart: onToolStart,
      onToolComplete: onToolComplete,
    );
  }

  static bool _cloudAvailable(Ref ref) {
    return ref.read(openAIServiceProvider) != null;
  }

  static Future<ActionRuntimeResult> _runCloudTurn({
    required Ref ref,
    required List<Map<String, dynamic>> apiMessages,
    required String userInput,
    required bool deep,
    void Function(String toolName)? onToolStart,
    void Function(String toolName, String result)? onToolComplete,
  }) async {
    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      throw UserFacingError.from(
        Exception('Cloud AI selected but OpenAI key is missing.'),
      );
    }

    final apiContent = deep
        ? '$userInput\n\n[Deep reasoning mode: think step by step.]'
        : userInput;
    apiMessages.add({'role': 'user', 'content': apiContent});

    final model = deep ? 'gpt-4o' : 'gpt-4o-mini';
    final toolsUsed = <String>[];

    for (var i = 0; i < 6; i++) {
      final resp = await openai.chatWithTools(
        messages: List<Map<String, dynamic>>.from(apiMessages),
        tools: kActionTools,
        model: model,
        maxTokens: deep ? 1600 : 900,
      );
      final content = (resp['content'] ?? '').toString();
      final toolCalls = resp['tool_calls'];

      if (toolCalls is List && toolCalls.isNotEmpty) {
        apiMessages.add({
          'role': 'assistant',
          'content': content.isEmpty ? null : content,
          'tool_calls': toolCalls,
        });
        for (final tc in toolCalls) {
          final m = Map<String, dynamic>.from(tc as Map);
          final id = m['id']?.toString() ?? '';
          final fn = Map<String, dynamic>.from(m['function'] as Map);
          final name = fn['name']?.toString() ?? '';
          Map<String, dynamic> args;
          try {
            args = jsonDecode((fn['arguments'] ?? '{}').toString())
                as Map<String, dynamic>;
          } catch (_) {
            args = {};
          }
          onToolStart?.call(name);
          final result = await executeActionTool(ref, name, args);
          onToolComplete?.call(name, result);
          toolsUsed.add(name);
          apiMessages.add({
            'role': 'tool',
            'tool_call_id': id,
            'content': result,
          });
        }
        continue;
      }

      apiMessages.add({'role': 'assistant', 'content': content});
      return ActionRuntimeResult(reply: content, toolsUsed: toolsUsed);
    }

    return ActionRuntimeResult(
      reply: 'I hit my step limit. Try a simpler request.',
      toolsUsed: toolsUsed,
    );
  }

  static Future<String> runDraftTurn({
    required Ref ref,
    required String userMessage,
  }) async {
    final result = await runTurn(
      ref: ref,
      apiMessages: freshApiMessages(ref),
      userInput: userMessage,
    );
    return result.reply;
  }

  static List<Map<String, dynamic>> freshApiMessages(Ref ref) {
    final profile = ref.read(userProfileProvider).asData?.value;
    return [
      {'role': 'system', 'content': buildActionSystemPrompt(profile: profile)},
    ];
  }

  static String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > 12) return '$month';
    return names[month];
  }
}
