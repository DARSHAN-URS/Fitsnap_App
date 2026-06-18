import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class HealthSyncService {
  static final Health _health = Health();

  static Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WATER,
    ];

    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];

    try {
      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus.isDenied) {
          return false;
        }
      }

      bool hasPermissions = await _health.hasPermissions(types, permissions: permissions) ?? false;
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
      }
      return hasPermissions;
    } catch (e) {
      debugPrint("Health authorization error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchTodayData() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WATER,
    ];

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    int steps = 0;
    double calories = 0;
    double water = 0;

    try {
      final bool hasPerms = await requestPermissions();
      if (!hasPerms) {
        return {'success': false, 'error': 'Permissions not granted'};
      }

      final List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: types,
      );

      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          steps += (data.value as NumericHealthValue).numericValue.toInt();
        } else if (data.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          calories += (data.value as NumericHealthValue).numericValue.toDouble();
        } else if (data.type == HealthDataType.WATER) {
          water += (data.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      return {
        'success': true,
        'data': {
          'steps': steps,
          'calories': calories.toInt(),
          'water': water,
        }
      };
    } catch (e) {
      debugPrint("Health data fetch error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
