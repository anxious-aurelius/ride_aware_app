import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class DeviceIdService {
  static const String _participantIdHashKey = 'participantIdHash';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();


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

  Future<void> setParticipantCode(String participantCode) async {
    final String hash = _generateSha256Hash(participantCode);
    await _secureStorage.write(key: _participantIdHashKey, value: hash);
    if (kDebugMode) {
      debugPrint('Participant Code hashed and stored: $hash');
    }
  }

  Future<void> clearParticipantIdHash() async {
    await _secureStorage.delete(key: _participantIdHashKey);
    if (kDebugMode) {
      debugPrint('Participant ID Hash cleared from secure storage.');
    }
  }


  Future<bool> hasParticipantIdHash() async {
    final String? hash = await _secureStorage.read(key: _participantIdHashKey);
    return hash != null && hash.isNotEmpty;
  }

  String _generateSha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
