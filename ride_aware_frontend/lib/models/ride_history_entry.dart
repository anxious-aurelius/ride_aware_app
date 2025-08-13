class RideHistoryEntry {
  final String rideId;
  final DateTime start;
  final DateTime end;
  final String status;
  final Map<String, dynamic> summary;
  final Map<String, dynamic>? threshold;
  final String? feedback;
  final List<WeatherPoint> weather;

  RideHistoryEntry({
    required this.rideId,
    required this.start,
    required this.end,
    required this.status,
    required this.summary,
    this.threshold,
    this.feedback,
    required this.weather,
  });

  DateTime get localDate => start;

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String;
    final startStr = json['start_time'] as String;
    final endStr = json['end_time'] as String;
    final start = DateTime.parse('${date}T$startStr');
    final end = DateTime.parse('${date}T$endStr');
    return RideHistoryEntry(
      rideId: json['ride_id'] as String,
      start: start,
      end: end,
      status: json['status'] as String,
      summary: Map<String, dynamic>.from(json['summary'] as Map),
      threshold: json['threshold'] == null
          ? null
          : Map<String, dynamic>.from(json['threshold'] as Map),
      feedback: json['feedback'] as String?,
      weather: (json['weather_history'] as List? ?? [])
          .map((e) => WeatherPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ride_id': rideId,
        'date': start.toIso8601String().split('T').first,
        'start_time': '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
        'end_time': '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        'status': status,
        'summary': summary,
        if (threshold != null) 'threshold': threshold,
        if (feedback != null) 'feedback': feedback,
        if (weather.isNotEmpty)
          'weather_history': weather.map((w) => w.toJson()).toList(),
      };
}

class WeatherPoint {
  final DateTime timestamp;
  final num? tempC;
  final num? windMs;
  final String? cond;
  WeatherPoint({required this.timestamp, this.tempC, this.windMs, this.cond});

  factory WeatherPoint.fromJson(Map<String, dynamic> json) => WeatherPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        tempC: json['temp_c'] as num?,
        windMs: json['wind_ms'] as num?,
        cond: json['cond'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        if (tempC != null) 'temp_c': tempC,
        if (windMs != null) 'wind_ms': windMs,
        if (cond != null) 'cond': cond,
      };
}
