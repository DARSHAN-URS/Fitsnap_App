import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferencesHelper {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Save a string securely (all keys are stored securely per user request)
  static Future<void> saveString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error writing secure string key $key: $e');
    }
  }

  static Future<String?> readString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('Error reading secure string key $key: $e');
      return null;
    }
  }

  // StringList helpers
  static Future<void> saveStringList(String key, List<String> value) async {
    try {
      await _secureStorage.write(key: key, value: jsonEncode(value));
    } catch (e) {
      debugPrint('Error writing secure string list key $key: $e');
    }
  }

  static Future<List<String>?> readStringList(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      try {
        final List<dynamic> decoded = jsonDecode(value);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return null;
      }
    } catch (e) {
      debugPrint('Error reading secure string list key $key: $e');
      return null;
    }
  }

  // Save/read boolean values securely
  static Future<void> saveBool(String key, bool value) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
    } catch (e) {
      debugPrint('Error writing secure bool key $key: $e');
    }
  }

  static Future<bool?> readBool(String key) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val == null) return null;
      return val == 'true';
    } catch (e) {
      debugPrint('Error reading secure bool key $key: $e');
      return null;
    }
  }

  // Save/read integer values securely
  static Future<void> saveInt(String key, int value) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
    } catch (e) {
      debugPrint('Error writing secure int key $key: $e');
    }
  }

  static Future<int?> readInt(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      return int.tryParse(value);
    } catch (e) {
      debugPrint('Error reading secure int key $key: $e');
      return null;
    }
  }

  // Double helpers
  static Future<void> saveDouble(String key, double value) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
    } catch (e) {
      debugPrint('Error writing secure double key $key: $e');
    }
  }

  static Future<double?> readDouble(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      return double.tryParse(value);
    } catch (e) {
      debugPrint('Error reading secure double key $key: $e');
      return null;
    }
  }

  // Deletion helper
  static Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting secure key $key: $e');
    }
  }

  // Clear all helper
  static Future<void> clear() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
    }
  }

  // --- Growth Features Helpers ---

  static Future<void> setOnboardingCompleted(bool completed) async {
    await saveBool('onboarding_completed', completed);
  }

  static Future<bool> getOnboardingCompleted() async {
    return await readBool('onboarding_completed') ?? false;
  }

  static Future<void> setReferralCode(String code) async {
    await saveString('referral_code', code);
  }

  static Future<String?> getReferralCode() async {
    return await readString('referral_code');
  }

  static Future<void> setReminderTime(String time) async {
    await saveString('reminder_time', time);
  }

  static Future<String?> getReminderTime() async {
    return await readString('reminder_time');
  }

  // --- Neutral Age & Families Policy Helpers ---

  /// Returns true if the user's saved age is 13 or below.
  static Future<bool> isUnder13() async {
    final ageStr = await readString('profile_age');
    if (ageStr == null || ageStr.trim().isEmpty) {
      final ageInt = await readInt('profile_age');
      if (ageInt != null) return ageInt <= 13;
      return false; // Default to false if unknown
    }
    final parsed = int.tryParse(ageStr.trim());
    if (parsed == null) return false;
    return parsed <= 13;
  }

  /// Helper to get user age as an integer, or null if not yet entered
  static Future<int?> getUserAge() async {
    final ageStr = await readString('profile_age');
    if (ageStr != null && ageStr.trim().isNotEmpty) {
      return int.tryParse(ageStr.trim());
    }
    return await readInt('profile_age');
  }
}
