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
  final Map<String, dynamic> summary;
  final String status; // ok, warning, alert
  final List<String> issues;
  final List<String> borderline;

  CommuteAlertResult({
    required this.time,
    required this.limits,
    required this.route,
    required this.summary,
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
  List<Map<String, dynamic>>? hourlyForecasts;

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
      final sampled = _sampleRoute(route);
      final evaluation = await _forecastService.evaluateRoute(
          sampled, targetTime, prefs.weatherLimits);
      hourlyForecasts = await _forecastService.getNextHoursForecast(
          route.startLocation.latitude,
          route.startLocation.longitude,
          6);
      result = CommuteAlertResult(
        time: targetTime,
        limits: prefs.weatherLimits,
        route: route,
        summary: Map<String, dynamic>.from(evaluation['summary'] as Map),
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
    final rideTime = prefs.commuteWindows.startLocal;
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      rideTime.hour,
      rideTime.minute,
    );
    return now.isBefore(todayStart)
        ? todayStart
        : todayStart.add(const Duration(days: 1));
  }

  List<GeoPoint> _sampleRoute(RouteModel route, {int samples = 5}) {
    final pts = [route.startLocation, ...route.routePoints, route.endLocation];
    if (pts.length <= samples) return pts;
    final step = (pts.length - 1) / (samples - 1);
    return List.generate(samples, (i) => pts[(i * step).round()]);
  }

  Future<void> setCommuteTime(TimeOfDay time) async {
    final prefs = await _prefsService.loadPreferences();
    final updated = prefs.copyWith(
      commuteWindows: prefs.commuteWindows.copyWith(
        start: CommuteWindows.localTimeOfDayToUtc(time),
      ),
    );
    await _prefsService.savePreferences(updated);
    await load();
  }
}
