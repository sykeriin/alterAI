import 'package:alter/src/features/feedback/domain/feedback_event.dart';
import 'package:alter/src/features/privacy/data/context_privacy_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackEvent', () {
    test('round-trips JSON and exposes a reward signal', () {
      final event = FeedbackEvent(
        id: '1',
        decision: 'take the internship',
        kind: DecisionFeedbackKind.regretted,
        outcome: OutcomeValence.negative,
        rating: 2,
        note: 'too far from home',
        at: DateTime.parse('2026-01-01T10:00:00Z'),
        context: {
          'options': ['A', 'B'],
        },
      );

      final back = FeedbackEvent.fromJson(event.toJson());
      expect(back.decision, 'take the internship');
      expect(back.kind, DecisionFeedbackKind.regretted);
      expect(back.outcome, OutcomeValence.negative);
      expect(back.rating, 2);
      expect(back.rewardSignal, -1.0);
    });

    test('completed-positive and regretted give opposite reward signals', () {
      final good = FeedbackEvent(
        id: 'a',
        decision: 'x',
        kind: DecisionFeedbackKind.completed,
        outcome: OutcomeValence.positive,
        at: DateTime.now(),
      );
      final bad = FeedbackEvent(
        id: 'b',
        decision: 'x',
        kind: DecisionFeedbackKind.regretted,
        at: DateTime.now(),
      );
      expect(good.rewardSignal > 0, isTrue);
      expect(bad.rewardSignal < 0, isTrue);
    });
  });

  group('ContextPrivacyFilter', () {
    test('redacts PII before cloud', () {
      const filter = ContextPrivacyFilter();
      final out =
          filter.filter('email me at jane@work.com or +1 415 555 1234 today');
      expect(out.contains('jane@work.com'), isFalse);
      expect(out.contains('555'), isFalse);
      expect(out.contains('[redacted-email]'), isTrue);
    });

    test('caps to the context budget', () {
      const filter = ContextPrivacyFilter(maxChars: 10);
      final out = filter.filter('a' * 50);
      expect(out.length <= 11, isTrue); // maxChars + ellipsis
    });
  });
}
