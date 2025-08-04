import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_preferences.dart';
import '../models/route_model.dart'; // Import RouteModel
import 'device_id_service.dart';

class ApiService {
  // TODO: Replace with actual API base URL
  static const String baseUrl = 'http://81.17.60.64:8888';

  final DeviceIdService _deviceIdService = DeviceIdService();

  /// Submit user preferences/thresholds to the API
  Future<void> submitThresholds(UserPreferences preferences) async {
    final response = await _postWithDeviceId(
      '/thresholds',
      preferences.toJson(),
      debugLabel: 'Thresholds',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit thresholds: ${response.statusCode}');
    }
  }

  /// Submit commute route data to the API
  Future<void> submitRoute(RouteModel route) async {
    final response = await _postWithDeviceId(
      '/routes',
      route.toJson(),
      debugLabel: 'Route',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit route: ${response.statusCode}');
    }
  }

  /// Submit FCM token to the API
  Future<void> submitFCMToken(String fcmToken) async {
    final response = await _postWithDeviceId(
      '/fcm/register',
      {'fcm_token': fcmToken},
      debugLabel: 'FCM Token',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit FCM token: ${response.statusCode}');
    }
  }

  /// Get user preferences from the API
  Future<UserPreferences?> getUserPreferences() async {
    try {
      final String? deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        // If no participant ID, no preferences can be fetched
        if (kDebugMode) {
          print(
            'ℹ️ GET Request Debug: No Participant ID available. Skipping preferences fetch.',
          );
        }
        return null;
      }

      final url = Uri.parse('$baseUrl/thresholds/$deviceId');

      if (kDebugMode) {
        print('🚀 GET Request Debug:');
        print('   Endpoint: $url');
        print('   Device ID: $deviceId');
        print('   Headers: ${await _getHeaders()}');
      }

      final response = await http.get(url, headers: await _getHeaders());

      if (kDebugMode) {
        print('📡 GET Response: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('   Response Body: ${response.body}');
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return UserPreferences.fromJson(responseData);
      } else if (response.statusCode == 404) {
        // No preferences found for this device
        return null;
      } else {
        throw Exception('Failed to get preferences: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GET Error: $e');
      }
      throw Exception('Network error: $e');
    }
  }

  /// Get standard headers for API requests
  Future<Map<String, String>> _getHeaders() async {
    final String? deviceId = await _deviceIdService.getParticipantIdHash();

    return {
      'Content-Type': 'application/json',
      'X-Device-Id':
          deviceId ??
          'unknown', // Provide a fallback if ID is null, though it should be handled upstream
    };
  }

  /// Helper method for POST requests with device ID
  Future<http.Response> _postWithDeviceId(
    String endpoint,
    Map<String, dynamic> body, {
    String? debugLabel,
  }) async {
    final String? deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      throw Exception(
        'Participant ID not available. Cannot perform POST request.',
      );
    }

    final requestBody = {...body, 'device_id': deviceId};

    if (kDebugMode && debugLabel != null) {
      print('🚀 API Request Debug ($debugLabel):');
      print('   Endpoint: $baseUrl$endpoint');
      print('   Device ID: $deviceId');
      print('   Request Body: ${jsonEncode(requestBody)}');
      print('   Headers: ${await _getHeaders()}');
    }

    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(requestBody),
    );

    if (kDebugMode && debugLabel != null) {
      print('📡 API Response ($debugLabel): ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('   Response Body: ${response.body}');
      }
    }
    return response;
  }
}
