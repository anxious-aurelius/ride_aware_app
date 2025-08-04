import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/parsing.dart';
import 'device_id_service.dart';
import 'api_service.dart';
import '../models/geo_point.dart';
import '../models/user_preferences.dart';

class ForecastService {
  final DeviceIdService _deviceIdService;
  final http.Client _client;

  ForecastService({DeviceIdService? deviceIdService, http.Client? client})
    : _deviceIdService = deviceIdService ?? DeviceIdService(),
      _client = client ?? http.Client();

  Future<Map<String, dynamic>> getForecast(
    double lat,
    double lon,
    DateTime time,
  ) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/forecast').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'time': time.toIso8601String(),
      },
    );

    final response = await _client.get(uri, headers: await _getHeaders());

    if (kDebugMode) {
      print('📡 Forecast API Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   Response Body: ${response.body}');
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      const numericKeys = {
        'wind_speed',
        'wind_deg',
        'rain',
        'humidity',
        'temp',
        'visibility',
        'uvi',
        'clouds',
      };
      for (final key in numericKeys) {
        if (data.containsKey(key)) {
          data[key] = parseDouble(data[key]);
        }
      }
      return data;
    } else {
      throw Exception('Failed to load forecast: ${response.statusCode}');
    }
  }

  /// Evaluate weather along a route of [points] at the specified [time].
  Future<Map<String, dynamic>> evaluateRoute(
    List<GeoPoint> points,
    DateTime time,
    WeatherLimits limits,
  ) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/forecast/route');
    final body = {
      'points':
          points.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
      'time': time.toIso8601String(),
      'thresholds': limits.toJson(),
    };

    final response =
        await _client.post(uri, headers: await _getHeaders(), body: jsonEncode(body));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to evaluate route: ${response.statusCode}');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId ?? 'unknown',
    };
  }
}
