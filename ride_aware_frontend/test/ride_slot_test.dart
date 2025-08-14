import 'package:test/test.dart';
import 'package:active_commuter_support/models/ride_slot.dart';

void main() {
  group('shouldShowFeedback', () {
    final current = RideSlot(
      start: DateTime(2024, 1, 1, 8),
      end: DateTime(2024, 1, 1, 9),
      rideId: 'ride1',
    );
    final next = RideSlot(
      start: DateTime(2024, 1, 1, 17),
      end: DateTime(2024, 1, 1, 18),
      rideId: 'ride2',
    );

    test('before current ride ends', () {
      final now = DateTime(2024, 1, 1, 8, 30);
      final show = shouldShowFeedback(
        current: current,
        next: next,
        feedbackAlreadySubmitted: false,
        nowLocal: now,
      );
      expect(show, isFalse);
    });

    test('immediately after ride end', () {
      final now = DateTime(2024, 1, 1, 9);
      final show = shouldShowFeedback(
        current: current,
        next: next,
        feedbackAlreadySubmitted: false,
        nowLocal: now,
      );
      expect(show, isTrue);
    });

    test('just before next ride window closes', () {
      final now = DateTime(2024, 1, 1, 16, 58, 59);
      final show = shouldShowFeedback(
        current: current,
        next: next,
        feedbackAlreadySubmitted: false,
        nowLocal: now,
      );
      expect(show, isTrue);
    });

    test('at hide time it disappears', () {
      final now = DateTime(2024, 1, 1, 16, 59);
      final show = shouldShowFeedback(
        current: current,
        next: next,
        feedbackAlreadySubmitted: false,
        nowLocal: now,
      );
      expect(show, isFalse);
    });

    test('feedback already submitted hides card', () {
      final now = DateTime(2024, 1, 1, 9, 1);
      final show = shouldShowFeedback(
        current: current,
        next: next,
        feedbackAlreadySubmitted: true,
        nowLocal: now,
      );
      expect(show, isFalse);
    });
  });
}
