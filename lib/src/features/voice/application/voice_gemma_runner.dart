import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/performance/on_device_resource_governor.dart';
import '../../contextos/application/gemma_model_manager.dart';
import '../../profile/domain/user_profile.dart';
import '../data/voice_runtime_api_client.dart';

/// On-device Gemma inference for voice commands (offline tier).
class VoiceGemmaRunner {
  VoiceGemmaRunner(this._ref);

  final Ref _ref;

  Future<VoiceRuntimeResult?> run({
    required String transcript,
    required String locale,
    UserProfile? profile,
    required String memoryBlock,
    required String identityBlock,
  }) async {
    final manager = _ref.read(gemmaModelProvider.notifier);
    if (!await manager.ensureLoaded()) return null;

    final model = manager.model;
    if (model == null) return null;

    final prompt =
        _prompt(transcript, profile, locale, memoryBlock, identityBlock);

    try {
      await _ref
          .read(onDeviceResourceGovernorProvider.notifier)
          .acquire(OnDeviceResource.llm);

      final session = await model.createSession(temperature: 0.4, topK: 40);
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final raw = await session.getResponse();
      await session.close();

      await _ref
          .read(onDeviceResourceGovernorProvider.notifier)
          .release(OnDeviceResource.llm);

      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')
            .replaceFirst(RegExp(r'\n?\s*```$'), '');
      }
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final json = jsonDecode(cleaned.substring(start, end + 1));
      if (json is! Map<String, dynamic>) return null;
      return VoiceRuntimeResult.fromJson(json);
    } catch (_) {
      await _ref
          .read(onDeviceResourceGovernorProvider.notifier)
          .release(OnDeviceResource.llm);
      return null;
    }
  }

  String _prompt(
    String transcript,
    UserProfile? profile,
    String locale,
    String memoryBlock,
    String identityBlock,
  ) {
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'the user';
    return '''You are ALTER, a warm, helpful personal voice assistant for $name.
Answer like a normal conversational AI: directly answer questions, chat
naturally, and help. Reply in the SAME language the user used (locale hint: $locale).
If the user just greets you ("hi"/"hello"), greet them back and ask how you can
help — do NOT invent tasks or "reversible" steps.

Identity: ${identityBlock.isEmpty ? 'building' : identityBlock}
Memories (use only these, never invent):
${memoryBlock.isEmpty ? 'none' : memoryBlock}

User said: "$transcript"

Respond ONLY with JSON:
{"normalized_text":"...","wake_word_detected":true,"inferred_intent":"conversation|call_contact|send_message|memory_capture","intent_confidence":0.0,"spoken_response":"your real answer in the user's language (1-3 sentences)","display_response":"same answer, optionally a little more detail","action_graph":[],"next_actions":[],"follow_up_questions":[],"signals":[]}

Use "conversation" for normal questions, chat, and greetings (put the answer in spoken_response).
Use "call_contact" only when explicitly asked to call someone (name them in spoken_response).
Use "send_message" only when explicitly asked to text/message someone.
Use "memory_capture" when asked to remember something.''';
  }
}

final voiceGemmaRunnerProvider = Provider<VoiceGemmaRunner>((ref) {
  return VoiceGemmaRunner(ref);
});
