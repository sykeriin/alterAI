import 'package:alter/src/features/voice/application/voice_turn_orchestrator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VoiceTurnOrchestrator provider is constructible', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(voiceTurnOrchestratorProvider), isNotNull);
  });
}
