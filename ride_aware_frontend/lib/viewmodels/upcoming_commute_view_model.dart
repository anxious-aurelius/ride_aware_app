import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../models/route_model.dart';
import '../models/geo_point.dart';
import '../services/preferences_service.dart';
import '../services/forecast_service.dart';
import '../services/user_route_service.dart';

class CommuteAlertResult {
  final DateTime time;
  final WeatherLimits limits;
  final RouteModel route;
  final Map<String, dynamic> forecast;
  final String status; // ok, warning, alert
  final List<String> issues;
  final List<String> borderline;

  CommuteAlertResult({
    required this.time,
    required this.limits,
    required this.route,
    required this.forecast,
    required this.status,
    required this.issues,
    required this.borderline,
  });
}

class UpcomingCommuteViewModel extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();
  final ForecastService _forecastService = ForecastService();
  final UserRouteService _routeService = UserRouteService();

  bool isLoading = false;
  String? error;
  bool needsCommuteTime = false;
  CommuteAlertResult? result;

  Future<void> load() async {
    isLoading = true;
    error = null;
    needsCommuteTime = false;
    notifyListeners();

    try {
      final prefsSet = await _prefsService.arePreferencesSet();
      if (!prefsSet) {
        needsCommuteTime = true;
        return;
      }
      final prefs = await _prefsService.loadPreferences();
      final route = await _routeService.fetchRoute();
      if (route == null) {
        error = 'No route saved';
        return;
      }

      final DateTime targetTime = _nextCommuteTime(prefs);
      final forecast = await _forecastService.getForecast(
          route.startLocation.latitude,
          route.startLocation.longitude,
          targetTime);
      final evaluation = _evaluate(forecast, prefs.weatherLimits, route);
      forecast['headwind'] = evaluation['headwind'];
      forecast['crosswind'] = evaluation['crosswind'];
      result = CommuteAlertResult(
        time: targetTime,
        limits: prefs.weatherLimits,
        route: route,
        forecast: forecast,
        status: evaluation['status'] as String,
        issues: List<String>.from(evaluation['issues'] as List),
        borderline: List<String>.from(evaluation['borderline'] as List),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  DateTime _nextCommuteTime(UserPreferences prefs) {
    final now = DateTime.now();
    TimeOfDay rideTime = prefs.commuteWindows.morningLocal;
    DateTime scheduled = DateTime(
      now.year,
      now.month,
      now.day + 1,
      rideTime.hour,
      rideTime.minute,
    );
    return scheduled;
  }

  Map<String, dynamic> _evaluate(
      Map<String, dynamic> forecast, WeatherLimits limits, RouteModel route) {
    final List<String> issues = [];
    final List<String> borderline = [];

    double wind = (forecast['wind_speed'] ?? 0).toDouble();
    double rain = (forecast['rain'] ?? 0).toDouble();
    double humidity = (forecast['humidity'] ?? 0).toDouble();
    double temp = (forecast['temp'] ?? 0).toDouble();
    double windDeg = (forecast['wind_deg'] ?? 0).toDouble();

    if (wind > limits.maxWindSpeed) {
      issues.add('Wind speed > ${limits.maxWindSpeed} m/s');
    } else if (wind > limits.maxWindSpeed * 0.8) {
      borderline.add('Wind speed near limit');
    }

    if (rain > limits.maxRainIntensity) {
      issues.add('Rain > ${limits.maxRainIntensity} mm');
    } else if (rain > limits.maxRainIntensity * 0.8) {
      borderline.add('Rain near limit');
    }

    if (humidity > limits.maxHumidity) {
      issues.add('Humidity > ${limits.maxHumidity}%');
    }

    if (temp < limits.minTemperature || temp > limits.maxTemperature) {
      issues.add(
          'Temperature outside ${limits.minTemperature}-${limits.maxTemperature}°C');
    } else if (temp < limits.minTemperature + 2 ||
        temp > limits.maxTemperature - 2) {
      borderline.add('Temperature near limit');
    }

    // Headwind and crosswind evaluation
    final bearing = _bearing(route.startLocation, route.endLocation);
    final rel = ((windDeg - bearing) + 360) % 360;
    final head = wind * math.cos(rel * math.pi / 180);
    final cross = wind * math.sin(rel * math.pi / 180);

    if (head.abs() > limits.headwindSensitivity) {
      issues.add('Headwind > ${limits.headwindSensitivity} m/s');
    } else if (head.abs() > limits.headwindSensitivity * 0.8) {
      borderline.add('Headwind near limit');
    }

    if (cross.abs() > limits.crosswindSensitivity) {
      issues.add('Crosswind > ${limits.crosswindSensitivity} m/s');
    } else if (cross.abs() > limits.crosswindSensitivity * 0.8) {
      borderline.add('Crosswind near limit');
    }

    final status = issues.isNotEmpty
        ? 'alert'
        : (borderline.isNotEmpty ? 'warning' : 'ok');

    return {
      'status': status,
      'issues': issues,
      'borderline': borderline,
      'headwind': head.abs(),
      'crosswind': cross.abs(),
    };
  }

  double _bearing(GeoPoint a, GeoPoint b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  Future<void> setCommuteTime(TimeOfDay time) async {
    final prefs = await _prefsService.loadPreferences();
    final updated = prefs.copyWith(
      commuteWindows: prefs.commuteWindows.copyWith(
        morning: CommuteWindows.localTimeOfDayToUtc(time),
      ),
    );
    await _prefsService.savePreferences(updated);
    await load();
  }
}
