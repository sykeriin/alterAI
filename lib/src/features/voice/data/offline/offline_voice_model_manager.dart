import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/performance/device_tier.dart';
import 'offline_voice_config.dart';
import 'offline_voice_downloader.dart';

enum OfflineVoiceStatus { checking, notInstalled, downloading, ready, error }

class OfflineVoiceModelState {
  const OfflineVoiceModelState({
    this.status = OfflineVoiceStatus.checking,
    this.progress = 0,
    this.message = '',
    this.asrReady = false,
    this.ttsReady = false,
    this.installedAsrId = '',
    this.installedTtsIds = const {},
  });

  final OfflineVoiceStatus status;
  final double progress;
  final String message;
  final bool asrReady;
  final bool ttsReady;
  final String installedAsrId;
  final Set<String> installedTtsIds;

  bool get isAsrReady => asrReady;
  bool get isTtsReady => ttsReady;

  OfflineVoiceModelState copyWith({
    OfflineVoiceStatus? status,
    double? progress,
    String? message,
    bool? asrReady,
    bool? ttsReady,
    String? installedAsrId,
    Set<String>? installedTtsIds,
  }) =>
      OfflineVoiceModelState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        message: message ?? this.message,
        asrReady: asrReady ?? this.asrReady,
        ttsReady: ttsReady ?? this.ttsReady,
        installedAsrId: installedAsrId ?? this.installedAsrId,
        installedTtsIds: installedTtsIds ?? this.installedTtsIds,
      );
}

final offlineVoiceModelManagerProvider =
    NotifierProvider<OfflineVoiceModelManager, OfflineVoiceModelState>(
  OfflineVoiceModelManager.new,
);

class OfflineVoiceModelManager extends Notifier<OfflineVoiceModelState> {
  static const _prefsAsrKey = 'alter_offline_asr_installed';
  static const _prefsTtsKey = 'alter_offline_tts_installed';

  http.Client? _client;
  String? _rootDir;

  @override
  OfflineVoiceModelState build() {
    if (kIsWeb) {
      return const OfflineVoiceModelState(
        status: OfflineVoiceStatus.error,
        message: 'Offline voice models require a mobile build.',
      );
    }
    Future.microtask(refresh);
    return const OfflineVoiceModelState(status: OfflineVoiceStatus.checking);
  }

  Future<String> _root() async {
    if (_rootDir != null) return _rootDir!;
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = p.join(docs.path, 'offline_voice');
    await Directory(_rootDir!).create(recursive: true);
    return _rootDir!;
  }

  Future<void> refresh() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final asrId = prefs.getString(_prefsAsrKey) ?? '';
    final ttsRaw = prefs.getStringList(_prefsTtsKey) ?? const [];
    final root = await _root();

    final asrReady = asrId.isNotEmpty && await _validateAsr(root, asrId);
    final ttsIds = <String>{};
    for (final id in ttsRaw) {
      if (await _validateTts(root, id)) ttsIds.add(id);
    }

    state = OfflineVoiceModelState(
      status: asrReady || ttsIds.isNotEmpty
          ? OfflineVoiceStatus.ready
          : OfflineVoiceStatus.notInstalled,
      asrReady: asrReady,
      ttsReady: ttsIds.isNotEmpty,
      installedAsrId: asrReady ? asrId : '',
      installedTtsIds: ttsIds,
      message: asrReady || ttsIds.isNotEmpty
          ? 'Offline voice models ready.'
          : 'Download models for offline speech.',
    );
  }

  Future<bool> _validateAsr(String root, String bundleId) async {
    final dir = p.join(root, bundleId);
    final model = await OfflineVoiceDownloader.findFile(dir, '.onnx');
    final tokens = await OfflineVoiceDownloader.findFile(dir, 'tokens.txt');
    final vad = File(p.join(root, 'vad', 'silero_vad.onnx'));
    return model != null && tokens != null && await vad.exists();
  }

  Future<bool> _validateTts(String root, String bundleId) async {
    final dir = p.join(root, bundleId);
    final model = await OfflineVoiceDownloader.findFile(dir, '.onnx');
    final tokens = await OfflineVoiceDownloader.findFile(dir, 'tokens.txt');
    final espeak = await OfflineVoiceDownloader.findDirectoryNamed(dir, 'espeak-ng-data');
    return model != null && tokens != null && espeak != null;
  }

  Future<void> downloadAsrBundle({DeviceTier? tier}) async {
    if (kIsWeb) return;
    final deviceTier = tier ?? detectDeviceTier();
    final bundle = asrBundleForTier(deviceTier);
    await _downloadBundle(bundle, alsoDownloadVad: true, markAsr: bundle.id);
  }

  Future<void> downloadTtsBundle(String locale) async {
    if (kIsWeb) return;
    final bundle = ttsBundleForLocale(locale);
    await _downloadBundle(bundle, markTts: bundle.id);
  }

  Future<void> _downloadBundle(
    OfflineVoiceBundle bundle, {
    bool alsoDownloadVad = false,
    String? markAsr,
    String? markTts,
  }) async {
    _client ??= http.Client();
    final root = await _root();
    final dest = p.join(root, bundle.id);
    state = state.copyWith(
      status: OfflineVoiceStatus.downloading,
      progress: 0,
      message: 'Downloading ${bundle.label}…',
    );
    try {
      final downloader = OfflineVoiceDownloader(_client!);
      await downloader.downloadArchive(
        url: bundle.archiveUrl,
        destRoot: dest,
        onProgress: (p) => state = state.copyWith(progress: p),
      );
      if (alsoDownloadVad) {
        final vadDir = p.join(root, 'vad');
        await downloader.downloadArchive(
          url: kVadSileroUrl,
          destRoot: vadDir,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      if (markAsr != null) {
        await prefs.setString(_prefsAsrKey, markAsr);
      }
      if (markTts != null) {
        final existing = prefs.getStringList(_prefsTtsKey) ?? [];
        if (!existing.contains(markTts)) {
          await prefs.setStringList(_prefsTtsKey, [...existing, markTts]);
        }
      }
      await refresh();
      state = state.copyWith(
        status: OfflineVoiceStatus.ready,
        progress: 1,
        message: '${bundle.label} installed.',
      );
    } catch (e) {
      state = state.copyWith(
        status: OfflineVoiceStatus.error,
        message: 'Download failed: $e',
      );
    }
  }

  Future<OfflineAsrPaths?> resolveAsrPaths() async {
    if (!state.asrReady) return null;
    final root = await _root();
    final asrDir = p.join(root, state.installedAsrId);
    return OfflineAsrPaths(
      modelPath: await OfflineVoiceDownloader.findFile(asrDir, '.onnx') ?? '',
      tokensPath:
          await OfflineVoiceDownloader.findFile(asrDir, 'tokens.txt') ?? '',
      vadPath: p.join(root, 'vad', 'silero_vad.onnx'),
      senseVoice: state.installedAsrId.contains('sense'),
    );
  }

  Future<OfflineTtsPaths?> resolveTtsPaths(String locale) async {
    final bundleId = ttsBundleIdForLocale(locale);
    if (!state.installedTtsIds.contains(bundleId)) {
      if (state.installedTtsIds.contains(kTtsPiperEnInBundle.id)) {
        return _ttsPathsFor(kTtsPiperEnInBundle.id);
      }
      return null;
    }
    return _ttsPathsFor(bundleId);
  }

  Future<OfflineTtsPaths?> _ttsPathsFor(String bundleId) async {
    final root = await _root();
    final dir = p.join(root, bundleId);
    final model = await OfflineVoiceDownloader.findFile(dir, '.onnx');
    final tokens = await OfflineVoiceDownloader.findFile(dir, 'tokens.txt');
    final espeak =
        await OfflineVoiceDownloader.findDirectoryNamed(dir, 'espeak-ng-data');
    if (model == null || tokens == null || espeak == null) return null;
    return OfflineTtsPaths(
      modelPath: model,
      tokensPath: tokens,
      dataDir: espeak,
    );
  }

  Future<void> uninstallAll() async {
    final root = await _root();
    final dir = Directory(root);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAsrKey);
    await prefs.remove(_prefsTtsKey);
    state = const OfflineVoiceModelState(status: OfflineVoiceStatus.notInstalled);
  }
}

class OfflineAsrPaths {
  const OfflineAsrPaths({
    required this.modelPath,
    required this.tokensPath,
    required this.vadPath,
    required this.senseVoice,
  });

  final String modelPath;
  final String tokensPath;
  final String vadPath;
  final bool senseVoice;

  bool get isValid =>
      modelPath.isNotEmpty && tokensPath.isNotEmpty && vadPath.isNotEmpty;
}

class OfflineTtsPaths {
  const OfflineTtsPaths({
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
  });

  final String modelPath;
  final String tokensPath;
  final String dataDir;
}
