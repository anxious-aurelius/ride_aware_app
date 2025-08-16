import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/commute_status.dart';
import 'device_id_service.dart';

class CommuteStatusApiService {
  static final CommuteStatusApiService _instance =
      CommuteStatusApiService._internal();
  factory CommuteStatusApiService() => _instance;
  CommuteStatusApiService._internal();

  static const String baseUrl = 'http://81.17.60.64:8888';

  final DeviceIdService _deviceIdService = DeviceIdService();

  Future<CommuteStatusResponse> getCommuteStatus() async {
    try {
      final String? deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception(
          'Device ID not available. Cannot fetch commute status.',
        );
      }

      final url = Uri.parse('$baseUrl/commute/status/$deviceId');

      if (kDebugMode) {
        print('   Commute Status API Request:');
        print('   Endpoint: $url');
        print('   Device ID: $deviceId');
      }

      final response = await http.get(url, headers: await _getHeaders());

      if (kDebugMode) {
        print(' Commute Status API Response: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('   Response Body: ${response.body}');
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return CommuteStatusResponse.fromJson(responseData);
      } else if (response.statusCode == 404) {
        throw Exception('No commute status found for this device');
      } else {
        throw Exception('Failed to get commute status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print(' Commute Status API Error: $e');
      }
      rethrow;
    }
  }


  Future<Map<String, String>> _getHeaders() async {
    final String? deviceId = await _deviceIdService.getParticipantIdHash();

    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId ?? 'unknown',
    };
  }
}
