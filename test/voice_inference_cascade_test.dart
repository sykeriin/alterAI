import 'package:alter/src/features/voice/application/voice_local_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('heuristic tier always returns spoken response offline', () {
    final result = VoiceLocalFallback.respond(
      transcript: 'hey alter how are you',
      memoryBlock: '',
      identityBlock: '',
      profile: null,
      offline: true,
    );
    expect(result, isNotNull);
    expect(result!.spokenResponse.isNotEmpty, isTrue);
    expect(
      result.signals.any((s) => s.summary == 'heuristic'),
      isTrue,
    );
  });

  test('offlineOnly path uses heuristic without online wording', () {
    final result = VoiceLocalFallback.respond(
      transcript: 'tell me about my goals',
      memoryBlock: '- [goal] Goals: finish thesis by June (confidence=0.90)',
      identityBlock: '',
      profile: null,
      offline: true,
    );
    expect(result!.spokenResponse.toLowerCase(), isNot(contains('back online')));
  });
}
