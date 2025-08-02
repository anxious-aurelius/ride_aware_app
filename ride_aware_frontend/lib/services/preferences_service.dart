import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_preferences.dart';
import 'device_id_service.dart';

class PreferencesService {
  static const String _preferencesKey = 'user_preferences';
  static const String _thresholdsSetKey = 'thresholdsSet';
  static const String _prefsVersionKey = 'prefsVersion';

  final DeviceIdService _deviceIdService = DeviceIdService();

  // Get device ID (now participant ID hash) through preferences service
  Future<String?> getDeviceId() async {
    // Renamed to getParticipantIdHash in DeviceIdService
    return await _deviceIdService.getParticipantIdHash();
  }

  // Save preferences with device ID metadata
  Future<void> savePreferencesWithDeviceId(UserPreferences preferences) async {
    final String? deviceId = await _deviceIdService
        .getParticipantIdHash(); // Use new method
    final prefs = await SharedPreferences.getInstance();

    // Save preferences as usual
    final jsonString = jsonEncode(preferences.toJson());
    await prefs.setString(_preferencesKey, jsonString);
    await prefs.setBool(_thresholdsSetKey, true);
    await prefs.setInt(_prefsVersionKey, 1);

    // Also save device ID for reference (optional)
    if (deviceId != null) {
      await prefs.setString('preferences_device_id', deviceId);
    }
  }

  // Save preferences to local storage
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(preferences.toJson());

    await prefs.setString(_preferencesKey, jsonString);
    await prefs.setBool(_thresholdsSetKey, true);
    await prefs.setInt(_prefsVersionKey, 1);
  }

  // Load preferences from local storage
  Future<UserPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_preferencesKey);

    if (jsonString == null) {
      return UserPreferences.defaultValues();
    }

    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserPreferences.fromJson(jsonMap);
    } catch (e) {
      // If parsing fails, return default values
      return UserPreferences.defaultValues();
    }
  }

  // Check if preferences have been set
  Future<bool> arePreferencesSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_thresholdsSetKey) ?? false;
  }

  // Get preferences version
  Future<int> getPreferencesVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsVersionKey) ?? 0;
  }

  // Clear all preferences (for testing or reset functionality)
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_preferencesKey);
    await prefs.remove(_thresholdsSetKey);
    await prefs.remove(_prefsVersionKey);
  }

  // Check if preferences exist in storage
  Future<bool> hasStoredPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_preferencesKey);
  }
}
