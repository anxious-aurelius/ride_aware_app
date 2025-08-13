import 'package:flutter/material.dart';
import 'user_preferences.dart';

class RideHistoryEntry {
  final String thresholdId;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String status;
  final Map<String, dynamic> summary;
  final String? feedback;
  final List<Map<String, dynamic>> weatherHistory;

  RideHistoryEntry({
    required this.thresholdId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.summary,
    this.feedback,
    this.weatherHistory = const [],
  });

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    final cw = CommuteWindows.defaultValues();
    return RideHistoryEntry(
      thresholdId: json['threshold_id'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
      startTime: cw.utcToLocalTimeOfDay(json['start_time'] as String),
      endTime: cw.utcToLocalTimeOfDay(json['end_time'] as String),
      status: json['status'] as String,
      summary: Map<String, dynamic>.from(json['summary'] as Map),
      feedback: json['feedback'] as String?,
      weatherHistory: (json['weather_history'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'threshold_id': thresholdId,
        'date': date.toUtc().toIso8601String().split('T').first,
        'start_time': CommuteWindows.localTimeOfDayToUtc(startTime),
        'end_time': CommuteWindows.localTimeOfDayToUtc(endTime),
        'status': status,
        'summary': summary,
        if (feedback != null) 'feedback': feedback,
        if (weatherHistory.isNotEmpty) 'weather_history': weatherHistory,
      };

  // No additional helpers needed; conversions handled by [CommuteWindows].
}
