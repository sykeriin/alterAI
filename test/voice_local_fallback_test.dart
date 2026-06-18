import 'package:alter/src/features/voice/application/voice_local_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline greeting does not mention back online', () {
    final result = VoiceLocalFallback.respond(
      transcript: 'hello',
      memoryBlock: '',
      identityBlock: '',
      profile: null,
      offline: true,
    );
    expect(result, isNotNull);
    expect(result!.spokenResponse.toLowerCase(), isNot(contains('back online')));
  });

  test('memory recall surfaces matching line offline', () {
    final result = VoiceLocalFallback.respond(
      transcript: 'what is my internship plan?',
      memoryBlock:
          '- [goal] Voice interaction: User asked about startup internship at Acme (confidence=0.80)',
      identityBlock: '',
      profile: null,
      offline: true,
    );
    expect(result, isNotNull);
    expect(result!.spokenResponse.toLowerCase(), contains('internship'));
  });

  test('memory_capture acknowledges snippet', () {
    final result = VoiceLocalFallback.respond(
      transcript: 'remember I prefer morning meetings',
      memoryBlock:
          '- [preference] Schedule: prefers morning meetings (confidence=0.70)',
      identityBlock: '',
      profile: null,
      offline: true,
    );
    expect(result, isNotNull);
    expect(result!.inferredIntent, 'memory_capture');
    expect(result.spokenResponse.toLowerCase(), contains('remember'));
  });
}
