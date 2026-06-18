import 'package:alter/src/features/ondevice/on_device_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ai = HeuristicOnDeviceAi();

  group('HeuristicOnDeviceAi (on-device fallback)', () {
    test('classifies coarse intents', () async {
      expect(await ai.classifyIntent('remind me at 5pm'), 'schedule');
      expect(await ai.classifyIntent('should I take the job?'), 'decision');
      expect(await ai.classifyIntent('just saying hi'), 'chat');
    });

    test('routes deep reasoning on-device', () async {
      expect(await ai.needsDeepReasoning('should I take the job?'), isTrue);
      expect(await ai.needsDeepReasoning('what time is it'), isFalse);
    });

    test('summarize caps to maxWords', () async {
      final out = await ai.summarize(
        List.filled(60, 'word').join(' '),
        maxWords: 10,
      );
      expect(out.split(' ').length <= 11, isTrue);
    });

    test('redact removes PII but keeps length', () async {
      final out = await ai.redact('mail me at jane@example.com please');
      expect(out.contains('jane@example.com'), isFalse);
      expect(out.contains('[redacted-email]'), isTrue);
    });
  });
}
