import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/native_wake_service.dart';

final nativeWakeServiceProvider = Provider<NativeWakeService>((ref) {
  return NativeWakeService();
});

final nativeWakeServiceControllerProvider =
    NotifierProvider<NativeWakeServiceController, NativeWakeServiceState>(
      NativeWakeServiceController.new,
    );

class NativeWakeServiceController extends Notifier<NativeWakeServiceState> {
  StreamSubscription<NativeWakeEvent>? _subscription;

  @override
  NativeWakeServiceState build() {
    ref.onDispose(() => _subscription?.cancel());
    Future.microtask(_probeSupport);
    return const NativeWakeServiceState();
  }

  Future<void> start() async {
    final service = ref.read(nativeWakeServiceProvider);
    if (!service.isSupportedPlatform) {
      state = state.copyWith(
        supported: false,
        error: 'Native wake service is only available on Android.',
      );
      return;
    }

    try {
      final speechAvailable = await service.isSpeechRecognitionAvailable();
      if (!speechAvailable) {
        state = state.copyWith(
          supported: false,
          running: false,
          error: 'Android speech recognition is unavailable on this device.',
        );
        return;
      }

      await _subscription?.cancel();
      _subscription = service.wakeEvents.listen(_onWakeEvent);
      await service.start();
      final onDevice = await service.isOnDeviceWakeAvailable();
      state = state.copyWith(
        supported: true,
        running: true,
        speechRecognitionAvailable: true,
        onDeviceWakeAvailable: onDevice,
        error: '',
      );
    } on PlatformException catch (error) {
      state = state.copyWith(
        running: false,
        error: error.message ?? error.code,
      );
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
    }
  }

  Future<void> stop() async {
    final service = ref.read(nativeWakeServiceProvider);
    try {
      await service.stop();
    } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(running: false, error: '');
  }

  Future<void> toggle() async {
    if (state.running) {
      await stop();
    } else {
      await start();
    }
  }

  Future<void> _probeSupport() async {
    final service = ref.read(nativeWakeServiceProvider);
    if (!service.isSupportedPlatform) {
      state = state.copyWith(supported: false);
      return;
    }

    try {
      final speechAvailable = await service.isSpeechRecognitionAvailable();
      final onDevice = await service.isOnDeviceWakeAvailable();
      state = state.copyWith(
        supported: speechAvailable,
        speechRecognitionAvailable: speechAvailable,
        onDeviceWakeAvailable: onDevice,
        error: '',
      );
    } catch (error) {
      state = state.copyWith(supported: false, error: error.toString());
    }
  }

  void _onWakeEvent(NativeWakeEvent event) {
    state = state.copyWith(
      running: true,
      lastEvent: event,
      wakeCount: state.wakeCount + 1,
      error: '',
    );
  }
}

class NativeWakeServiceState {
  const NativeWakeServiceState({
    this.supported = false,
    this.speechRecognitionAvailable = false,
    this.onDeviceWakeAvailable = false,
    this.running = false,
    this.lastEvent,
    this.wakeCount = 0,
    this.error = '',
  });

  final bool supported;
  final bool speechRecognitionAvailable;
  final bool onDeviceWakeAvailable;
  final bool running;
  final NativeWakeEvent? lastEvent;
  final int wakeCount;
  final String error;

  NativeWakeServiceState copyWith({
    bool? supported,
    bool? speechRecognitionAvailable,
    bool? onDeviceWakeAvailable,
    bool? running,
    NativeWakeEvent? lastEvent,
    int? wakeCount,
    String? error,
  }) {
    return NativeWakeServiceState(
      supported: supported ?? this.supported,
      speechRecognitionAvailable:
          speechRecognitionAvailable ?? this.speechRecognitionAvailable,
      onDeviceWakeAvailable:
          onDeviceWakeAvailable ?? this.onDeviceWakeAvailable,
      running: running ?? this.running,
      lastEvent: lastEvent ?? this.lastEvent,
      wakeCount: wakeCount ?? this.wakeCount,
      error: error ?? this.error,
    );
  }
}
