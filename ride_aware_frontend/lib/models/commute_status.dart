import 'package:flutter/material.dart';

enum CommuteStatusLevel { safe, caution, unsafe }

class CommuteStatusResponse {
  final String deviceId;
  final CommuteStatusData morning;
  final CommuteStatusData evening;

  const CommuteStatusResponse({
    required this.deviceId,
    required this.morning,
    required this.evening,
  });

  factory CommuteStatusResponse.fromJson(Map<String, dynamic> json) {
    final statuses = json['statuses'] as Map<String, dynamic>;

    return CommuteStatusResponse(
      deviceId: json['device_id'] as String,
      morning: CommuteStatusData.fromJson(
        statuses['morning'] as Map<String, dynamic>,
      ),
      evening: CommuteStatusData.fromJson(
        statuses['evening'] as Map<String, dynamic>,
      ),
    );
  }
}

class CommuteStatusData {
  final CommuteStatusLevel status;
  final ForecastData forecast;
  final List<String> violations;
  final ThresholdData thresholds;
  final DateTime forecastTime;
  final String? recommendation;

  const CommuteStatusData({
    required this.status,
    required this.forecast,
    required this.violations,
    required this.thresholds,
    required this.forecastTime,
    this.recommendation,
  });

  factory CommuteStatusData.fromJson(Map<String, dynamic> json) {
    return CommuteStatusData(
      status: _parseStatus(json['status'] as String),
      forecast: ForecastData.fromJson(json['forecast'] as Map<String, dynamic>),
      violations: (json['violations'] as List<dynamic>).cast<String>(),
      thresholds: ThresholdData.fromJson(
        json['thresholds'] as Map<String, dynamic>,
      ),
      forecastTime: DateTime.parse(json['forecast_time'] as String),
      recommendation: json['recommendation'] as String?,
    );
  }

  static CommuteStatusLevel _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return CommuteStatusLevel.safe;
      case 'caution':
        return CommuteStatusLevel.caution;
      case 'unsafe':
        return CommuteStatusLevel.unsafe;
      default:
        return CommuteStatusLevel.caution;
    }
  }

  Color get statusColor {
    switch (status) {
      case CommuteStatusLevel.safe:
        return Colors.green;
      case CommuteStatusLevel.caution:
        return Colors.amber;
      case CommuteStatusLevel.unsafe:
        return Colors.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case CommuteStatusLevel.safe:
        return Icons.check_circle;
      case CommuteStatusLevel.caution:
        return Icons.warning;
      case CommuteStatusLevel.unsafe:
        return Icons.cancel;
    }
  }

  String get statusText {
    switch (status) {
      case CommuteStatusLevel.safe:
        return 'Safe';
      case CommuteStatusLevel.caution:
        return 'Caution';
      case CommuteStatusLevel.unsafe:
        return 'Unsafe';
    }
  }

  String get statusEmoji {
    switch (status) {
      case CommuteStatusLevel.safe:
        return '✅';
      case CommuteStatusLevel.caution:
        return '🟡';
      case CommuteStatusLevel.unsafe:
        return '❌';
    }
  }
}

class ForecastData {
  final double temperature;
  final double windSpeed;
  final double rain;
  final double humidity; // Added humidity
  final String confidence;

  const ForecastData({
    required this.temperature,
    required this.windSpeed,
    required this.rain,
    required this.humidity, // Added humidity
    required this.confidence,
  });

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    return ForecastData(
      temperature: (json['temperature'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      rain: (json['rain'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(), // Parse humidity
      confidence: json['confidence'] as String,
    );
  }
}

class ThresholdData {
  final double windSpeed;
  final double rain;
  final double temperatureMin;
  final double temperatureMax;

  const ThresholdData({
    required this.windSpeed,
    required this.rain,
    required this.temperatureMin,
    required this.temperatureMax,
  });

  factory ThresholdData.fromJson(Map<String, dynamic> json) {
    return ThresholdData(
      windSpeed: (json['wind_speed'] as num).toDouble(),
      rain: (json['rain'] as num).toDouble(),
      temperatureMin: (json['temperature_min'] as num)
          .toDouble(), // Parse temperature_min
      temperatureMax: (json['temperature_max'] as num)
          .toDouble(), // Parse temperature_max
    );
  }
}
