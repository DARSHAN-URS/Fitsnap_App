import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferencesHelper {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Save a string securely (all keys are stored securely per user request)
  static Future<void> saveString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readString(String key) async {
    return await _secureStorage.read(key: key);
  }

  // StringList helpers
  static Future<void> saveStringList(String key, List<String> value) async {
    await _secureStorage.write(key: key, value: jsonEncode(value));
  }

  static Future<List<String>?> readStringList(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(value);
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  // Save/read boolean values securely
  static Future<void> saveBool(String key, bool value) async {
    await _secureStorage.write(key: key, value: value.toString());
  }

  static Future<bool?> readBool(String key) async {
    final val = await _secureStorage.read(key: key);
    if (val == null) return null;
    return val == 'true';
  }

  // Save/read integer values securely
  static Future<void> saveInt(String key, int value) async {
    await _secureStorage.write(key: key, value: value.toString());
  }

  static Future<int?> readInt(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  // Double helpers
  static Future<void> saveDouble(String key, double value) async {
    await _secureStorage.write(key: key, value: value.toString());
  }

  static Future<double?> readDouble(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  // Deletion helper
  static Future<void> delete(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Clear all helper
  static Future<void> clear() async {
    await _secureStorage.deleteAll();
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
}
