import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../app/app_state.dart';
import '../../backend/application/backend_config_controller.dart';
import '../../contextos/application/gemma_model_manager.dart';
import '../../ondevice/on_device_ai.dart';
import '../../privacy/data/context_privacy_filter.dart';
import '../../profile/application/profile_provider.dart';
import '../../voice/data/native_audio_capture.dart';
import '../../voice/data/sarvam_live_voice_client.dart';
import '../../voice/data/voice_runtime_api_client.dart';
import 'agent_tools.dart';
import 'persistent_intelligence_store.dart';

enum AgentRole { user, assistant, tool }

class AgentMessage {
  AgentMessage(this.role, this.text, {this.pending = false});
  final AgentRole role;
  String text;
  bool pending;
}

class AgentState {
  const AgentState({
    this.messages = const [],
    this.isThinking = false,
    this.isListening = false,
    this.isSarvamRecording = false,
    this.partial = '',
    this.error = '',
    this.liveVoiceStatus = '',
  });

  final List<AgentMessage> messages;
  final bool isThinking;
  final bool isListening;
  final bool isSarvamRecording;
  final String partial;
  final String error;
  final String liveVoiceStatus;

  AgentState copyWith({
    List<AgentMessage>? messages,
    bool? isThinking,
    bool? isListening,
    bool? isSarvamRecording,
    String? partial,
    String? error,
    String? liveVoiceStatus,
  }) => AgentState(
    messages: messages ?? this.messages,
    isThinking: isThinking ?? this.isThinking,
    isListening: isListening ?? this.isListening,
    isSarvamRecording: isSarvamRecording ?? this.isSarvamRecording,
    partial: partial ?? this.partial,
    error: error ?? this.error,
    liveVoiceStatus: liveVoiceStatus ?? this.liveVoiceStatus,
  );
}

final agentControllerProvider = NotifierProvider<AgentController, AgentState>(
  AgentController.new,
);

class AgentController extends Notifier<AgentState> {
  final _api = <Map<String, dynamic>>[];
  final _tts = FlutterTts();
  final _audio = const NativeAudioBridge();
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;

  bool _speaking = false;
  Timer? _captureTimer;
  List<Map<String, dynamic>> _recallPrefix = const [];

  @override
  AgentState build() {
    _api.add({'role': 'system', 'content': _systemPrompt()});
    _tts.awaitSpeakCompletion(true);
    ref.onDispose(() {
      _speaking = false;
      _captureTimer?.cancel();
      _tts.stop();
      _audio.cancelRecording();
      _audio.stopPlayback();
      _stt.cancel();
    });
    return AgentState(
      messages: [
        AgentMessage(
          AgentRole.assistant,
          'Hi, I\'m ALTER. Talk to me — ask me to check if something\'s safe, '
          'plan your day, weigh a decision, message someone, or look something up.',
        ),
      ],
    );
  }

  // --- Voice in (record → cloud transcribe; far better than on-device STT) ---
  /// The mic button: start capturing, or stop + transcribe if already capturing.
  /// Capture records the FULL utterance and only stops when you tap again (or,
  /// for a wake, after a max window) — so it never cuts you off mid-sentence,
  /// and a cloud model (Sarvam) transcribes it for real accuracy. The on-device
  /// recognizer is used only as an offline fallback.
  Future<void> toggleListening() async {
    if (state.isSarvamRecording) {
      await _stopCloudCaptureAndSend();
      return;
    }
    if (state.isListening) {
      stopListening();
      return;
    }
    await _startCapture(interrupt: true);
  }

  void stopListening() {
    _captureTimer?.cancel();
    _stt.stop();
    _audio.cancelRecording();
    state = state.copyWith(
      isListening: false,
      isSarvamRecording: false,
      partial: '',
      liveVoiceStatus: '',
    );
  }

  /// "Hey ALTER" wake entry point. Only fires when fully idle, so it can never
  /// talk over ALTER or start a runaway capture.
  Future<void> startListeningFromWake() async {
    if (_speaking ||
        state.isThinking ||
        state.isListening ||
        state.isSarvamRecording) {
      return;
    }
    await _startCapture(fromWake: true);
  }

  /// Begin a capture. Prefers cloud record→transcribe (accurate, no cutoff);
  /// falls back to the on-device recognizer only when no gateway is reachable.
  Future<void> _startCapture({
    bool interrupt = false,
    bool fromWake = false,
  }) async {
    if (state.isThinking || state.isListening || state.isSarvamRecording) {
      return;
    }
    if (_speaking && !interrupt) return; // never cut ALTER off on a wake
    _speaking = false;
    await _tts.stop();
    await _audio.stopPlayback();

    final config = await ref.read(backendConfigProvider.future);
    if (config.hasGateway) {
      final started = await _audio.startRecording();
      if (started.ok) {
        state = state.copyWith(
          isSarvamRecording: true,
          isListening: true,
          partial: '',
          error: '',
          liveVoiceStatus: 'Listening… tap to send',
        );
        if (fromWake) {
          // Hands-free has no "tap to stop", so cap the recording window.
          _captureTimer?.cancel();
          _captureTimer = Timer(const Duration(seconds: 12), () {
            if (state.isSarvamRecording) _stopCloudCaptureAndSend();
          });
        }
        return;
      }
      // Recording couldn't start — fall through to the native recognizer.
    }
    await _listenNative();
  }

  /// Stop the cloud recording, transcribe it, and hand the text to the agent.
  Future<void> _stopCloudCaptureAndSend() async {
    _captureTimer?.cancel();
    state = state.copyWith(
      isSarvamRecording: false,
      isListening: false,
      liveVoiceStatus: 'Transcribing…',
    );
    final captured = await _audio.stopRecording();
    if (!captured.ok || captured.audioBase64.isEmpty) {
      state = state.copyWith(error: captured.message, liveVoiceStatus: '');
      return;
    }
    await _transcribeAndSend(captured);
  }

  /// Send captured audio to the backend speech stack and dispatch the
  /// transcript to the conversation.
  Future<void> _transcribeAndSend(NativeAudioCaptureResult captured) async {
    try {
      final config = await ref.read(backendConfigProvider.future);
      if (!config.hasGateway) {
        state = state.copyWith(
          error: 'Connect a backend gateway to use voice.',
          liveVoiceStatus: '',
        );
        return;
      }
      final client = SarvamLiveVoiceClient(baseUrl: config.gatewayUrl);
      final stt = await client.transcribe(captured);
      client.close();
      final text = stt.transcript.trim();
      if (text.isEmpty) {
        state = state.copyWith(
          error: stt.error.isNotEmpty
              ? stt.error
              : 'Didn\'t catch that — tap the mic and try again.',
          liveVoiceStatus: '',
        );
        return;
      }
      state = state.copyWith(liveVoiceStatus: '');
      await send(text);
    } catch (error) {
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
        liveVoiceStatus: '',
      );
    }
  }

  /// On-device fallback recognizer — used only when no gateway is reachable.
  Future<void> _listenNative() async {
    _sttReady =
        _sttReady ||
        await _stt.initialize(
          onError: (_) {
            if (state.isListening) {
              state = state.copyWith(isListening: false, partial: '');
            }
          },
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && state.isListening) {
              state = state.copyWith(isListening: false);
            }
          },
        );
    if (!_sttReady) {
      state = state.copyWith(
        error: 'Microphone unavailable. Type to ALTER instead.',
        isListening: false,
      );
      return;
    }
    state = state.copyWith(isListening: true, partial: '', error: '');
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
      ),
      onResult: (r) {
        state = state.copyWith(partial: r.recognizedWords);
        if (r.finalResult) {
          final words = r.recognizedWords.trim();
          state = state.copyWith(isListening: false, partial: '');
          if (words.isNotEmpty) send(words);
        }
      },
    );
  }

  /// Pick the cloud model for a turn using on-device intent classification:
  /// reasoning-heavy requests get the stronger model; everyday commands stay on
  /// the fast, cheap one. The decision is made on-device (no cloud round-trip).
  Future<String> _routeModel(String input) async {
    final heavy = await ref.read(onDeviceAiProvider).needsDeepReasoning(input);
    return heavy ? 'gpt-4o' : 'gpt-4o-mini';
  }

  // --- The conversational tool-calling loop ---
  Future<void> send(String text) async {
    final input = text.trim();
    if (input.isEmpty || state.isThinking) return;

    final openai = ref.read(openAIServiceProvider);
    if (openai == null) {
      _push(AgentRole.user, input);
      await ref
          .read(persistentIntelligenceStoreProvider.notifier)
          .addMemory(
            source: 'agent_chat',
            title: input,
            summary: 'User message sent to ALTER.',
          );
      state = state.copyWith(isThinking: true, error: '');
      final backendReply = await _runBackendRuntime(input);
      if (backendReply != null) {
        _push(AgentRole.assistant, backendReply);
        state = state.copyWith(isThinking: false);
        await _speak(backendReply);
        return;
      }
      state = state.copyWith(isThinking: false);
      _push(
        AgentRole.assistant,
        'Connect the backend gateway or sign in with AI access to help.',
      );
      return;
    }

    _push(AgentRole.user, input);
    await ref
        .read(persistentIntelligenceStoreProvider.notifier)
        .addMemory(
          source: 'agent_chat',
          title: input,
          summary: 'User message sent to ALTER.',
        );
    _api.add({'role': 'user', 'content': input});
    await _loadRecall(input); // pull the user's twin memory into this turn
    state = state.copyWith(isThinking: true, error: '');

    // On-device mode: answer plain, private chats fully on the phone. Defers to
    // the cloud path below for anything needing tools or deep reasoning, or if
    // the local model isn't ready / fails to produce text.
    final localReply = await _tryOnDeviceAnswer(input);
    if (localReply != null && localReply.trim().isNotEmpty) {
      _api.add({'role': 'assistant', 'content': localReply});
      _push(AgentRole.assistant, localReply);
      state = state.copyWith(isThinking: false);
      await _speak(localReply);
      return;
    }

    try {
      // Model routing: harder, reasoning-heavy turns get the stronger model;
      // everyday turns stay on the fast, cheap one (decided on-device).
      final model = await _routeModel(input);
      for (var i = 0; i < 6; i++) {
        final resp = await openai.chatWithTools(
          messages: _withRecall(),
          tools: kAgentTools,
          model: model,
        );
        final content = (resp['content'] ?? '').toString();
        final toolCalls = resp['tool_calls'];

        if (toolCalls is List && toolCalls.isNotEmpty) {
          _api.add({
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
              args =
                  jsonDecode((fn['arguments'] ?? '{}').toString())
                      as Map<String, dynamic>;
            } catch (_) {
              args = {};
            }
            final toolMsg = AgentMessage(
              AgentRole.tool,
              agentToolLabel(name),
              pending: true,
            );
            _appendMessage(toolMsg);
            String result;
            try {
              result = await executeAgentTool(ref, name, args);
            } catch (e) {
              // A tool failing must NEVER leave a dangling tool_call: OpenAI
              // rejects the next turn ("tool_calls must be followed by tool
              // messages") and the whole chat wedges. Always record a response.
              result =
                  'Tool failed: ${e.toString().replaceFirst('Exception: ', '')}';
            }
            toolMsg.text = result;
            toolMsg.pending = false;
            _bump();
            _api.add({'role': 'tool', 'tool_call_id': id, 'content': result});
          }
          continue; // let the model react to the tool results
        }

        // Final spoken answer.
        _api.add({'role': 'assistant', 'content': content});
        _push(AgentRole.assistant, content);
        state = state.copyWith(isThinking: false);
        await _speak(content);
        return;
      }
      state = state.copyWith(isThinking: false);
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      _push(AgentRole.assistant, 'Something went wrong: ${state.error}');
    }
  }

  /// When On-device mode is on and a local model is loaded, answer plain
  /// conversational turns fully on the phone. Returns null to defer to the
  /// cloud (tools, deep reasoning, model not ready, or inference failure) so the
  /// existing path is unchanged in every other case.
  Future<String?> _tryOnDeviceAnswer(String input) async {
    if (!ref.read(alterAppControllerProvider).onDeviceMode) return null;
    if (!ref.read(gemmaModelProvider).isReady) return null;

    // Route with cheap heuristics (no inference) so deciding is instant; only a
    // plain 'chat' turn stays on-device, everything actionable/deep goes cloud.
    const router = HeuristicOnDeviceAi();
    final intent = await router.classifyIntent(input);
    const cloudIntents = {
      'schedule',
      'message',
      'call',
      'search',
      'navigate',
      'decision',
      'planning',
      'reflect',
    };
    if (cloudIntents.contains(intent)) return null;
    if (await router.needsDeepReasoning(input)) return null;

    return ref
        .read(gemmaModelProvider.notifier)
        .generate(_onDevicePrompt(), temperature: 0.6);
  }

  /// Builds a compact prompt for the on-device model from the recent turns
  /// (the latest user message is already the tail of [_api]).
  String _onDevicePrompt() {
    final buf = StringBuffer()
      ..writeln(
        "You are ALTER, a concise, friendly personal assistant running "
        "privately on the user's phone. Reply in 1-3 sentences. Do not invent "
        "facts about the user.",
      );
    final turns = _api
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .where((m) => (m['content'] ?? '').toString().trim().isNotEmpty)
        .toList();
    final tail = turns.length > 6 ? turns.sublist(turns.length - 6) : turns;
    for (final m in tail) {
      final who = m['role'] == 'user' ? 'User' : 'ALTER';
      buf.writeln('$who: ${m['content']}');
    }
    buf.write('ALTER:');
    return buf.toString();
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    // Mark "speaking" for the whole spoken duration so a "Hey ALTER" wake can't
    // open the mic and cut ALTER off. (awaitSpeakCompletion + the Sarvam
    // duration block keep these awaits open until playback actually finishes.)
    _speaking = true;
    try {
      final spokeWithSarvam = await _speakWithSarvam(text);
      if (spokeWithSarvam) return;
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52);
      await _tts.speak(text);
    } catch (_) {
    } finally {
      _speaking = false;
    }
  }

  Future<bool> _speakWithSarvam(String text) async {
    try {
      final config = await ref.read(backendConfigProvider.future);
      if (!config.hasGateway) return false;
      final client = SarvamLiveVoiceClient(baseUrl: config.gatewayUrl);
      final tts = await client.synthesize(
        text: text,
        targetLanguageCode: 'en-IN',
      );
      client.close();
      if (tts.audioBase64.isEmpty || tts.fallback) return false;
      final sw = Stopwatch()..start();
      final playback = await _audio.playAudioBase64(
        audioBase64: tts.audioBase64,
        filename: 'alter_sarvam_tts.wav',
      );
      if (!playback.ok) return false;
      // Block until playback actually finishes so hands-free won't hear itself.
      final remaining = playback.durationMs - sw.elapsedMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining + 150));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Secondary "Sarvam live voice" control. Now shares the same accurate
  /// record→transcribe path as the main mic button.
  Future<void> toggleSarvamLiveVoice() => toggleListening();

  void stopSpeaking() {
    _tts.stop();
    _audio.stopPlayback();
  }

  Future<String?> _runBackendRuntime(String input) async {
    final config = await ref.read(backendConfigProvider.future);
    if (!config.hasGateway) return null;
    final client = VoiceRuntimeApiClient();
    try {
      final result = await client.run(
        transcript: input,
        locale: 'en-US',
        profile: ref.read(userProfileProvider).asData?.value,
      );
      client.close();
      return result.displayResponse.isNotEmpty
          ? result.displayResponse
          : result.spokenResponse;
    } catch (error) {
      client.close();
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  void _push(AgentRole role, String text) =>
      _appendMessage(AgentMessage(role, text));

  void _appendMessage(AgentMessage m) {
    state = state.copyWith(messages: [...state.messages, m]);
  }

  // Force a state emit after mutating a message in place.
  void _bump() => state = state.copyWith(messages: [...state.messages]);

  // --- Digital twin: retrieve what ALTER has learned about the user ---
  Future<void> _loadRecall(String query) async {
    final recall = await _recallContext(query);
    _recallPrefix = recall.isEmpty
        ? const []
        : [
            <String, dynamic>{'role': 'system', 'content': recall},
          ];
  }

  /// Conversation sent to the model = base system + twin recall + history.
  List<Map<String, dynamic>> _withRecall() {
    final base = _repaired(_api);
    if (_recallPrefix.isEmpty || base.isEmpty) {
      return base;
    }
    return [base.first, ..._recallPrefix, ...base.skip(1)];
  }

  /// OpenAI rejects any assistant `tool_calls` message that isn't followed by a
  /// `tool` response for every id. If a prior turn ever left a call dangling,
  /// every subsequent send would 400 forever. Strip dangling calls and orphan
  /// tool messages so the conversation self-heals instead of staying wedged.
  List<Map<String, dynamic>> _repaired(List<Map<String, dynamic>> msgs) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final calls = m['tool_calls'];
      if (m['role'] == 'assistant' && calls is List && calls.isNotEmpty) {
        final ids = calls
            .map((c) => (c as Map)['id']?.toString())
            .whereType<String>()
            .toSet();
        var j = i + 1;
        final responded = <String>{};
        while (j < msgs.length && msgs[j]['role'] == 'tool') {
          final id = msgs[j]['tool_call_id']?.toString();
          if (id != null) responded.add(id);
          j++;
        }
        if (ids.difference(responded).isEmpty) {
          out.add(m);
          for (var k = i + 1; k < j; k++) {
            out.add(msgs[k]);
          }
        } else {
          // Dangling: keep only the assistant's text, drop the unanswered calls.
          final content = m['content'];
          if (content != null && content.toString().trim().isNotEmpty) {
            out.add({'role': 'assistant', 'content': content});
          }
        }
        i = j - 1;
      } else if (m['role'] == 'tool') {
        // Orphan tool message with no matching assistant call — drop it.
        continue;
      } else {
        out.add(m);
      }
    }
    return out;
  }

  Future<String> _recallContext(String query) async {
    try {
      final store = ref.read(persistentIntelligenceStoreProvider.notifier);
      final recent = await store.searchMemory('');
      final relevant = query.trim().isEmpty
          ? const <TwinMemoryRecord>[]
          : await store.searchMemory(query);
      final seen = <String>{};
      final picked = <TwinMemoryRecord>[];
      for (final m in [...relevant, ...recent]) {
        final key = '${m.source}|${m.title}';
        if (m.title.isEmpty || !seen.add(key)) continue;
        picked.add(m);
        if (picked.length >= 8) break;
      }
      final profile = ref.read(userProfileProvider).asData?.value;
      final who = (profile == null || profile.displayName.isEmpty)
          ? ''
          : 'About the user — name: ${profile.displayName}'
                '${profile.role.isNotEmpty ? ', role: ${profile.role}' : ''}'
                '${profile.goals.isNotEmpty ? '; goals: ${profile.goals.join(', ')}' : ''}'
                '${profile.skills.isNotEmpty ? '; skills: ${profile.skills.join(', ')}' : ''}.\n';
      if (picked.isEmpty && who.isEmpty) return '';
      final lines = picked
          .map((m) => '- [${m.source}] ${m.title}: ${m.summary}')
          .join('\n');
      // Privacy + context budget: redact obvious PII and cap length before this
      // personal context leaves the device for cloud reasoning.
      return const ContextPrivacyFilter().filter(
        '${who}Recent things ALTER has learned about this user from their '
        'phone and conversations:\n$lines\n'
        'Use this to make your answer personal and tailored to THIS person and '
        'their situation. Reference what you know when relevant; never invent '
        'facts not listed here.',
      );
    } catch (_) {
      return '';
    }
  }

  String _systemPrompt() {
    final profile = ref.read(userProfileProvider).asData?.value;
    final who = profile == null || profile.displayName.isEmpty
        ? ''
        : 'You are speaking with ${profile.displayName}'
              '${profile.role.isNotEmpty ? ', a ${profile.role}' : ''}. ';
    return 'You are ALTER, a proactive voice assistant living on the user\'s '
        'iQOO phone. ${who}You converse naturally and briefly — your replies are '
        'spoken aloud, so keep them short, warm, and clear. '
        'You build a private on-device memory of THIS person over time — their '
        'messages, notifications, decisions and habits. Relevant memory is given '
        'to you each turn under "About the user"/"Recent things ALTER has '
        'learned"; treat it as ground truth and tailor every answer to them '
        'specifically, like you genuinely know them. '
        'When the user asks you to DO something, USE A TOOL rather than just '
        'describing it. You can: check safety of a message/link/payment, plan '
        'the day, weigh a decision, convene a 5-voice council, call a number, '
        'send a WhatsApp/SMS, open a link, search the web, add a calendar '
        'event, open apps/settings, read visible screen text, click visible '
        'non-sensitive UI text, type into focused fields, scroll, and press '
        'Back/Home/Recents/Notifications. Before clicking in another app, read '
        'the screen first and choose visible labels rather than guessing. Device '
        'actions open or control only permissioned Android surfaces — after '
        'calling one, tell them what happened and what still needs their final tap. '
        'Never claim you actually sent, paid, called, or installed anything; you '
        'prepare it and the user confirms. Never directly click Send, Pay, '
        'Confirm, Install, Approve, Delete, or Allow; route that through OpenClaw '
        'with queue_openclaw_action or ask the user to tap it. If you need a phone number or detail '
        'you don\'t have, ask for it. After a tool returns, summarize the result '
        'in one or two spoken sentences.';
  }
}
