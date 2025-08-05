import 'package:flutter_test/flutter_test.dart';
import 'package:ride_aware_frontend/services/notification_service.dart';

void main() {
  final service = NotificationService();

  test('rolls past times forward one day', () {
    final now = DateTime.now();
    final past = now.subtract(const Duration(hours: 1));
    final adjusted = service.rollForwardIfPast(past);
    expect(adjusted.isAfter(now), isTrue);
    expect(adjusted.difference(past).inDays, 1);
  });

  test('keeps future times unchanged', () {
    final now = DateTime.now();
    final future = now.add(const Duration(hours: 1));
    final adjusted = service.rollForwardIfPast(future);
    expect(adjusted, future);
  });
}
