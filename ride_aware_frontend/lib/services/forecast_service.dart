import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/parsing.dart';
import 'device_id_service.dart';
import 'api_service.dart';

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

  Future<Map<String, String>> _getHeaders() async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId ?? 'unknown',
    };
  }
}
