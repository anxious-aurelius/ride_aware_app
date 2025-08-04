import 'package:flutter/material.dart';
import '../utils/parsing.dart';

class UserPreferences {
  final WeatherLimits weatherLimits;
  final EnvironmentalRisk environmentalRisk;
  final OfficeLocation officeLocation;
  final CommuteWindows commuteWindows;

  const UserPreferences({
    required this.weatherLimits,
    required this.environmentalRisk,
    required this.officeLocation,
    required this.commuteWindows,
  });

  // Default preferences for first-time users
  factory UserPreferences.defaultValues() {
    return UserPreferences(
      weatherLimits: WeatherLimits.defaultValues(),
      environmentalRisk: EnvironmentalRisk.defaultValues(),
      officeLocation: OfficeLocation.empty(),
      commuteWindows: CommuteWindows.defaultValues(),
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
      commuteWindows: CommuteWindows.fromJson(json['commute_windows'] ?? {}),
    );
  }

  // Convert to JSON (for API and local storage)
  Map<String, dynamic> toJson() {
    return {
      'weather_limits': weatherLimits.toJson(),
      'environmental_risk': environmentalRisk.toJson(),
      'office_location': officeLocation.toJson(),
      'commute_windows': commuteWindows.toJson(),
    };
  }

  // Create a copy with updated values
  UserPreferences copyWith({
    WeatherLimits? weatherLimits,
    EnvironmentalRisk? environmentalRisk,
    OfficeLocation? officeLocation,
    CommuteWindows? commuteWindows,
  }) {
    return UserPreferences(
      weatherLimits: weatherLimits ?? this.weatherLimits,
      environmentalRisk: environmentalRisk ?? this.environmentalRisk,
      officeLocation: officeLocation ?? this.officeLocation,
      commuteWindows: commuteWindows ?? this.commuteWindows,
    );
  }

  // Validation
  bool get isValid {
    return weatherLimits.isValid &&
        environmentalRisk.isValid &&
        officeLocation.isValid &&
        commuteWindows.isValid;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        other.weatherLimits == weatherLimits &&
        other.environmentalRisk == environmentalRisk &&
        other.officeLocation == officeLocation &&
        other.commuteWindows == commuteWindows;
  }

  @override
  int get hashCode {
    return weatherLimits.hashCode ^
        environmentalRisk.hashCode ^
        officeLocation.hashCode ^
        commuteWindows.hashCode;
  }

  @override
  String toString() {
    return 'UserPreferences(weatherLimits: $weatherLimits, environmentalRisk: $environmentalRisk, officeLocation: $officeLocation, commuteWindows: $commuteWindows)';
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
  final String morning; // Stored in UTC format (HH:mm)
  final String evening; // Stored in UTC format (HH:mm)

  const CommuteWindows({required this.morning, required this.evening});

  factory CommuteWindows.defaultValues() {
    // Default times in UTC (assuming user is in UTC+0 initially)
    return const CommuteWindows(morning: '07:30', evening: '17:30');
  }

  factory CommuteWindows.fromJson(Map<String, dynamic> json) {
    return CommuteWindows(
      morning: json['morning'] ?? '07:30',
      evening: json['evening'] ?? '17:30',
    );
  }

  Map<String, dynamic> toJson() {
    return {'morning': morning, 'evening': evening};
  }

  CommuteWindows copyWith({String? morning, String? evening}) {
    return CommuteWindows(
      morning: morning ?? this.morning,
      evening: evening ?? this.evening,
    );
  }

  bool get isValid {
    return _isValidTimeFormat(morning) && _isValidTimeFormat(evening);
  }

  bool _isValidTimeFormat(String time) {
    final RegExp timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  /// Convert UTC time string to local TimeOfDay
  TimeOfDay utcToLocalTimeOfDay(String utcTimeString) {
    try {
      final parts = utcTimeString.split(':');
      if (parts.length == 2) {
        final utcHour = int.parse(parts[0]);
        final utcMinute = int.parse(parts[1]);

        // Create a DateTime in UTC for today with the specified time
        final now = DateTime.now();
        final utcDateTime = DateTime.utc(
          now.year,
          now.month,
          now.day,
          utcHour,
          utcMinute,
        );

        // Convert to local time
        final localDateTime = utcDateTime.toLocal();

        return TimeOfDay(
          hour: localDateTime.hour,
          minute: localDateTime.minute,
        );
      }
    } catch (e) {
      // If parsing fails, return default
    }
    return const TimeOfDay(hour: 7, minute: 30);
  }

  /// Convert local TimeOfDay to UTC time string
  static String localTimeOfDayToUtc(TimeOfDay localTime) {
    try {
      // Create a DateTime in local time for today with the specified time
      final now = DateTime.now();
      final localDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        localTime.hour,
        localTime.minute,
      );

      // Convert to UTC
      final utcDateTime = localDateTime.toUtc();

      return '${utcDateTime.hour.toString().padLeft(2, '0')}:${utcDateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // If conversion fails, return the original time as string
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Get morning commute time in local timezone
  TimeOfDay get morningLocal => utcToLocalTimeOfDay(morning);

  /// Get evening commute time in local timezone
  TimeOfDay get eveningLocal => utcToLocalTimeOfDay(evening);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommuteWindows &&
        other.morning == morning &&
        other.evening == evening;
  }

  @override
  int get hashCode {
    return morning.hashCode ^ evening.hashCode;
  }

  @override
  String toString() {
    return 'CommuteWindows(morning: $morning UTC, evening: $evening UTC)';
  }
}
