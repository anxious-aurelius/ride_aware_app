import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'device_id_service.dart';
import 'api_service.dart';

class ForecastService {
  final DeviceIdService _deviceIdService = DeviceIdService();

  Future<Map<String, dynamic>> getForecast(
      double lat, double lon, DateTime time) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/forecast').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'time': time.toIso8601String(),
      },
    );

    final response = await http.get(uri, headers: await _getHeaders());

    if (kDebugMode) {
      print('📡 Forecast API Response: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   Response Body: ${response.body}');
      }
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
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
