import 'dart:async';



import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/performance/on_device_resource_governor.dart';

import '../../contextos/application/gemma_model_manager.dart';

import '../../voice/application/voice_io_preference.dart';

import '../../voice/data/offline/offline_asr_service.dart';

import '../../voice/data/offline/offline_tts_service.dart';

import 'voice_runtime_controller.dart';



final voiceTurnOrchestratorProvider =

    Provider<VoiceTurnOrchestrator>((ref) => VoiceTurnOrchestrator(ref));



/// Serial voice turn: infer → speak → optional model unload on background.

class VoiceTurnOrchestrator {

  VoiceTurnOrchestrator(this._ref);



  final Ref _ref;



  Future<void> runVoiceTurn({

    required String transcript,

    required String locale,

    required Future<void> Function(String spoken) onSpeak,

  }) async {

    await _ref.read(voiceRuntimeControllerProvider.notifier).run(

          transcript: transcript,

          locale: locale,

        );

    final runtime = _ref.read(voiceRuntimeControllerProvider);

    final spoken = runtime.result?.spokenResponse ?? '';

    final errMsg = runtime.errorMessage;

    final toSpeak = spoken.isNotEmpty ? spoken : errMsg;

    if (toSpeak.trim().isNotEmpty) {

      await onSpeak(toSpeak.trim());

    }

  }



  Future<void> onAppPaused() async {

    if (!_ref.read(unloadOnBackgroundProvider)) return;

    if (_ref.read(keepGemmaInRamProvider)) {

      try {

        await _ref.read(offlineAsrServiceProvider).disposeEngines();

      } catch (_) {}

      try {

        await _ref.read(offlineTtsServiceProvider).disposeEngine();

      } catch (_) {}

      return;

    }

    await _ref.read(onDeviceResourceGovernorProvider.notifier).releaseAll();

    await _ref.read(gemmaModelProvider.notifier).unloadFromRam();

    try {

      await _ref.read(offlineAsrServiceProvider).disposeEngines();

    } catch (_) {}

    try {

      await _ref.read(offlineTtsServiceProvider).disposeEngine();

    } catch (_) {}

  }

}


