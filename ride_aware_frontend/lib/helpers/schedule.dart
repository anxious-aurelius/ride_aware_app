import 'package:flutter/material.dart';

/// Choose the next scheduled start date based on the provided start time.
DateTime pickScheduledStart(DateTime now, TimeOfDay startLocal) {
  final todayStart = DateTime(
    now.year,
    now.month,
    now.day,
    startLocal.hour,
    startLocal.minute,
  );
  return now.isBefore(todayStart) ? todayStart : todayStart.add(const Duration(days: 1));
}

/// Format a [DateTime] as `YYYY-MM-DD`.
String yyyymmdd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

extension TimeOfDayX on TimeOfDay {
  /// Format the time as `HH:mm`.
  String format24h() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

