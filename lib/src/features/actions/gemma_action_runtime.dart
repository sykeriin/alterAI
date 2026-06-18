import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/performance/on_device_resource_governor.dart';
import '../contextos/application/gemma_model_manager.dart';
import '../profile/application/profile_provider.dart';
import '../profile/domain/user_profile.dart';
import '../voice/application/voice_backend_preference.dart';
import 'action_runtime_result.dart';
import 'action_system_prompt.dart';
import 'action_tools.dart';

/// On-device Gemma tool loop — JSON plan → execute tool → repeat.
class GemmaActionRuntime {
  const GemmaActionRuntime._();

  static bool preferGemma(Ref ref) {
    final backend = ref.read(voiceBackendPreferenceProvider);
    return backend == VoiceBackend.onDevice;
  }

  static Future<ActionRuntimeResult> runTurn({
    required Ref ref,
    required String userInput,
    List<Map<String, dynamic>>? conversation,
    String memoryBlock = '',
    String identityBlock = '',
    void Function(String toolName)? onToolStart,
    void Function(String toolName, String result)? onToolComplete,
  }) async {
    final manager = ref.read(gemmaModelProvider.notifier);
    if (!await manager.ensureLoaded()) {
      throw Exception(
        'Gemma is not loaded. Open Settings → EDGE and download/load Gemma 4.',
      );
    }
    final model = manager.model;
    if (model == null) {
      throw Exception('Gemma model unavailable.');
    }

    final profile = ref.read(userProfileProvider).asData?.value;
    final toolsUsed = <String>[];
    final transcript = StringBuffer()
      ..writeln('User: ${userInput.trim()}');

    for (var step = 0; step < 6; step++) {
      final prompt = _buildPrompt(
        profile: profile,
        memoryBlock: memoryBlock,
        identityBlock: identityBlock,
        transcript: transcript.toString(),
      );

      final raw = await _infer(ref, model, prompt);
      final parsed = _parseStep(raw);
      if (parsed == null) {
        return ActionRuntimeResult(
          reply: 'I had trouble understanding that. Try rephrasing.',
          toolsUsed: toolsUsed,
        );
      }

      if (parsed.isReply) {
        return ActionRuntimeResult(
          reply: parsed.reply!,
          toolsUsed: toolsUsed,
        );
      }

      final name = parsed.toolName!;
      final args = parsed.toolArgs;
      onToolStart?.call(name);
      final result = await executeActionTool(ref, name, args);
      onToolComplete?.call(name, result);
      toolsUsed.add(name);
      transcript.writeln('Tool $name → $result');
      transcript.writeln('(Choose another tool or reply to the user.)');
    }

    return ActionRuntimeResult(
      reply: 'I hit my step limit. Try a simpler request.',
      toolsUsed: toolsUsed,
    );
  }

  static Future<String> _infer(
    Ref ref,
    InferenceModel model,
    String prompt,
  ) async {
    await ref
        .read(onDeviceResourceGovernorProvider.notifier)
        .acquire(OnDeviceResource.llm);
    try {
      final session = await model.createSession(temperature: 0.35, topK: 40);
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final raw = await session.getResponse();
      await session.close();
      return raw.trim();
    } finally {
      await ref
          .read(onDeviceResourceGovernorProvider.notifier)
          .release(OnDeviceResource.llm);
    }
  }

  static String _buildPrompt({
    UserProfile? profile,
    required String memoryBlock,
    required String identityBlock,
    required String transcript,
  }) {
    final system = buildActionSystemPrompt(profile: profile);
    return '''$system

You run fully ON-DEVICE. Use tools for actions; answer briefly when done.
Today is ${DateTime.now().toIso8601String().substring(0, 10)}.
Respond ONLY with one JSON object (no markdown fences).

Tool catalog (name + args):
- find_contact(name)
- call_number(number)
- compose_message(channel: whatsapp|sms, recipient, intent, tone?, body?, number?)
- compose_email(to, intent, subject?, body?, tone?)
- schedule_event(title, start_iso, end_iso?, location?, notes?) — use ISO-8601 local times; for "6 Oct 2026" use 2026-10-06T09:00:00
- send_message(app: whatsapp|sms, number, text)
- web_search(query) — opens browser
- open_url(url)
- add_calendar_event(title, details?, start_iso?)
- safety_check(text)
- plan_day(context)
- weigh_decision(decision)
- ask_council(question)
- queue_openclaw_action(action_type, title, detail?)

JSON shapes:
{"step":"tool","name":"find_contact","args":{"name":"Mom"}}
{"step":"reply","text":"Your spoken answer in the user's language"}

Rules: find_contact before messaging by name. Use compose_message for WhatsApp/SMS drafts.
For calendar requests (birthday, event, appointment), use schedule_event with parsed ISO dates.
Never claim you sent something unless a tool result says so.

Identity: ${identityBlock.isEmpty ? 'still learning' : identityBlock}
Memories:
${memoryBlock.isEmpty ? 'None.' : memoryBlock}

Conversation:
$transcript''';
  }

  static _GemmaStep? _parseStep(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')
          .replaceFirst(RegExp(r'\n?\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final json =
          jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
      final step = (json['step'] ?? json['action'] ?? '').toString();
      final hasToolName = (json['name'] ?? json['tool'] ?? json['tool_name'] ?? '')
          .toString()
          .isNotEmpty;
      if (step == 'reply' ||
          json.containsKey('spoken_response') ||
          (json.containsKey('text') && !hasToolName)) {
        final text = (json['text'] ??
                json['spoken_response'] ??
                json['reply'] ??
                json['display_response'] ??
                '')
            .toString()
            .trim();
        if (text.isEmpty) return null;
        return _GemmaStep.reply(text);
      }
      final name =
          (json['name'] ?? json['tool'] ?? json['tool_name'] ?? '').toString();
      if (name.isEmpty) return null;
      final argsRaw = json['args'] ?? json['arguments'] ?? json['parameters'];
      final args = argsRaw is Map
          ? Map<String, dynamic>.from(argsRaw)
          : <String, dynamic>{};
      return _GemmaStep.tool(name, args);
    } catch (_) {
      return null;
    }
  }
}

class _GemmaStep {
  _GemmaStep._({this.reply, this.toolName, this.toolArgs = const {}});

  factory _GemmaStep.reply(String text) => _GemmaStep._(reply: text);

  factory _GemmaStep.tool(String name, Map<String, dynamic> args) =>
      _GemmaStep._(toolName: name, toolArgs: args);

  final String? reply;
  final String? toolName;
  final Map<String, dynamic> toolArgs;

  bool get isReply => reply != null && reply!.isNotEmpty;
}
