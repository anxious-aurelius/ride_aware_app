import 'package:flutter/material.dart';

class RideHistoryEntry {
  final String thresholdId;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String status;
  final Map<String, dynamic> summary;
  final String? feedback;

  RideHistoryEntry({
    required this.thresholdId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.summary,
    this.feedback,
  });

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RideHistoryEntry(
      thresholdId: json['threshold_id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: _parseTime(json['start_time'] as String),
      endTime: _parseTime(json['end_time'] as String),
      status: json['status'] as String,
      summary: Map<String, dynamic>.from(json['summary'] as Map),
      feedback: json['feedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'threshold_id': thresholdId,
        'date': date.toIso8601String().split('T').first,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'status': status,
        'summary': summary,
        if (feedback != null) 'feedback': feedback,
      };

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
