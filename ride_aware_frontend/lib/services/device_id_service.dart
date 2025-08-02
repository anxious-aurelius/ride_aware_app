import 'dart:convert'; // For utf8.encode
import 'package:crypto/crypto.dart'; // For sha256
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class DeviceIdService {
  static const String _participantIdHashKey = 'participantIdHash';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Get the stored participant ID hash.
  /// Returns null if no hash is found (e.g., first launch or after reinstall).
  Future<String?> getParticipantIdHash() async {
    final String? hash = await _secureStorage.read(key: _participantIdHashKey);
    if (kDebugMode) {
      if (hash != null && hash.isNotEmpty) {
        debugPrint('Retrieved existing Participant ID Hash: $hash');
      } else {
        debugPrint('No Participant ID Hash found in secure storage.');
      }
    }
    return hash;
  }

  /// Hashes the provided participant code and stores it securely.
  Future<void> setParticipantCode(String participantCode) async {
    final String hash = _generateSha256Hash(participantCode);
    await _secureStorage.write(key: _participantIdHashKey, value: hash);
    if (kDebugMode) {
      debugPrint('Participant Code hashed and stored: $hash');
    }
  }

  /// Clears the stored participant ID hash.
  /// This will force the user to re-enter their code on next launch.
  Future<void> clearParticipantIdHash() async {
    await _secureStorage.delete(key: _participantIdHashKey);
    if (kDebugMode) {
      debugPrint('Participant ID Hash cleared from secure storage.');
    }
  }

  /// Check if a participant ID hash exists in storage.
  Future<bool> hasParticipantIdHash() async {
    final String? hash = await _secureStorage.read(key: _participantIdHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Helper to generate SHA-256 hash of a string.
  String _generateSha256Hash(String input) {
    final bytes = utf8.encode(input); // Data to be hashed
    final digest = sha256.convert(bytes); // Hash it
    return digest.toString(); // Get the hex string
  }
}
