import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user_preferences.dart';
import '../models/route_model.dart';
import '../models/ride_history_entry.dart';
import '../helpers/schedule.dart';
import 'device_id_service.dart';
import 'preferences_service.dart';

class ApiService {
  // TODO: Replace with your actual API base URL if needed
  static const String baseUrl = 'http://10.0.2.2:8889';

  final DeviceIdService _deviceIdService = DeviceIdService();
  final PreferencesService _preferencesService = PreferencesService();

  // ------------------------------
  // Thresholds
  // ------------------------------
  Future<String?> submitThresholds(UserPreferences preferences) async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot submit thresholds.');
      }

      if (!preferences.isValid) {
        if (kDebugMode) {
          print('❌ Invalid preferences: ${jsonEncode(preferences.toJson())}');
        }
        throw Exception('Invalid threshold values');
      }

      final now = DateTime.now();
      final scheduledStart = pickScheduledStart(now, preferences.commuteWindows.startLocal);

      final body = {
        'device_id': deviceId,
        'date': yyyymmdd(scheduledStart),
        'start_time': preferences.commuteWindows.startLocal.format24h(),
        'end_time': preferences.commuteWindows.endLocal.format24h(),
        'timezone': preferences.timezone ?? 'Europe/London',
        'presence_radius_m': preferences.presenceRadiusM,
        'speed_cutoff_kmh': preferences.speedCutoffKmh,
        'weather_limits': preferences.weatherLimits.toJson(),
        'office_location': preferences.officeLocation.toJson(),
      };

      if (kDebugMode) {
        print('🚀 POST $baseUrl/thresholds');
        print('   headers: ${await _getHeaders()}');
        print('   body: ${jsonEncode(body)}');
      }

      final res = await http.post(
        Uri.parse('$baseUrl/thresholds'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('📡 thresholds -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to submit thresholds: ${res.statusCode}');
      }

      String? thresholdId;
      if (res.body.isNotEmpty) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        thresholdId = data['threshold_id'] as String?;
        if (thresholdId != null) {
          await _preferencesService.saveCurrentThresholdId(thresholdId);
        }
      }
      return thresholdId;
    } catch (e) {
      if (kDebugMode) print('❌ submitThresholds error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<UserPreferences?> getUserPreferences() async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        if (kDebugMode) print('ℹ️ No participant ID, skipping preferences fetch.');
        return null;
      }

      final url = Uri.parse('$baseUrl/thresholds/$deviceId');

      if (kDebugMode) {
        print('🚀 GET $url');
        print('   headers: ${await _getHeaders()}');
      }

      final res = await http.get(url, headers: await _getHeaders());

      if (kDebugMode) {
        print('📡 getUserPreferences -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return UserPreferences.fromJson(data);
      } else if (res.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get preferences: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ getUserPreferences error: $e');
      throw Exception('Network error: $e');
    }
  }

  // ------------------------------
  // Route
  // ------------------------------
  Future<void> submitRoute(RouteModel route) async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot submit route.');
      }

      final body = route.copyWith(deviceId: deviceId).toJson();

      if (kDebugMode) {
        print('🚀 POST $baseUrl/routes');
        print('   headers: ${await _getHeaders()}');
        print('   body: ${jsonEncode(body)}');
      }

      final res = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('📡 submitRoute -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200) {
        throw Exception('Failed to submit route: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ submitRoute error: $e');
      throw Exception('Network error: $e');
    }
  }

  // ------------------------------
  // FCM
  // ------------------------------
  Future<void> submitFCMToken(String fcmToken) async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot submit FCM token.');
      }

      final body = {'device_id': deviceId, 'fcm_token': fcmToken};

      if (kDebugMode) {
        print('🚀 POST $baseUrl/fcm/register');
        print('   headers: ${await _getHeaders()}');
        print('   body: ${jsonEncode(body..['fcm_token'] = '${fcmToken.substring(0, 20)}...')}');
      }

      final res = await http.post(
        Uri.parse('$baseUrl/fcm/register'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('📡 submitFCMToken -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200) {
        throw Exception('Failed to submit FCM token: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ submitFCMToken error: $e');
      throw Exception('Network error: $e');
    }
  }

  // ------------------------------
  // Feedback
  // ------------------------------
  Future<void> submitFeedback(Map<String, dynamic> feedback) async {
    try {
      final pendingId = await _preferencesService.getPendingFeedbackThresholdId();
      final currentId = await _preferencesService.getCurrentThresholdId();
      final thresholdId = pendingId ?? currentId;
      if (thresholdId == null) {
        throw Exception('Threshold ID not available. Cannot submit feedback.');
      }

      final res = await _postWithDeviceId('/feedback', {
        ...feedback,
        'threshold_id': thresholdId,
      });

      if (kDebugMode) {
        print('📡 submitFeedback -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to submit feedback: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ submitFeedback error: $e');
      throw Exception('Network error: $e');
    }
  }

  // ------------------------------
  // Ride history
  // ------------------------------

  /// Typed version (maps into your RideHistoryEntry model).
  Future<List<RideHistoryEntry>> fetchRideHistory({int lastDays = 30}) async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot fetch history.');
      }

      final uri = Uri.parse('$baseUrl/rideHistory').replace(queryParameters: {
        'device_id': deviceId,
        'lastDays': lastDays.toString(),
      });

      final res = await http.get(uri, headers: await _getHeaders());

      if (kDebugMode) {
        print('📡 fetchRideHistory -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200) {
        throw Exception('Failed to fetch ride history: ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as List;
      return data
          .map((e) => RideHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('❌ fetchRideHistory error: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Raw version (returns exact payload from backend, including weather_history).
  Future<List<Map<String, dynamic>>> fetchRideHistoryRaw({int lastDays = 30}) async {
    try {
      final deviceId = await _deviceIdService.getParticipantIdHash();
      if (deviceId == null) {
        throw Exception('Participant ID not available. Cannot fetch history.');
      }

      final uri = Uri.parse('$baseUrl/rideHistory').replace(queryParameters: {
        'device_id': deviceId,
        'lastDays': lastDays.toString(),
      });

      final res = await http.get(uri, headers: await _getHeaders());

      if (kDebugMode) {
        print('📡 Ride History Raw Fetch: ${res.statusCode}');
        if (res.body.isNotEmpty) print('   Body: ${res.body}');
      }

      if (res.statusCode != 200) {
        throw Exception('Failed to load ride history: ${res.statusCode} ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];

      return decoded.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e as Map);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ fetchRideHistoryRaw error: $e');
      rethrow;
    }
  }

  // ------------------------------
  // Ride save
  // ------------------------------
  Future<void> saveRideHistoryEntry(RideHistoryEntry entry) async {
    try {
      final res = await _postWithDeviceId('/rideHistory', entry.toJson());

      if (kDebugMode) {
        print('📡 saveRideHistoryEntry -> ${res.statusCode}');
        if (res.body.isNotEmpty) print('   body: ${res.body}');
      }

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to save ride history: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ saveRideHistoryEntry error: $e');
      throw Exception('Network error: $e');
    }
  }

  // ------------------------------
  // Helpers
  // ------------------------------
  Future<Map<String, String>> _getHeaders() async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId ?? 'unknown',
    };
  }

  Future<http.Response> _getWithDeviceId(String endpoint) async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      throw Exception('Participant ID not available. Cannot perform GET request.');
    }
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {'device_id': deviceId});
    return http.get(uri, headers: await _getHeaders());
  }

  Future<http.Response> _postWithDeviceId(String endpoint, Map<String, dynamic> body) async {
    final deviceId = await _deviceIdService.getParticipantIdHash();
    if (deviceId == null) {
      throw Exception('Participant ID not available. Cannot perform POST request.');
    }
    final requestBody = {...body, 'device_id': deviceId};
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(requestBody),
    );
  }
}
