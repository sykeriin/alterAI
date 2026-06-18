import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../core/performance/on_device_resource_governor.dart';
import 'offline_voice_model_manager.dart';

class OfflineTtsService {
  OfflineTtsService();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  OfflineTtsPaths? _paths;

  bool get isInitialized => _tts != null;

  Future<void> init(OfflineTtsPaths paths) async {
    sherpa.initBindings();
    await disposeEngine();
    _paths = paths;
    final vits = sherpa.OfflineTtsVitsModelConfig(
      model: paths.modelPath,
      tokens: paths.tokensPath,
      dataDir: paths.dataDir,
    );
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(vits: vits, numThreads: 1),
      maxNumSenetences: 1,
    );
    _tts = sherpa.OfflineTts(config);
  }

  Future<void> speak(String text, {double speed = 1.0}) async {
    if (_tts == null) throw StateError('OfflineTtsService not initialized');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final audio = _tts!.generateWithConfig(
      text: trimmed.length > 800 ? trimmed.substring(0, 800) : trimmed,
      config: sherpa.OfflineTtsGenerationConfig(speed: speed),
      onProgress: (_, __) => 1,
    );

    final bytes = _waveBytes(audio.samples, audio.sampleRate);
    await _player.stop();
    await _player.setAudioSource(_MemoryAudioSource(bytes));
    await _player.play();
    await _player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed);
  }

  Uint8List _waveBytes(Float32List samples, int sampleRate) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).clamp(-32768, 32767).round();
      pcm[i] = v;
    }
    final dataSize = pcm.lengthInBytes;
    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint32(12, 16, Endian.little);
    header.setUint16(16, 1, Endian.little);
    header.setUint16(18, 1, Endian.little);
    header.setUint32(20, sampleRate, Endian.little);
    header.setUint32(24, sampleRate * 2, Endian.little);
    header.setUint16(28, 2, Endian.little);
    header.setUint16(30, 16, Endian.little);
    header.setUint8(32, 0x64);
    header.setUint8(33, 0x61);
    header.setUint8(34, 0x74);
    header.setUint8(35, 0x61);
    header.setUint32(40, dataSize, Endian.little);
    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(pcm.buffer.asUint8List());
    return out.toBytes();
  }

  Future<void> disposeEngine() async {
    _tts?.free();
    _tts = null;
  }

  Future<void> dispose() async {
    await disposeEngine();
    await _player.dispose();
  }
}

class _MemoryAudioSource extends StreamAudioSource {
  _MemoryAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

final offlineTtsServiceProvider = Provider<OfflineTtsService>((ref) {
  final service = OfflineTtsService();
  ref.read(onDeviceResourceGovernorProvider.notifier).registerDisposer(
        OnDeviceResource.tts,
        service.disposeEngine,
      );
  ref.onDispose(service.dispose);
  return service;
});
