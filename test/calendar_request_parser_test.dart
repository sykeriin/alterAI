import 'package:alter/src/features/actions/calendar_request_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarRequestParser', () {
    test('parses birthday on 6th oct 2026', () {
      final r = CalendarRequestParser.tryParse(
        'make an event for my birthday on 6th oct 2026',
      );
      expect(r, isNotNull);
      expect(r!.title, 'My Birthday');
      expect(r.startIso, startsWith('2026-10-06'));
    });

    test('parses october spelling and without ordinal', () {
      final r = CalendarRequestParser.tryParse(
        'create a calendar event for my birthday on 6 october 2026',
      );
      expect(r, isNotNull);
      expect(r!.title, 'My Birthday');
      expect(r.startIso, startsWith('2026-10-06'));
    });

    test('parses month-first date', () {
      final r = CalendarRequestParser.tryParse(
        'schedule appointment dentist on October 6 2026',
      );
      expect(r, isNotNull);
      expect(r!.startIso, startsWith('2026-10-06'));
    });

    test('ignores unrelated requests', () {
      expect(
        CalendarRequestParser.tryParse('call my dad'),
        isNull,
      );
    });
    test('handles common speech-to-text typos', () {
      final r = CalendarRequestParser.tryParse(
        'make an event for mt birtheday on 6th oct 2026',
      );
      expect(r, isNotNull);
      expect(r!.title, 'My Birthday');
    });
  });
}
