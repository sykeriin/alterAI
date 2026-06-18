import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/gemma_model_config.dart';
import '../../../core/config/gemma_model_spec.dart';
import '../../../core/config/gemma_model_validation.dart';
import '../../../core/performance/device_tier.dart';
import '../../../core/performance/on_device_resource_governor.dart';
import '../../voice/application/voice_backend_preference.dart';
import '../../voice/application/voice_io_preference.dart';
import '../data/gemma_edge_engine.dart';
import '../data/local_gemma_engine.dart';

enum GemmaStatus {
  checking,
  notInstalled,
  installed,
  downloading,
  loading,
  ready,
  unsupported,
  error,
}

class GemmaModelState {
  const GemmaModelState({
    this.status = GemmaStatus.checking,
    this.progress = 0,
    this.message = '',
  });

  final GemmaStatus status;
  final double progress;
  final String message;

  bool get isReady => status == GemmaStatus.ready;

  bool get modelOnDisk =>
      status == GemmaStatus.ready ||
      status == GemmaStatus.installed ||
      status == GemmaStatus.loading;

  bool get usesPatternCheck => !isReady;

  String get statusLabel => switch (status) {
        GemmaStatus.ready => 'Gemma 4 active',
        GemmaStatus.installed => 'Downloaded · not loaded',
        GemmaStatus.notInstalled => 'Not downloaded · pattern check',
        GemmaStatus.downloading => 'Downloading Gemma 4',
        GemmaStatus.loading => 'Loading into RAM',
        GemmaStatus.checking => 'Checking',
        GemmaStatus.unsupported => 'Pattern check only (web)',
        GemmaStatus.error => 'Error · pattern check',
      };

  String get edgePillLabel => isReady ? 'Gemma 4 on-device' : 'Pattern check';

  GemmaModelState copyWith({
    GemmaStatus? status,
    double? progress,
    String? message,
  }) =>
      GemmaModelState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        message: message ?? this.message,
      );
}

final gemmaModelProvider =
    NotifierProvider<GemmaModelManager, GemmaModelState>(GemmaModelManager.new);

class GemmaModelManager extends Notifier<GemmaModelState> {
  InferenceModel? _model;
  InferenceModel? get model => _model;
  bool _downloadInFlight = false;
  Timer? _idleUnloadTimer;
  static const _idleUnloadDuration = Duration(minutes: 5);

  // Serializes inference: flutter_gemma runs one session at a time per model.
  Future<void> _lock = Future<void>.value();

  /// Run a single prompt through the loaded on-device model.
  Future<String?> generate(
    String prompt, {
    double temperature = 0.4,
    int topK = 40,
  }) {
    final model = _model;
    if (!state.isReady || model == null) return Future.value(null);
    final run = _lock.then((_) async {
      try {
        final session = await model.createSession(
          temperature: temperature,
          topK: topK,
        );
        await session.addQueryChunk(Message.text(text: prompt, isUser: true));
        final out = await session.getResponse();
        await session.close();
        final trimmed = out.trim();
        return trimmed.isEmpty ? null : trimmed;
      } catch (_) {
        return null;
      }
    });
    _lock = run.then((_) {}, onError: (_) {});
    return run;
  }

  @override
  GemmaModelState build() {
    if (kIsWeb) {
      return const GemmaModelState(
        status: GemmaStatus.unsupported,
        message: 'Gemma 4 runs on the Android/iOS build, not web.',
      );
    }
    ref.read(onDeviceResourceGovernorProvider.notifier).registerDisposer(
          OnDeviceResource.llm,
          unloadFromRam,
        );
    Future.microtask(_bootstrap);
    return const GemmaModelState(status: GemmaStatus.checking);
  }

  Future<void> _bootstrap() async {
    await checkInstalled();
    if (ref.read(voiceBackendPreferenceProvider) == VoiceBackend.onDevice &&
        ref.read(keepGemmaInRamProvider) &&
        state.modelOnDisk &&
        !state.isReady) {
      await ensureLoaded();
    }
  }

  void _resetIdleUnloadTimer() {
    _idleUnloadTimer?.cancel();
    if (!state.isReady || ref.read(keepGemmaInRamProvider)) return;
    _idleUnloadTimer = Timer(_idleUnloadDuration, () {
      unawaited(unloadFromRam());
    });
  }

  Future<void> checkInstalled() async {
    if (kIsWeb) return;
    try {
      final installed = await FlutterGemma.listInstalledModels();
      if (installed.isEmpty) {
        state = const GemmaModelState(
          status: GemmaStatus.notInstalled,
          message: 'Download Gemma 4 E4B below (~3 GB, no token).',
        );
        return;
      }
      final validationError = await _validateInstalledModels(installed);
      if (validationError != null) {
        await remove();
        state = GemmaModelState(status: GemmaStatus.error, message: validationError);
        return;
      }
      state = GemmaModelState(
        status: GemmaStatus.installed,
        message:
            'Gemma 4 on disk (${installed.first}). Tap Load into RAM when ready.',
      );
    } catch (e) {
      state = GemmaModelState(
        status: GemmaStatus.notInstalled,
        message: e.toString(),
      );
    }
  }

  Future<void> _ensureSdkInitialized() async {
    await FlutterGemma.initialize();
  }

  Future<String?> _validateInstalledModels(List<String> modelIds) async {
    for (final id in modelIds) {
      final incompatible = GemmaModelSpec.androidIncompatibility(id);
      if (incompatible != null) return incompatible;
      final error = await GemmaModelValidation.validateInstalledModel(id);
      if (error != null) return error;
    }
    return null;
  }

  Future<void> download({String? url}) async {
    if (kIsWeb || _downloadInFlight) return;
    _downloadInFlight = true;
    final resolvedUrl = (url ?? kDefaultGemma4Url).trim();
    if (resolvedUrl.isEmpty) {
      _downloadInFlight = false;
      state = const GemmaModelState(
        status: GemmaStatus.error,
        message: 'Model URL is empty.',
      );
      return;
    }

    state = const GemmaModelState(status: GemmaStatus.downloading, progress: 0);
    try {
      await _ensureSdkInitialized();
      final spec = GemmaModelSpec.forUrl(resolvedUrl);
      await FlutterGemma.installModel(
        modelType: spec.modelType,
        fileType: spec.fileType,
      )
          .fromNetwork(resolvedUrl, foreground: true)
          .withProgress((p) {
        final frac = (p is num ? p.toDouble() : 0) / 100.0;
        state = state.copyWith(
          status: GemmaStatus.downloading,
          progress: frac.clamp(0, 1),
        );
      }).install();

      final installed = await FlutterGemma.listInstalledModels();
      final validationError = await _validateInstalledModels(installed);
      if (validationError != null) {
        await remove();
        throw StateError(validationError);
      }
      await _load();
    } catch (e) {
      state = GemmaModelState(
        status: GemmaStatus.error,
        message: 'Download failed: $e',
      );
    } finally {
      _downloadInFlight = false;
    }
  }

  Future<void> _load() async {
    state = const GemmaModelState(
      status: GemmaStatus.loading,
      message: 'Loading Gemma 4 into RAM (first time may take several minutes)…',
    );
    try {
      final installed = await FlutterGemma.listInstalledModels();
      if (installed.isEmpty) {
        state = const GemmaModelState(status: GemmaStatus.notInstalled);
        return;
      }

      final validationError = await _validateInstalledModels(installed);
      if (validationError != null) {
        await remove();
        state = GemmaModelState(status: GemmaStatus.error, message: validationError);
        return;
      }

      final maxTokens = maxTokensForTier(detectDeviceTier());
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.gpu,
      ).timeout(
        const Duration(minutes: 15),
        onTimeout: () => throw TimeoutException(
          'Load timed out. Gemma 4 E4B can take 5–15 min on first load — keep the app open.',
        ),
      );
      state = const GemmaModelState(
        status: GemmaStatus.ready,
        message: 'Gemma 4 is running on-device for voice and edge analysis.',
      );
      _resetIdleUnloadTimer();
      ref.invalidate(localGemmaEngineProvider);
    } catch (e) {
      _model = null;
      final installed = await FlutterGemma.listInstalledModels();
      final raw = e.toString();
      final zipCorrupt = raw.contains('Unable to open zip');
      if (zipCorrupt) await remove();
      state = GemmaModelState(
        status: zipCorrupt || installed.isEmpty
            ? GemmaStatus.error
            : GemmaStatus.installed,
        message: _loadErrorMessage(e, installed),
      );
      ref.invalidate(localGemmaEngineProvider);
    }
  }

  String _loadErrorMessage(Object error, List<String> installed) {
    final raw = error.toString();
    final name = installed.isNotEmpty ? installed.first : 'model';
    final incompatible =
        name != 'model' ? GemmaModelSpec.androidIncompatibility(name) : null;
    if (incompatible != null) return incompatible;
    if (raw.contains('Unable to open zip')) {
      return 'Model file corrupt or wrong format ($name). Remove and download '
          'the .litertlm URL (not .task).';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return raw.replaceFirst('TimeoutException: ', '');
    }
    return 'Load failed: $raw';
  }

  Future<void> loadIntoRam() async {
    if (kIsWeb || state.isReady) return;
    await _load();
  }

  Future<bool> ensureLoaded() async {
    if (kIsWeb) return false;
    if (state.isReady && _model != null) {
      _resetIdleUnloadTimer();
      return true;
    }
    try {
      final installed = await FlutterGemma.listInstalledModels();
      if (installed.isEmpty) return false;
      await _load();
      return state.isReady;
    } catch (_) {
      return false;
    }
  }

  Future<void> unloadFromRam() async {
    _idleUnloadTimer?.cancel();
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    if (state.status == GemmaStatus.ready) {
      state = const GemmaModelState(
        status: GemmaStatus.installed,
        message: 'Unloaded from RAM. Pattern check active until you load again.',
      );
    }
    ref.invalidate(localGemmaEngineProvider);
  }

  Future<void> remove() async {
    try {
      await _model?.close();
      final installed = await FlutterGemma.listInstalledModels();
      for (final id in installed) {
        await FlutterGemma.uninstallModel(id);
      }
    } catch (_) {}
    _model = null;
    state = const GemmaModelState(status: GemmaStatus.notInstalled);
    ref.invalidate(localGemmaEngineProvider);
  }
}

final localGemmaEngineProvider = Provider<LocalGemmaEngine>((ref) {
  final gemma = ref.watch(gemmaModelProvider);
  final manager = ref.read(gemmaModelProvider.notifier);
  if (gemma.isReady && manager.model != null) {
    return GemmaEdgeEngine(manager.model!);
  }
  return const HeuristicGemmaEngine();
});

final edgeIsRealGemmaProvider = Provider<bool>(
  (ref) => ref.watch(gemmaModelProvider).isReady,
);
