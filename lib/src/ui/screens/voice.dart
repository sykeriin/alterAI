import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:alter/src/core/errors/user_facing_error.dart';
import 'package:alter/src/features/voice/application/voice_runtime_controller.dart';
import 'package:alter/src/features/voice/application/voice_backend_preference.dart';
import 'package:alter/src/features/permissions/data/permission_hub_bridge.dart';
import 'package:alter/src/features/profile/application/profile_provider.dart';
import 'package:alter/src/features/voice/application/voice_stt_helper.dart';
import 'package:alter/src/features/voice/application/voice_pipeline.dart';
import 'package:alter/src/features/voice/application/voice_io_preference.dart';
import 'package:alter/src/features/voice/application/voice_turn_orchestrator.dart';
import 'package:alter/src/features/voice/domain/wake_word.dart';
import 'package:alter/src/ui/routes.dart';
import 'package:alter/src/ui/theme.dart';
import 'package:alter/src/ui/widgets.dart';
import 'package:alter/src/ui/screens/main_shell.dart';

enum VoiceMode { idle, listening, speaking }

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  VoiceMode _mode = VoiceMode.idle;
  String _userText = '';
  String _assistantText = '';
  String _status = 'Tap the mic to speak';
  bool _assistantMode = false;
  bool _wakeProcessing = false;
  bool _sttReady = false;
  bool _micGranted = false;

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _speechLocale = 'en_US';
  bool _heardThisSession = false;
  bool _runtimeTriggered = false;
  bool _speakingInProgress = false;

  late final AnimationController _eqWave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  String get _profileLocale {
    final langs = ref.read(userProfileProvider).asData?.value?.languages;
    if (langs != null && langs.isNotEmpty) {
      return _localeForLanguage(langs.first);
    }
    return 'en-IN';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureSpeechReady());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(ref.read(voiceTurnOrchestratorProvider).onAppPaused());
    }
    if (state == AppLifecycleState.resumed) {
      _micGranted = false;
      _sttReady = false;
      unawaited(_ensureSpeechReady());
    }
  }

  Future<bool> _ensureMicPermission() async {
    if (_micGranted) return true;
    final bridge = PermissionHubBridge();
    var statuses = await bridge.getStatuses();
    if (statuses.isEmpty || statuses['microphone']?.granted != true) {
      statuses = await bridge.request('microphone');
    }
    _micGranted = statuses['microphone']?.granted == true;
    // If the native bridge is unavailable, let speech_to_text try anyway.
    if (!_micGranted && statuses.isNotEmpty && mounted) {
      setState(() => _status = 'Microphone permission required — enable in Settings.');
      return false;
    }
    return true;
  }

  Future<bool> _ensureSpeechReady() async {
    if (!await _ensureMicPermission()) return false;
    if (_sttReady) return true;
    final available = await _speech.initialize(
      onError: (err) {
        if (!mounted) return;
        final friendly = UserFacingError.fromSpeechOrRaw(err.errorMsg);
        setState(() => _status = friendly.message);
        if (_assistantMode) _rearmWakeLoop();
      },
      onStatus: _onSpeechStatus,
    );
    if (!available) {
      if (mounted) {
        setState(() => _status = 'Speech unavailable on this device.');
      }
      return false;
    }
    _speechLocale = await VoiceSttHelper.resolveLocale(
      _speech,
      preferred: _profileLocale,
    );
    _micGranted = true;
    _sttReady = true;
    return true;
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty || _speakingInProgress) return;
    _speakingInProgress = true;
    await _speech.stop();
    if (mounted) setState(() => _mode = VoiceMode.speaking);
    try {
      await ref.read(voicePipelineProvider).speak(
            text,
            locale: _profileLocale,
            osTts: _tts,
            onFlutterTtsFallback: (t) async {
              await _tts.stop();
              await _tts.awaitSpeakCompletion(true);
              await _tts.setLanguage(_profileLocale);
              await _tts.setSpeechRate(0.52);
              await _tts.speak(t);
              await _tts.awaitSpeakCompletion(true);
            },
          );
    } catch (_) {
      try {
        await _tts.stop();
        await _tts.awaitSpeakCompletion(true);
        await _tts.setLanguage(_profileLocale);
        await _tts.setSpeechRate(0.52);
        await _tts.speak(text);
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {}
    } finally {
      _speakingInProgress = false;
      if (!mounted) return;
      if (_assistantMode) {
        setState(() => _mode = VoiceMode.listening);
        _rearmWakeLoop();
      } else {
        setState(() => _mode = VoiceMode.idle);
      }
    }
  }

  Future<void> _runVoiceRuntime(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty) return;
    if (ref.read(voiceRuntimeControllerProvider).isRunning ||
        _speakingInProgress) {
      return;
    }
    await _speech.stop();
    setState(() {
      _userText = cleaned;
      _assistantText = '';
      _mode = VoiceMode.speaking;
      _status = 'Alter is responding';
    });
    _scrollToBottom();
    await ref.read(voiceTurnOrchestratorProvider).runVoiceTurn(
          transcript: cleaned,
          locale: _profileLocale,
          onSpeak: _speak,
        );
    if (!mounted) return;
    final runtime = ref.read(voiceRuntimeControllerProvider);
    final display = runtime.result?.displayResponse ??
        runtime.result?.spokenResponse ??
        runtime.errorMessage;
    if (display.isNotEmpty) {
      setState(() {
        _assistantText = display;
        if (runtime.errorMessage.isNotEmpty) {
          _status = runtime.errorMessage;
        } else if (!_assistantMode) {
          _status = 'Tap the mic to speak';
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _submitTypedText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    FocusScope.of(context).unfocus();
    await _runVoiceRuntime(text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eqWave.dispose();
    _speech.cancel();
    _tts.stop();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _startOneShotListening() async {
    if (!await _ensureSpeechReady()) {
      setState(() => _status = 'Speech unavailable — type in Agent instead.');
      return;
    }
    _assistantMode = false;
    _wakeProcessing = false;
    _heardThisSession = false;
    _runtimeTriggered = false;
    await _speech.stop();

    final offlineText = await ref.read(voicePipelineProvider).listenOneShot(
          locale: _profileLocale,
          onPartial: (partial) {
            if (!mounted) return;
            if (partial.isNotEmpty) {
              _heardThisSession = true;
              setState(() => _userText = partial);
            }
          },
        );
    if (offlineText != null && offlineText.trim().isNotEmpty) {
      _runtimeTriggered = true;
      await _runVoiceRuntime(offlineText);
      return;
    }

    setState(() {
      _mode = VoiceMode.listening;
      _status = 'Listening… speak now';
    });
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _speechLocale,
          listenFor: const Duration(seconds: 18),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (!mounted) return;
          if (result.recognizedWords.isNotEmpty) {
            _heardThisSession = true;
            setState(() => _userText = result.recognizedWords);
          }
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _runtimeTriggered = true;
            _speech.stop();
            unawaited(_runVoiceRuntime(result.recognizedWords));
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not start microphone — check permission.');
      }
    }
  }

  Future<void> _toggleAssistantMode() async {
    if (_assistantMode) {
      _assistantMode = false;
      await _speech.stop();
      setState(() {
        _mode = VoiceMode.idle;
        _status = 'Tap the mic to speak';
      });
      return;
    }
    if (!await _ensureSpeechReady()) return;
    _assistantMode = true;
    setState(() {
      _status = 'Listening for "Hey Alter"';
      _mode = VoiceMode.listening;
    });
    unawaited(_speak('Hey Alter is ready.'));
  }

  Future<void> _startWakeLoop() async {
    if (!_assistantMode ||
        _wakeProcessing ||
        _speakingInProgress ||
        ref.read(voiceRuntimeControllerProvider).isRunning ||
        !mounted) {
      return;
    }
    if (_speech.isListening) await _speech.stop();
    setState(() {
      _mode = VoiceMode.listening;
      _status = 'Listening for "Hey Alter"';
    });
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: _speechLocale,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
      onResult: _onWakeResult,
    );
  }

  void _onWakeResult(SpeechRecognitionResult result) {
    if (!mounted || !_assistantMode || _wakeProcessing) return;
    final wake = WakeWord.parse(result.recognizedWords);
    if (!wake.detected) return;
    _wakeProcessing = true;
    unawaited(_speech.stop());
    unawaited(_processWakeMatch(wake));
  }

  Future<void> _processWakeMatch(WakeWordMatch wake) async {
    if (!mounted) return;
    if (!wake.hasCommand) {
      final ioMode = ref.read(voiceIoPreferenceProvider);
      if (ioMode != VoiceIoMode.cloudPreferred) {
        final heard = await ref.read(voicePipelineProvider).listenOneShot(
              locale: _profileLocale,
              maxDuration: const Duration(seconds: 12),
            );
        if (heard != null && heard.trim().isNotEmpty) {
          await _runVoiceRuntime(heard.trim());
          _wakeProcessing = false;
          return;
        }
      }
      await _speak('I am listening.');
      _wakeProcessing = false;
      return;
    }
    await _runVoiceRuntime(wake.runtimeTranscript);
    _wakeProcessing = false;
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if ((status == 'done' || status == 'notListening') &&
        !_assistantMode &&
        _mode == VoiceMode.listening) {
      final partial = _userText.trim();
      if (!_runtimeTriggered &&
          partial.isNotEmpty &&
          !_speakingInProgress &&
          !ref.read(voiceRuntimeControllerProvider).isRunning) {
        _runtimeTriggered = true;
        unawaited(_runVoiceRuntime(partial));
        return;
      }
      if (!_heardThisSession) {
        setState(() {
          _mode = VoiceMode.idle;
          _status = 'Didn\'t catch that — tap and speak again.';
        });
      }
      return;
    }
    if ((status == 'done' || status == 'notListening') &&
        _assistantMode &&
        !_wakeProcessing) {
      _rearmWakeLoop();
    }
  }

  void _rearmWakeLoop() {
    if (!_assistantMode || !mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted ||
          !_assistantMode ||
          _wakeProcessing ||
          _speakingInProgress ||
          ref.read(voiceRuntimeControllerProvider).isRunning) {
        return;
      }
      unawaited(_startWakeLoop());
    });
  }


  void _onOrbTap() {
    if (ref.read(voiceRuntimeControllerProvider).isRunning ||
        _speakingInProgress) {
      return;
    }
    if (_assistantMode) {
      unawaited(_toggleAssistantMode());
      return;
    }
    unawaited(_startOneShotListening());
  }

  @override
  Widget build(BuildContext context) {
    final shell = MainShell.of(context);
    final runtime = ref.watch(voiceRuntimeControllerProvider);
    final backend = ref.watch(voiceBackendPreferenceProvider);

    ref.listen(voiceRuntimeControllerProvider, (prev, next) {
      // UI-only updates; TTS is handled by VoiceTurnOrchestrator.
      if (prev?.isRunning == true && !next.isRunning) {
        final display = next.result?.displayResponse ??
            (next.errorMessage.isNotEmpty
                ? next.errorMessage
                : next.result?.spokenResponse ?? '');
        if (display.isEmpty) {
          if (mounted && !_assistantMode) {
            setState(() => _mode = VoiceMode.idle);
          }
          return;
        }
        if (mounted) {
          setState(() {
            _assistantText = display;
            if (next.errorMessage.isNotEmpty) {
              _status = next.errorMessage;
            } else if (!_assistantMode) {
              _status = 'Tap the mic to speak';
            }
          });
        }
        _scrollToBottom();
      }
    });

    final mode = runtime.isRunning
        ? VoiceMode.speaking
        : (_speakingInProgress
              ? VoiceMode.speaking
              : (_mode == VoiceMode.listening
                    ? VoiceMode.listening
                    : _mode));

    final label = runtime.isRunning
        ? 'Alter is responding'
        : _speakingInProgress
        ? 'Alter is speaking'
        : _status;

    final media = MediaQuery.of(context);
    // MainShell GlassNavBar: 26 offset + ~68 pill + system inset.
    final navBarClearance = 26 + media.padding.bottom + 72;
    final keyboardInset = media.viewInsets.bottom;

    final eqMode = switch (mode) {
      VoiceMode.listening => VoiceEqualizerMode.listening,
      VoiceMode.speaking => VoiceEqualizerMode.speaking,
      VoiceMode.idle => VoiceEqualizerMode.idle,
    };

    return ValueListenableBuilder<bool>(
      valueListenable: AlterUiTheme.isLight,
      builder: (context, light, __) {
        final voiceBg = light
            ? const [Color(0xFFECE8F6), Color(0xFFF4F1FB), Color(0xFFEEF0F8)]
            : const [Color(0xFF1A1430), Color(0xFF0D0A16), Color(0xFF060409)];

        return GradientScaffold(
      bgColors: voiceBg,
      bgCenter: const Alignment(0.0, -0.2),
      bgStops: const [0.0, 0.55, 1.0],
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: PrimaryHeader(
                  title: 'VOICE',
                  starTitle: true,
                  showAvatar: false,
                  onGear: shell.openSettings,
                ),
              ),
              Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _onOrbTap,
                          onLongPress: () => unawaited(_toggleAssistantMode()),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: mode == VoiceMode.idle
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        AppColors.lime,
                                        AppColors.limeDeep,
                                      ],
                                    ),
                              color: mode == VoiceMode.idle
                                  ? AppColors.white(0.08)
                                  : null,
                              border: Border.all(
                                color: mode == VoiceMode.listening
                                    ? AppColors.cyan
                                    : mode == VoiceMode.speaking
                                    ? AppColors.lime
                                    : AppColors.white(0.18),
                                width: mode == VoiceMode.idle ? 1 : 1.5,
                              ),
                            ),
                            child: Icon(
                              mode == VoiceMode.speaking
                                  ? Icons.volume_up_rounded
                                  : mode == VoiceMode.listening
                                  ? Icons.mic
                                  : Icons.mic_none_outlined,
                              color: mode == VoiceMode.idle
                                  ? AppColors.white(0.75)
                                  : AppColors.bg,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: AppText.body(15, weight: FontWeight.w700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _assistantMode
                                    ? 'Long-press mic to turn off Hey Alter'
                                    : voiceBackendSubtitle(backend),
                                style: AppText.body(
                                  12,
                                  color: AppColors.white(0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: RainbowEqualizer(
                      mode: eqMode,
                      animation: _eqWave,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: _scrollCtrl,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                      children: [
                        if (_userText.isEmpty && _assistantText.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 32, bottom: 16),
                            child: Text(
                              'Ask Alter anything — tap the mic or type below.',
                              textAlign: TextAlign.center,
                              style: AppText.body(
                                14,
                                color: AppColors.white(0.42),
                                height: 1.5,
                              ),
                            ),
                          ),
                        if (_userText.isNotEmpty) ...[
                          _bubble(_userText, true, null),
                          const SizedBox(height: 12),
                        ],
                        if (_assistantText.isNotEmpty)
                          _bubble(
                            _assistantText,
                            false,
                            LinearGradient(
                              colors: [
                                AppColors.lime.withValues(alpha: 0.16),
                                AppColors.purple.withValues(alpha: 0.14),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: light
                          ? const Color(0xFFF4F1FB).withValues(alpha: 0.96)
                          : const Color(0xFF0D0A16).withValues(alpha: 0.96),
                      border: Border(
                        top: BorderSide(color: AppColors.white(0.10)),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 10, 18, 10 + navBarClearance),
                      child: _buildTextInput(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white(0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.white(0.16)),
      ),
      padding: const EdgeInsets.only(left: 18, right: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_submitTypedText()),
              style: AppText.body(14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type a message to ALTER…',
                hintStyle: AppText.body(14, color: AppColors.white(0.4)),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => unawaited(_submitTypedText()),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.arrow_upward, size: 18, color: AppColors.lime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool me, Gradient? grad) {
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (me ? 0.78 : 0.82),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: me ? AppColors.white(0.1) : null,
          gradient: grad,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(me ? 20 : 6),
            bottomRight: Radius.circular(me ? 6 : 20),
          ),
          border: Border.all(
            color: me
                ? AppColors.white(0.14)
                : AppColors.lime.withValues(alpha: 0.25),
          ),
        ),
        child: Text(text, style: AppText.body(14, height: 1.5)),
      ),
    );
  }
}

String _localeForLanguage(String language) {
  final normalized = language.trim().toLowerCase();
  if (normalized.contains('hi') || normalized == 'hindi') return 'hi-IN';
  if (normalized.contains('ta') || normalized == 'tamil') return 'ta-IN';
  if (normalized.contains('te') || normalized == 'telugu') return 'te-IN';
  if (normalized.contains('kn') || normalized == 'kannada') return 'kn-IN';
  if (normalized.contains('ml') || normalized == 'malayalam') return 'ml-IN';
  if (normalized.contains('mr') || normalized == 'marathi') return 'mr-IN';
  if (normalized.contains('bn') || normalized == 'bengali') return 'bn-IN';
  if (normalized.contains('gu') || normalized == 'gujarati') return 'gu-IN';
  if (normalized.contains('pa') || normalized == 'punjabi') return 'pa-IN';
  if (normalized.contains('es') || normalized == 'spanish') return 'es-ES';
  if (normalized.contains('ja') || normalized == 'japanese') return 'ja-JP';
  if (normalized.contains('fr') || normalized == 'french') return 'fr-FR';
  if (normalized.contains('de') || normalized == 'german') return 'de-DE';
  if (normalized.contains('en') || normalized == 'english') return 'en-IN';
  if (RegExp(r'^[a-z]{2}-[A-Z]{2}$').hasMatch(language)) return language;
  return 'en-IN';
}
