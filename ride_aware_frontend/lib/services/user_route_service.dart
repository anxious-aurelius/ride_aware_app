import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import 'device_id_service.dart';
import 'api_service.dart';

class UserRouteService {
  final DeviceIdService _deviceIdService = DeviceIdService();

  Future<RouteModel?> fetchRoute() async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      return null;
    }

    final uri = Uri.parse('${ApiService.baseUrl}/routes/$deviceId');
    final response = await http.get(uri, headers: await _getHeaders());

    if (kDebugMode) {
      print('📡 Route Fetch Response: ${response.statusCode}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RouteModel.fromJson(data);
    } else {
      return null;
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
