import 'package:flutter/material.dart';

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
  String format24h() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

