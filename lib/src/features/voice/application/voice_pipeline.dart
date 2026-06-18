import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/performance/on_device_resource_governor.dart';
import '../data/offline/offline_asr_service.dart';
import '../data/offline/offline_tts_service.dart';
import '../data/offline/offline_voice_model_manager.dart';
import '../data/sarvam_tts_client.dart';
import 'voice_io_preference.dart';

final voicePipelineProvider = Provider<VoicePipeline>((ref) {
  return VoicePipeline(ref);
});

/// Unified STT/TTS routing: offline sherpa → cloud Sarvam → OS fallback.
class VoicePipeline {
  VoicePipeline(this._ref);

  final Ref _ref;

  bool get _offlineOnly =>
      _ref.read(voiceIoPreferenceProvider) == VoiceIoMode.offlineOnly;

  bool get _offlineFirst =>
      _ref.read(voiceIoPreferenceProvider) != VoiceIoMode.cloudPreferred;

  Future<bool> get _online async =>
      _ref.read(connectivityServiceProvider).isOnline;

  Future<bool> get _cloudVoiceAllowed async {
    if (_offlineOnly) return false;
    if (!_ref.read(cloudVoiceEnabledProvider)) return false;
    return _online;
  }

  Future<String?> transcribeWithOsStt({
    required SpeechToText speech,
    required String speechLocale,
    required void Function(SpeechRecognitionResult result) onResult,
    Duration listenFor = const Duration(seconds: 18),
  }) async {
    await speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: speechLocale,
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
      onResult: onResult,
    );
    return null;
  }

  Future<String?> listenOneShot({
    required String locale,
    void Function(String partial)? onPartial,
    Duration maxDuration = const Duration(seconds: 18),
  }) async {
    final models = _ref.read(offlineVoiceModelManagerProvider);
    final offlineOk = models.isAsrReady && (_offlineFirst || !await _online);

    if (offlineOk) {
      try {
        await _ref
            .read(onDeviceResourceGovernorProvider.notifier)
            .acquire(OnDeviceResource.asr);
        final paths =
            await _ref.read(offlineVoiceModelManagerProvider.notifier).resolveAsrPaths();
        if (paths != null && paths.isValid) {
          final asr = _ref.read(offlineAsrServiceProvider);
          if (!asr.isInitialized) {
            await asr.init(paths);
          }
          final text = await asr.listenOneShot(
            onPartial: onPartial,
            maxDuration: maxDuration,
          );
          await asr.disposeEngines();
          await _ref
              .read(onDeviceResourceGovernorProvider.notifier)
              .release(OnDeviceResource.asr);
          if (text.trim().isNotEmpty) return text.trim();
        }
      } catch (_) {
        await _ref
            .read(onDeviceResourceGovernorProvider.notifier)
            .release(OnDeviceResource.asr);
      }
    }

    if (_offlineOnly) return null;
    return null; // Caller falls back to OS speech_to_text streaming.
  }

  Future<void> speak(
    String text, {
    required String locale,
    required FlutterTts osTts,
    required Future<void> Function(String) onFlutterTtsFallback,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final models = _ref.read(offlineVoiceModelManagerProvider);
    final offlineOk = models.isTtsReady && (_offlineFirst || !await _online);

    if (offlineOk) {
      try {
        await _ref
            .read(onDeviceResourceGovernorProvider.notifier)
            .acquire(OnDeviceResource.tts);
        final paths = await _ref
            .read(offlineVoiceModelManagerProvider.notifier)
            .resolveTtsPaths(locale);
        if (paths != null) {
          final tts = _ref.read(offlineTtsServiceProvider);
          if (!tts.isInitialized) {
            await tts.init(paths);
          }
          await tts.speak(trimmed);
          await tts.disposeEngine();
          await _ref
              .read(onDeviceResourceGovernorProvider.notifier)
              .release(OnDeviceResource.tts);
          return;
        }
        await _ref
            .read(onDeviceResourceGovernorProvider.notifier)
            .release(OnDeviceResource.tts);
      } catch (_) {
        await _ref
            .read(onDeviceResourceGovernorProvider.notifier)
            .release(OnDeviceResource.tts);
      }
    }

    if (await _cloudVoiceAllowed) {
      try {
        await _ref.read(sarvamTtsClientProvider).speak(
              trimmed,
              targetLanguageCode: locale,
              onFlutterTtsFallback: onFlutterTtsFallback,
            );
        return;
      } catch (_) {}
    }

    if (!_offlineOnly) {
      await onFlutterTtsFallback(trimmed);
    } else {
      await osTts.speak(trimmed);
    }
  }
}
