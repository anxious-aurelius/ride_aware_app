import 'package:flutter/material.dart';
import '../utils/parsing.dart';

class UserPreferences {
  final WeatherLimits weatherLimits;
  final EnvironmentalRisk environmentalRisk;
  final OfficeLocation officeLocation;
  final CommuteWindows commuteWindows;
  final int presenceRadiusM;
  final int speedCutoffKmh;
  final String timezone;

  const UserPreferences({
    required this.weatherLimits,
    required this.environmentalRisk,
    required this.officeLocation,
    required this.commuteWindows,
    this.presenceRadiusM = 100,
    this.speedCutoffKmh = 5,
    this.timezone = 'Europe/London',
  });

  // Default preferences for first-time users
  factory UserPreferences.defaultValues() {
    return UserPreferences(
      weatherLimits: WeatherLimits.defaultValues(),
      environmentalRisk: EnvironmentalRisk.defaultValues(),
      officeLocation: OfficeLocation.empty(),
      commuteWindows: CommuteWindows.defaultValues(),
      presenceRadiusM: 100,
      speedCutoffKmh: 5,
      timezone: 'Europe/London',
    );
  }

  // Create from JSON (for API and local storage)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      weatherLimits: WeatherLimits.fromJson(json['weather_limits'] ?? {}),
      environmentalRisk: EnvironmentalRisk.fromJson(
        json['environmental_risk'] ?? {},
      ),
      officeLocation: OfficeLocation.fromJson(json['office_location'] ?? {}),
      commuteWindows: CommuteWindows.fromJson({
        'start': json['start_time'] ?? '07:30',
        'end': json['end_time'] ?? '17:30',
      }),
      presenceRadiusM: json['presence_radius_m'] ?? 100,
      speedCutoffKmh: json['speed_cutoff_kmh'] ?? 5,
      timezone: json['timezone'] ?? 'Europe/London',
    );
  }

  // Convert to JSON (for API and local storage)
  Map<String, dynamic> toJson() {
    return {
      'weather_limits': weatherLimits.toJson(),
      'environmental_risk': environmentalRisk.toJson(),
      'office_location': officeLocation.toJson(),
      'start_time': commuteWindows.start,
      'end_time': commuteWindows.end,
      'presence_radius_m': presenceRadiusM,
      'speed_cutoff_kmh': speedCutoffKmh,
      'timezone': timezone,
    };
  }

  // Create a copy with updated values
  UserPreferences copyWith({
    WeatherLimits? weatherLimits,
    EnvironmentalRisk? environmentalRisk,
    OfficeLocation? officeLocation,
    CommuteWindows? commuteWindows,
    int? presenceRadiusM,
    int? speedCutoffKmh,
    String? timezone,
  }) {
    return UserPreferences(
      weatherLimits: weatherLimits ?? this.weatherLimits,
      environmentalRisk: environmentalRisk ?? this.environmentalRisk,
      officeLocation: officeLocation ?? this.officeLocation,
      commuteWindows: commuteWindows ?? this.commuteWindows,
      presenceRadiusM: presenceRadiusM ?? this.presenceRadiusM,
      speedCutoffKmh: speedCutoffKmh ?? this.speedCutoffKmh,
      timezone: timezone ?? this.timezone,
    );
  }

  // Validation
  bool get isValid {
    return weatherLimits.isValid &&
        environmentalRisk.isValid &&
        officeLocation.isValid &&
        commuteWindows.isValid &&
        presenceRadiusM > 0 &&
        speedCutoffKmh >= 0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        other.weatherLimits == weatherLimits &&
        other.environmentalRisk == environmentalRisk &&
        other.officeLocation == officeLocation &&
        other.commuteWindows == commuteWindows &&
        other.presenceRadiusM == presenceRadiusM &&
        other.speedCutoffKmh == speedCutoffKmh &&
        other.timezone == timezone;
  }

  @override
  int get hashCode {
    return weatherLimits.hashCode ^
        environmentalRisk.hashCode ^
        officeLocation.hashCode ^
        commuteWindows.hashCode ^
        presenceRadiusM.hashCode ^
        speedCutoffKmh.hashCode ^
        timezone.hashCode;
  }

  @override
  String toString() {
    // ignore: lines_longer_than_80_chars
    return 'UserPreferences(weatherLimits: $weatherLimits, environmentalRisk: $environmentalRisk, officeLocation: $officeLocation, commuteWindows: $commuteWindows, presenceRadiusM: $presenceRadiusM, speedCutoffKmh: $speedCutoffKmh, timezone: $timezone)';
  }
}

class WeatherLimits {
  final double maxWindSpeed;
  final double maxRainIntensity;
  final double maxHumidity;
  final double minTemperature;
  final double maxTemperature;
  final double headwindSensitivity;
  final double crosswindSensitivity;

  const WeatherLimits({
    required this.maxWindSpeed,
    required this.maxRainIntensity,
    required this.maxHumidity,
    required this.minTemperature,
    required this.maxTemperature,
    required this.headwindSensitivity,
    required this.crosswindSensitivity,
  });

  factory WeatherLimits.defaultValues() {
    return const WeatherLimits(
      maxWindSpeed: 30.0,
      maxRainIntensity: 0.5,
      maxHumidity: 85.0,
      minTemperature: 5.0, // 5°C minimum - cyclists don't like cold weather
      maxTemperature: 32.0,
      headwindSensitivity: 20.0,
      crosswindSensitivity: 15.0,
    );
  }

  factory WeatherLimits.fromJson(Map<String, dynamic> json) {
    return WeatherLimits(
      maxWindSpeed: parseDouble(json['max_wind_speed'], defaultValue: 30.0),
      maxRainIntensity:
          parseDouble(json['max_rain_intensity'], defaultValue: 0.5),
      maxHumidity: parseDouble(json['max_humidity'], defaultValue: 85.0),
      minTemperature: parseDouble(json['min_temperature'], defaultValue: 5.0),
      maxTemperature:
          parseDouble(json['max_temperature'], defaultValue: 32.0),
      headwindSensitivity:
          parseDouble(json['headwind_sensitivity'], defaultValue: 20.0),
      crosswindSensitivity:
          parseDouble(json['crosswind_sensitivity'], defaultValue: 15.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_wind_speed': maxWindSpeed,
      'max_rain_intensity': maxRainIntensity,
      'max_humidity': maxHumidity,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
      'headwind_sensitivity': headwindSensitivity,
      'crosswind_sensitivity': crosswindSensitivity,
    };
  }

  WeatherLimits copyWith({
    double? maxWindSpeed,
    double? maxRainIntensity,
    double? maxHumidity,
    double? minTemperature,
    double? maxTemperature,
    double? headwindSensitivity,
    double? crosswindSensitivity,
  }) {
    return WeatherLimits(
      maxWindSpeed: maxWindSpeed ?? this.maxWindSpeed,
      maxRainIntensity: maxRainIntensity ?? this.maxRainIntensity,
      maxHumidity: maxHumidity ?? this.maxHumidity,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      headwindSensitivity:
          headwindSensitivity ?? this.headwindSensitivity,
      crosswindSensitivity:
          crosswindSensitivity ?? this.crosswindSensitivity,
    );
  }

  bool get isValid {
    return maxWindSpeed >= 0 &&
        maxWindSpeed <= 200 &&
        maxRainIntensity >= 0 &&
        maxRainIntensity <= 50 &&
        maxHumidity >= 0 &&
        maxHumidity <= 100 &&
        minTemperature >= -50 &&
        minTemperature <= 60 &&
        maxTemperature >= -50 &&
        maxTemperature <= 60 &&
        headwindSensitivity >= 0 &&
        headwindSensitivity <= 50 &&
        crosswindSensitivity >= 0 &&
        crosswindSensitivity <= 50 &&
        minTemperature <=
            maxTemperature; // Min temp must be less than or equal to max temp
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherLimits &&
        other.maxWindSpeed == maxWindSpeed &&
        other.maxRainIntensity == maxRainIntensity &&
        other.maxHumidity == maxHumidity &&
        other.minTemperature == minTemperature &&
        other.maxTemperature == maxTemperature &&
        other.headwindSensitivity == headwindSensitivity &&
        other.crosswindSensitivity == crosswindSensitivity;
  }

  @override
  int get hashCode {
    return maxWindSpeed.hashCode ^
        maxRainIntensity.hashCode ^
        maxHumidity.hashCode ^
        minTemperature.hashCode ^
        maxTemperature.hashCode ^
        headwindSensitivity.hashCode ^
        crosswindSensitivity.hashCode;
  }

  @override
  String toString() {
    return 'WeatherLimits(maxWindSpeed: $maxWindSpeed, maxRainIntensity: $maxRainIntensity, maxHumidity: $maxHumidity, minTemperature: $minTemperature, maxTemperature: $maxTemperature, headwindSensitivity: $headwindSensitivity, crosswindSensitivity: $crosswindSensitivity)';
  }
}

class EnvironmentalRisk {
  final double minVisibility;
  final double maxPollution;
  final double maxUvIndex;

  const EnvironmentalRisk({
    required this.minVisibility,
    required this.maxPollution,
    required this.maxUvIndex,
  });

  factory EnvironmentalRisk.defaultValues() {
    return const EnvironmentalRisk(
      minVisibility: 1000.0,
      maxPollution: 80.0,
      maxUvIndex: 5.0,
    );
  }

  factory EnvironmentalRisk.fromJson(Map<String, dynamic> json) {
    return EnvironmentalRisk(
      minVisibility:
          parseDouble(json['min_visibility'], defaultValue: 1000.0),
      maxPollution:
          parseDouble(json['max_pollution'], defaultValue: 80.0),
      maxUvIndex: parseDouble(json['max_uv_index'], defaultValue: 5.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_visibility': minVisibility,
      'max_pollution': maxPollution,
      'max_uv_index': maxUvIndex,
    };
  }

  EnvironmentalRisk copyWith({
    double? minVisibility,
    double? maxPollution,
    double? maxUvIndex,
  }) {
    return EnvironmentalRisk(
      minVisibility: minVisibility ?? this.minVisibility,
      maxPollution: maxPollution ?? this.maxPollution,
      maxUvIndex: maxUvIndex ?? this.maxUvIndex,
    );
  }

  bool get isValid {
    return minVisibility >= 0 &&
        minVisibility <= 10000 &&
        maxPollution >= 0 &&
        maxPollution <= 500 &&
        maxUvIndex >= 0 &&
        maxUvIndex <= 15;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnvironmentalRisk &&
        other.minVisibility == minVisibility &&
        other.maxPollution == maxPollution &&
        other.maxUvIndex == maxUvIndex;
  }

  @override
  int get hashCode {
    return minVisibility.hashCode ^ maxPollution.hashCode ^ maxUvIndex.hashCode;
  }

  @override
  String toString() {
    return 'EnvironmentalRisk(minVisibility: $minVisibility, maxPollution: $maxPollution, maxUvIndex: $maxUvIndex)';
  }
}

class OfficeLocation {
  final double latitude;
  final double longitude;

  const OfficeLocation({required this.latitude, required this.longitude});

  factory OfficeLocation.empty() {
    return const OfficeLocation(latitude: 0.0, longitude: 0.0);
  }

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  OfficeLocation copyWith({double? latitude, double? longitude}) {
    return OfficeLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  bool get isValid {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0.0 && longitude == 0.0); // Not empty
  }

  bool get isEmpty {
    return latitude == 0.0 && longitude == 0.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfficeLocation &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^ longitude.hashCode;
  }

  @override
  String toString() {
    return 'OfficeLocation(latitude: $latitude, longitude: $longitude)';
  }
}

class CommuteWindows {
  /// Stored in local time (HH:mm)
  final String start;

  /// Stored in local time (HH:mm)
  final String end;

  const CommuteWindows._({required this.start, required this.end});

  factory CommuteWindows({required String start, required String end}) {
    return CommuteWindows._(
      start: _formatTime(start),
      end: _formatTime(end),
    );
  }

  factory CommuteWindows.defaultValues() {
    // Default times in local time
    return CommuteWindows(start: '07:30', end: '17:30');
  }

  factory CommuteWindows.fromJson(Map<String, dynamic> json) {
    return CommuteWindows(
      start: json['start'] ?? '07:30',
      end: json['end'] ?? '17:30',
    );
  }

  Map<String, dynamic> toJson() {
    return {'start': start, 'end': end};
  }

  CommuteWindows copyWith({String? start, String? end}) {
    return CommuteWindows(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get isValid {
    return _isValidTimeFormat(start) && _isValidTimeFormat(end);
  }

  bool _isValidTimeFormat(String time) {
    final RegExp timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  /// Convert [TimeOfDay] to storage string
  static String localTimeOfDayToString(TimeOfDay localTime) {
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _stringToTimeOfDay(String time) {
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return const TimeOfDay(hour: 7, minute: 30);
  }

  /// Get route start time in the local timezone
  TimeOfDay get startLocal => _stringToTimeOfDay(start);

  /// Get route end time in the local timezone
  TimeOfDay get endLocal => _stringToTimeOfDay(end);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommuteWindows &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode {
    return start.hashCode ^ end.hashCode;
  }

  @override
  String toString() {
    return 'CommuteWindows(start: $start, end: $end)';
  }
}
