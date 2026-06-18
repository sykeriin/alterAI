import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks memory lifecycle primitive status for UI (Encoding → Updating).
enum MemoryLifecycleStage {
  encoding,
  stabilizing,
  storing,
  retrieving,
  updating,
  idle,
}

class MemoryLifecycleState {
  const MemoryLifecycleState({
    this.stage = MemoryLifecycleStage.idle,
    this.message = '',
  });

  final MemoryLifecycleStage stage;
  final String message;

  MemoryLifecycleState copyWith({
    MemoryLifecycleStage? stage,
    String? message,
  }) =>
      MemoryLifecycleState(
        stage: stage ?? this.stage,
        message: message ?? this.message,
      );
}

final memoryLifecycleProvider =
    NotifierProvider<MemoryLifecycleNotifier, MemoryLifecycleState>(
  MemoryLifecycleNotifier.new,
);

class MemoryLifecycleNotifier extends Notifier<MemoryLifecycleState> {
  @override
  MemoryLifecycleState build() => const MemoryLifecycleState();

  void setStage(MemoryLifecycleStage stage, {String message = ''}) {
    state = MemoryLifecycleState(stage: stage, message: message);
  }

  void idle() => state = const MemoryLifecycleState();
}
