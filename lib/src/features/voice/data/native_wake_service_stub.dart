import 'dart:async';

class NativeWakeEvent {
  const NativeWakeEvent({
    required this.phrase,
    required this.detectedAt,
    required this.source,
    required this.onDevice,
  });

  factory NativeWakeEvent.fromMap(Object? raw) {
    return NativeWakeEvent(
      phrase: '',
      detectedAt: DateTime.fromMillisecondsSinceEpoch(0),
      source: 'unsupported',
      onDevice: false,
    );
  }

  final String phrase;
  final DateTime detectedAt;
  final String source;
  final bool onDevice;
}

class NativeWakeService {
  bool get isSupportedPlatform => false;

  Stream<NativeWakeEvent> get wakeEvents => const Stream.empty();

  Future<bool> isSpeechRecognitionAvailable() async => false;

  Future<bool> isOnDeviceWakeAvailable() async => false;

  Future<void> start() async {}

  Future<void> stop() async {}
}
