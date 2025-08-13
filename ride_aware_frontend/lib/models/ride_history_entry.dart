class RideHistoryEntry {
  final String rideId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final Map<String, dynamic> summary;
  final Map<String, dynamic>? threshold;
  final String? feedback;
  final List<WeatherPoint> weather;

  RideHistoryEntry({
    required this.rideId,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.summary,
    this.threshold,
    this.feedback,
    required this.weather,
  });

  DateTime get localDate => startUtc.toLocal();

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RideHistoryEntry(
      rideId: json['ride_id'] as String,
      startUtc: DateTime.parse(json['start_utc'] as String),
      endUtc: DateTime.parse(json['end_utc'] as String),
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
        'start_utc': startUtc.toUtc().toIso8601String(),
        'end_utc': endUtc.toUtc().toIso8601String(),
        'status': status,
        'summary': summary,
        if (threshold != null) 'threshold': threshold,
        if (feedback != null) 'feedback': feedback,
        if (weather.isNotEmpty)
          'weather_history': weather.map((w) => w.toJson()).toList(),
      };
}

class WeatherPoint {
  final DateTime tsUtc;
  final num? tempC;
  final num? windMs;
  final String? cond;
  WeatherPoint({required this.tsUtc, this.tempC, this.windMs, this.cond});

  factory WeatherPoint.fromJson(Map<String, dynamic> json) => WeatherPoint(
        tsUtc: DateTime.parse(json['ts_utc'] as String),
        tempC: json['temp_c'] as num?,
        windMs: json['wind_ms'] as num?,
        cond: json['cond'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'ts_utc': tsUtc.toUtc().toIso8601String(),
        if (tempC != null) 'temp_c': tempC,
        if (windMs != null) 'wind_ms': windMs,
        if (cond != null) 'cond': cond,
      };
}
