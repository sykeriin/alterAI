import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeWakeEvent {
  const NativeWakeEvent({
    required this.phrase,
    required this.detectedAt,
    required this.source,
    required this.onDevice,
  });

  factory NativeWakeEvent.fromMap(Object? raw) {
    final map = Map<Object?, Object?>.from(raw as Map<Object?, Object?>);
    final millis = map['detectedAtMillis'];
    return NativeWakeEvent(
      phrase: (map['phrase'] as String? ?? '').trim(),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        millis is int ? millis : int.tryParse('$millis') ?? 0,
      ),
      source: map['source'] as String? ?? 'android_speech_recognizer',
      onDevice: map['onDevice'] as bool? ?? false,
    );
  }

  final String phrase;
  final DateTime detectedAt;
  final String source;
  final bool onDevice;
}

class NativeWakeService {
  static const _methodChannel = MethodChannel('alter.ai/wake_service');
  static const _eventChannel = EventChannel('alter.ai/wake_events');

  Stream<NativeWakeEvent>? _events;

  bool get isSupportedPlatform => Platform.isAndroid;

  Stream<NativeWakeEvent> get wakeEvents {
    if (!isSupportedPlatform) return const Stream.empty();
    return _events ??= _eventChannel.receiveBroadcastStream().map(
      NativeWakeEvent.fromMap,
    );
  }

  Future<bool> isSpeechRecognitionAvailable() async {
    if (!isSupportedPlatform) return false;
    return await _methodChannel.invokeMethod<bool>(
          'isSpeechRecognitionAvailable',
        ) ??
        false;
  }

  Future<bool> isOnDeviceWakeAvailable() async {
    if (!isSupportedPlatform) return false;
    return await _methodChannel.invokeMethod<bool>('isOnDeviceWakeAvailable') ??
        false;
  }

  Future<void> start() async {
    if (!isSupportedPlatform) return;
    await _methodChannel.invokeMethod<bool>('startWakeService');
  }

  Future<void> stop() async {
    if (!isSupportedPlatform) return;
    await _methodChannel.invokeMethod<bool>('stopWakeService');
  }
}
