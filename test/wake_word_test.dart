import 'package:alter/src/features/voice/domain/wake_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects Hey Alter and extracts the command', () {
    final match = WakeWord.parse('Hey Alter, remind me to call Mom');

    expect(match.detected, isTrue);
    expect(match.command, 'remind me to call Mom');
    expect(match.runtimeTranscript, 'Hey Alter, remind me to call Mom');
  });

  test('detects alternate wake phrasing', () {
    final match = WakeWord.parse('Ok Alter what should I do today');

    expect(match.detected, isTrue);
    expect(match.command, 'what should I do today');
  });

  test('does not treat ordinary text as a wake command', () {
    final match = WakeWord.parse('I am thinking about ALTER as a startup');

    expect(match.detected, isFalse);
    expect(match.command, contains('startup'));
  });
}
