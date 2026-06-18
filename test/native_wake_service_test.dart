import 'package:alter/src/features/voice/data/native_wake_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Android wake event payload', () {
    final event = NativeWakeEvent.fromMap({
      'phrase': 'Hey Alter, start my day',
      'detectedAtMillis': 1710000000000,
      'source': 'android_speech_recognizer',
      'onDevice': true,
    });

    expect(event.phrase, 'Hey Alter, start my day');
    expect(event.detectedAt.millisecondsSinceEpoch, 1710000000000);
    expect(event.source, 'android_speech_recognizer');
    expect(event.onDevice, isTrue);
  });
}
