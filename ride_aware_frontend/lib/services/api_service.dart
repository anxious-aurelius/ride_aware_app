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
    try {
      final String? deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception(
          'Participant ID not available. Cannot submit thresholds.',
        );
      }

      // Create request body with device_id included
      final requestBody = {...preferences.toJson(), 'device_id': deviceId};

      // Debug messages
      if (kDebugMode) {
        print('🚀 API Request Debug:');
        print('   Endpoint: $baseUrl/thresholds');
        print('   Device ID: $deviceId');
        print('   Request Body: ${jsonEncode(requestBody)}');
        print('   Headers: ${await _getHeaders()}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/thresholds'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      // Wrap response debug prints in kDebugMode
      if (kDebugMode) {
        print('📡 API Response: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('   Response Body: ${response.body}');
        }
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to submit thresholds: ${response.statusCode}');
      }

      // TODO: Handle response data if needed
      // final responseData = jsonDecode(response.body);
    } catch (e) {
      // Wrap error debug prints in kDebugMode
      if (kDebugMode) {
        print('❌ API Error: $e');
      }
      // TODO: Add proper error logging
      throw Exception('Network error: $e');
    }
  }

  /// Submit commute route data to the API
  Future<void> submitRoute(RouteModel route) async {
    try {
      final String? deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot submit route.');
      }

      // Ensure the route model has the correct device ID
      final requestBody = route.copyWith(deviceId: deviceId).toJson();

      if (kDebugMode) {
        print('🚀 API Request Debug (Route):');
        print('   Endpoint: $baseUrl/routes');
        print('   Device ID: $deviceId');
        print('   Request Body: ${jsonEncode(requestBody)}');
        print('   Headers: ${await _getHeaders()}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print('📡 API Response (Route): ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('   Response Body: ${response.body}');
        }
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to submit route: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ API Error (Route): $e');
      }
      throw Exception('Network error: $e');
    }
  }

  /// Submit FCM token to the API
  Future<void> submitFCMToken(String fcmToken) async {
    try {
      final String? deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception(
          'Participant ID not available. Cannot submit FCM token.',
        );
      }

      // Create request body with device_id and fcm_token
      final requestBody = {'device_id': deviceId, 'fcm_token': fcmToken};

      if (kDebugMode) {
        print('🚀 API Request Debug (FCM Token):');
        print('   Endpoint: $baseUrl/fcm/register');
        print('   Device ID: $deviceId');
        print(
          '   FCM Token: ${fcmToken.substring(0, 20)}...',
        ); // Only show first 20 chars for security
        print('   Request Body: ${jsonEncode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fcm/register'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print('📡 API Response (FCM Token): ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('   Response Body: ${response.body}');
        }
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to submit FCM token: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ API Error (FCM Token): $e');
      }
      throw Exception('Network error: $e');
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

  /// Helper method for GET requests with device ID
  Future<http.Response> _getWithDeviceId(String endpoint) async {
    final String? deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      throw Exception(
        'Participant ID not available. Cannot perform GET request.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: {'device_id': deviceId});

    return await http.get(uri, headers: await _getHeaders());
  }

  /// Helper method for POST requests with device ID
  Future<http.Response> _postWithDeviceId(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final String? deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      throw Exception(
        'Participant ID not available. Cannot perform POST request.',
      );
    }

    final requestBody = {...body, 'device_id': deviceId};

    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(requestBody),
    );
  }
}
