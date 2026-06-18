import 'dart:convert';



import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/config/alter_gateway_config.dart';

import '../../auth/application/auth_provider.dart';

import '../../../core/errors/alter_service_exception.dart';

import '../../../core/network/connectivity_service.dart';

import '../../identity/application/identity_engine.dart';

import '../../memory/application/memory_encode_pipeline.dart';

import '../../memory/application/memory_retriever.dart';

import '../../profile/application/profile_provider.dart';

import '../../profile/domain/user_profile.dart';

import '../../actions/action_runtime.dart';

import '../application/voice_gemma_runner.dart';

import '../application/voice_io_preference.dart';

import '../application/voice_local_fallback.dart';

import '../application/voice_backend_preference.dart';

import '../application/voice_session_context.dart';

import '../data/voice_runtime_api_client.dart';



final voiceRuntimeApiClientProvider = Provider<VoiceRuntimeApiClient>((ref) {

  final client = VoiceRuntimeApiClient();

  ref.onDispose(client.close);

  return client;

});



final voiceRuntimeControllerProvider =

    NotifierProvider<VoiceRuntimeController, VoiceRuntimeState>(

  VoiceRuntimeController.new,

);



class VoiceRuntimeController extends Notifier<VoiceRuntimeState> {

  static const cloudMemoryChars = 4000;

  static const gemmaMemoryChars = 1500;

  static const heuristicMemoryChars = 800;



  @override

  VoiceRuntimeState build() => const VoiceRuntimeState();



  Future<void> run({

    required String transcript,

    required String locale,

  }) async {

    final trimmed = transcript.trim();

    if (trimmed.length < 3) {

      state = state.copyWith(

        isRunning: false,

        errorMessage: 'Say or type a command for ALTER.',

      );

      return;

    }



    final backend = ref.read(voiceBackendPreferenceProvider);

    state = state.copyWith(isRunning: true, errorMessage: '', clearResult: true);



    try {

      final profile = ref.read(userProfileProvider).asData?.value;

      final online = await ref.read(connectivityServiceProvider).isOnline;

      final expansion = ref.read(voiceSessionContextProvider.notifier).expansionPrefix(

            displayName: profile?.displayName,

            role: profile?.role,

          );



      String memoryBlockFull = '';

      try {

        memoryBlockFull = await ref.read(memoryRetrieverProvider).retrieveContext(

              query: trimmed,

              queryPrefix: expansion,

              maxChars: cloudMemoryChars,

            );

      } catch (e) {

        if (kDebugMode) debugPrint('Voice memory retrieve skipped: $e');

      }



      final identityTraits =

          ref.read(identityEngineProvider).asData?.value ?? const [];

      final identityBlock = identityTraits

          .map((t) =>

              '${t.dimension}=${t.value} (${t.confidence.toStringAsFixed(2)})')

          .join('; ');



      final result = await _runInferenceCascade(

        backend: backend,

        trimmed: trimmed,

        locale: locale,

        profile: profile,

        memoryBlockFull: memoryBlockFull,

        identityBlock: identityBlock,

        online: online,

      );



      if (result == null) {

        state = state.copyWith(

          isRunning: false,

          errorMessage: 'Could not produce a voice response. Try again.',

        );

        return;

      }



      var finalResult = result;

      try {

        await ref.read(memoryEncodePipelineProvider).processVoiceTurn(

              userTranscript: trimmed,

              assistantSummary: finalResult.spokenResponse,

              intent: finalResult.inferredIntent,

            );

        ref.read(voiceSessionContextProvider.notifier).record(

              userTranscript: trimmed,

              assistantSummary: finalResult.spokenResponse,

            );

      } catch (e) {

        if (kDebugMode) debugPrint('Voice memory encode skipped: $e');

      }



      state = state.copyWith(isRunning: false, result: finalResult);

    } catch (error) {

      if (kDebugMode) debugPrint('Voice runtime unexpected: $error');

      state = state.copyWith(

        isRunning: false,

        errorMessage: 'Something went wrong. Try again.',

      );

    }

  }



  Future<VoiceRuntimeResult?> _runInferenceCascade({

    required VoiceBackend backend,

    required String trimmed,

    required String locale,

    UserProfile? profile,

    required String memoryBlockFull,

    required String identityBlock,

    required bool online,

  }) async {

    final offlineOnly =

        ref.read(voiceIoPreferenceProvider) == VoiceIoMode.offlineOnly;

    final useCloudOrGateway = backend != VoiceBackend.onDevice &&

        !offlineOnly &&

        online;



    if (backend == VoiceBackend.onDevice || offlineOnly || !online) {

      final gemmaMemory = _trimMemoryBlock(memoryBlockFull, gemmaMemoryChars);

      final gemmaAction = await _runGemmaActionTools(

        trimmed,

        locale,

        profile,

        gemmaMemory,

        identityBlock,

      );

      if (gemmaAction != null) return _tagTier(gemmaAction, 'gemma');

    }



    if (useCloudOrGateway) {

      if (backend == VoiceBackend.cloudAi) {

        final cloud = await _tryCloudAi(

          trimmed,

          locale,

          profile,

          memoryBlockFull,

          identityBlock,

        );

        if (cloud != null) return _tagTier(cloud, 'cloud');

      }

      if (backend == VoiceBackend.gateway) {

        final gateway = await _tryGateway(

          trimmed,

          locale,

          profile,

          memoryBlockFull,

        );

        if (gateway != null) return _tagTier(gateway, 'gateway');

      }

    }



    final gemmaMemory = _trimMemoryBlock(memoryBlockFull, gemmaMemoryChars);

    final gemma = await ref.read(voiceGemmaRunnerProvider).run(

          transcript: trimmed,

          locale: locale,

          profile: profile,

          memoryBlock: gemmaMemory,

          identityBlock: identityBlock,

        );

    if (gemma != null) return _tagTier(gemma, 'gemma');



    final heuristicMemory =

        _trimMemoryBlock(memoryBlockFull, heuristicMemoryChars);

    return VoiceLocalFallback.respond(

      transcript: trimmed,

      memoryBlock: heuristicMemory,

      identityBlock: identityBlock,

      profile: profile,

      offline: offlineOnly || !online,

    );

  }



  Future<VoiceRuntimeResult?> _tryCloudAi(

    String transcript,

    String locale,

    UserProfile? profile,

    String memoryBlock,

    String identityBlock,

  ) async {

    try {

      final openai = ref.read(openAIServiceProvider);

      if (openai == null) return null;

      final online = await ref.read(connectivityServiceProvider).isOnline;

      if (!online) return null;

      return await _runActionTools(

        transcript,

        locale,

        profile,

        memoryBlock,

        identityBlock,

      );

    } on AlterServiceException {

      return null;

    } catch (e) {

      if (kDebugMode) debugPrint('Cloud AI skipped: $e');

      return null;

    }

  }



  Future<VoiceRuntimeResult?> _tryGateway(

    String transcript,

    String locale,

    UserProfile? profile,

    String memoryBlock,

  ) async {

    try {

      if (!AlterGatewayConfig.isConfigured) return null;

      final online = await ref.read(connectivityServiceProvider).isOnline;

      if (!online) return null;

      final userId = ref.read(localUserIdProvider);

      return await ref.read(voiceRuntimeApiClientProvider).run(

            transcript: transcript,

            locale: locale,

            userId: userId,

            profile: profile,

            memoryContext: memoryBlock,

          );

    } on AlterServiceException {

      return null;

    } catch (e) {

      if (kDebugMode) debugPrint('Gateway skipped: $e');

      return null;

    }

  }



  Future<VoiceRuntimeResult?> _runGemmaActionTools(

    String transcript,

    String locale,

    UserProfile? profile,

    String memoryBlock,

    String identityBlock,

  ) async {

    try {

      return await _runActionTools(

        transcript,

        locale,

        profile,

        memoryBlock,

        identityBlock,

      );

    } catch (e) {

      if (kDebugMode) debugPrint('Gemma action skipped: $e');

      return null;

    }

  }



  Future<VoiceRuntimeResult> _runActionTools(

    String transcript,

    String locale,

    UserProfile? profile,

    String memoryBlock,

    String identityBlock,

  ) async {

    final api = ActionRuntime.freshApiMessages(ref);

    final basePrompt = (api.first['content'] ?? '').toString();

    api[0] = {

      'role': 'system',

      'content': '$basePrompt\n\nLocale: $locale\n'

          'Memories:\n${memoryBlock.isEmpty ? 'None.' : memoryBlock}\n'

          'Identity: ${identityBlock.isEmpty ? 'still learning' : identityBlock}',

    };

    final toolsUsed = <String>[];

    final turn = await ActionRuntime.runTurn(

      ref: ref,

      apiMessages: api,

      userInput: transcript,

      memoryBlock: memoryBlock,

      identityBlock: identityBlock,

      onToolStart: (name) => toolsUsed.add(name),

    );

    return VoiceRuntimeResult(

      normalizedText: transcript,

      wakeWordDetected: false,

      inferredIntent: toolsUsed.isEmpty ? 'conversation' : 'action',

      intentConfidence: 0.92,

      spokenResponse: turn.reply,

      displayResponse: turn.reply,

      actionGraph: toolsUsed,

      experimentPlan: null,

      nextActions: const [],

      followUpQuestions: const [],

      signals: const [],

    );

  }



  Future<VoiceRuntimeResult> _runDirect(

    String transcript,

    String locale,

    UserProfile? profile,

    String memoryBlock,

    String identityBlock,

  ) async {

    final openai = ref.read(openAIServiceProvider)!;

    final systemPrompt =

        _buildSystemPrompt(profile, locale, memoryBlock, identityBlock);



    final raw = await openai.chat(

      messages: [

        {'role': 'system', 'content': systemPrompt},

        {'role': 'user', 'content': transcript},

      ],

      temperature: 0.6,

      maxTokens: 1400,

      jsonMode: true,

    );



    var cleaned = raw.trim();

    if (cleaned.startsWith('```')) {

      cleaned = cleaned

          .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')

          .replaceFirst(RegExp(r'\n?\s*```$'), '');

    }



    final json = jsonDecode(cleaned) as Map<String, dynamic>;

    return VoiceRuntimeResult.fromJson(json);

  }



  String _buildSystemPrompt(

    UserProfile? profile,

    String locale,

    String memoryBlock,

    String identityBlock,

  ) {

    final name = profile?.displayName.isNotEmpty == true

        ? profile!.displayName

        : 'the user';

    final role =

        profile?.role.isNotEmpty == true ? profile!.role : 'professional';

    final skills = profile?.skills.isNotEmpty == true

        ? profile!.skills.join(', ')

        : 'not yet specified';

    final goals = profile?.goals.isNotEmpty == true

        ? profile!.goals.join('; ')

        : 'not yet specified';

    final languages = profile?.languages.isNotEmpty == true

        ? profile!.languages.join(', ')

        : locale;



    return '''You are ALTER, a warm, intelligent personal voice assistant for $name.

Behave like a top-tier conversational AI: directly ANSWER questions, hold natural

conversation, do math, explain things, give advice, and help with everyday tasks.

Be concise and friendly — your reply is read aloud.



LANGUAGE — VERY IMPORTANT: Always reply in the SAME language and script the user

used. If ambiguous, use: $languages.



Just say hi back when greeted. Do NOT invent tasks or experiments unless asked.



User profile: role=$role | skills=$skills | goals=$goals | languages=$languages

Identity: ${identityBlock.isEmpty ? 'still learning' : identityBlock}

Memories (use only these):

${memoryBlock.isEmpty ? 'None yet.' : memoryBlock}



Respond ONLY with valid JSON (no markdown fences):

{

  "normalized_text": "cleaned transcript",

  "wake_word_detected": true,

  "inferred_intent": "conversation | call_contact | send_message | memory_capture",

  "intent_confidence": 0.0-1.0,

  "spoken_response": "natural answer in user's language (1-4 sentences)",

  "display_response": "same answer with optional extra detail",

  "action_graph": [],

  "next_actions": [],

  "follow_up_questions": [],

  "signals": []

}''';

  }



  String _trimMemoryBlock(String block, int maxChars) {

    if (block.length <= maxChars) return block;

    return '${block.substring(0, maxChars - 1)}…';

  }



  VoiceRuntimeResult _tagTier(VoiceRuntimeResult result, String tier) {

    final tierSignal = VoiceRuntimeSignal(

      title: 'Inference tier',

      status: 'ok',

      summary: tier,

      latencyMs: null,

    );

    return VoiceRuntimeResult(

      normalizedText: result.normalizedText,

      wakeWordDetected: result.wakeWordDetected,

      inferredIntent: result.inferredIntent,

      intentConfidence: result.intentConfidence,

      spokenResponse: result.spokenResponse,

      displayResponse: result.displayResponse,

      actionGraph: result.actionGraph,

      experimentPlan: result.experimentPlan,

      nextActions: result.nextActions,

      followUpQuestions: result.followUpQuestions,

      signals: [tierSignal, ...result.signals],

    );

  }

}



class VoiceRuntimeState {

  const VoiceRuntimeState({

    this.isRunning = false,

    this.result,

    this.errorMessage = '',

  });



  final bool isRunning;

  final VoiceRuntimeResult? result;

  final String errorMessage;



  VoiceRuntimeState copyWith({

    bool? isRunning,

    VoiceRuntimeResult? result,

    String? errorMessage,

    bool clearResult = false,

  }) {

    return VoiceRuntimeState(

      isRunning: isRunning ?? this.isRunning,

      result: clearResult ? null : (result ?? this.result),

      errorMessage: errorMessage ?? this.errorMessage,

    );

  }

}


