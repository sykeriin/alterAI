import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../core/performance/on_device_resource_governor.dart';
import 'offline_voice_model_manager.dart';

Float32List pcm16ToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);
  final data = ByteData.view(bytes.buffer);
  for (var i = 0; i < bytes.length; i += 2) {
    final short = data.getInt16(i, endian);
    values[i ~/ 2] = short / 32768.0;
  }
  return values;
}

/// Mic → VAD → offline recognizer. Requires downloaded sherpa-onnx models.
class OfflineAsrService {
  OfflineAsrService();

  static const sampleRate = 16000;

  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  sherpa.CircularBuffer? _buffer;
  sherpa.VadModelConfig? _vadConfig;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  String _accumulated = '';
  void Function(String partial)? _onPartial;

  bool get isInitialized => _recognizer != null;

  Future<void> init(OfflineAsrPaths paths) async {
    if (!paths.isValid) {
      throw StateError('ASR model paths invalid');
    }
    sherpa.initBindings();
    await disposeEngines();

    final silero = sherpa.SileroVadModelConfig(
      model: paths.vadPath,
      minSilenceDuration: 0.25,
      minSpeechDuration: 0.5,
      maxSpeechDuration: 20.0,
    );
    _vadConfig = sherpa.VadModelConfig(
      sileroVad: silero,
      numThreads: 1,
      debug: false,
    );
    _vad = sherpa.VoiceActivityDetector(
      config: _vadConfig!,
      bufferSizeInSeconds: 30,
    );
    _buffer = sherpa.CircularBuffer(capacity: 30 * sampleRate);

    final modelConfig = paths.senseVoice
        ? sherpa.OfflineModelConfig(
            senseVoice: sherpa.OfflineSenseVoiceModelConfig(
              model: paths.modelPath,
            ),
            tokens: paths.tokensPath,
          )
        : sherpa.OfflineModelConfig(
            nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(
              model: paths.modelPath,
            ),
            tokens: paths.tokensPath,
          );

    _recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(model: modelConfig),
    );
  }

  Future<String> listenOneShot({
    void Function(String partial)? onPartial,
    Duration maxDuration = const Duration(seconds: 18),
  }) async {
    if (_recognizer == null || _vad == null || _buffer == null) {
      throw StateError('OfflineAsrService not initialized');
    }
    _accumulated = '';
    _onPartial = onPartial;

    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

    final completer = Completer<String>();
    final timer = Timer(maxDuration, () => unawaited(_finishListen(completer)));

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _micSub = stream.listen(
      (data) => _handlePcm(data),
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          unawaited(_finishListen(completer));
        }
      },
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  Future<void> stop() async {
    await _recorder.stop();
    await _micSub?.cancel();
    _micSub = null;
  }

  void _handlePcm(Uint8List data) {
    final samples = pcm16ToFloat32(data);
    _buffer!.push(samples);
    final windowSize = _vadConfig!.sileroVad.windowSize;
    while (_buffer!.size > windowSize) {
      final window =
          _buffer!.get(startIndex: _buffer!.head, n: windowSize);
      _buffer!.pop(windowSize);
      _vad!.acceptWaveform(window);
      while (!_vad!.isEmpty()) {
        final segment = _vad!.front();
        final text = _decodeSegment(segment.samples);
        _vad!.pop();
        if (text.isNotEmpty) {
          _accumulated =
              _accumulated.isEmpty ? text : '$_accumulated $text'.trim();
          _onPartial?.call(_accumulated);
        }
      }
    }
  }

  String _decodeSegment(Float32List samples) {
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    _recognizer!.decode(stream);
    final text = _recognizer!.getResult(stream).text.trim();
    stream.free();
    return text;
  }

  Future<void> _finishListen(Completer<String> completer) async {
    await stop();
    _vad?.flush();
    while (_vad != null && !_vad!.isEmpty()) {
      final segment = _vad!.front();
      final text = _decodeSegment(segment.samples);
      _vad!.pop();
      if (text.isNotEmpty) {
        _accumulated =
            _accumulated.isEmpty ? text : '$_accumulated $text'.trim();
      }
    }
    if (!completer.isCompleted) {
      completer.complete(_accumulated.trim());
    }
  }

  Future<void> disposeEngines() async {
    await stop();
    _recognizer?.free();
    _vad?.free();
    _buffer?.free();
    _recognizer = null;
    _vad = null;
    _buffer = null;
    _vadConfig = null;
  }

  Future<void> dispose() async {
    await disposeEngines();
    await _recorder.dispose();
  }
}

final offlineAsrServiceProvider = Provider<OfflineAsrService>((ref) {
  final service = OfflineAsrService();
  ref.read(onDeviceResourceGovernorProvider.notifier).registerDisposer(
        OnDeviceResource.asr,
        service.disposeEngines,
      );
  ref.onDispose(service.dispose);
  return service;
});
