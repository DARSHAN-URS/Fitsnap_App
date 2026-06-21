import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:io';
import 'dart:async';

class HealthSyncService {
  static final Health _health = Health();
  static StreamSubscription<StepCount>? _pedometerSubscription;

  // Initialize Pedometer listening
  static void initPedometer() async {
    if (_pedometerSubscription != null) return;

    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      if (status.isDenied) {
        // Do not auto-initialize stream if permission is not yet granted
        return;
      }
    }

    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _handlePedometerEvent(event.steps);
        },
        onError: (error) {
          debugPrint("Pedometer error: $error");
        },
      );
    } catch (e) {
      debugPrint("Pedometer initialization error: $e");
    }
  }

  static void stopPedometer() {
    _pedometerSubscription?.cancel();
    _pedometerSubscription = null;
  }

  // Handle a new step count event from Pedometer (steps since last boot)
  static Future<void> _handlePedometerEvent(int stepsSinceBoot) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final lastCheckDate = prefs.getString('pedometer_last_check_date') ?? '';
    int todaySteps = prefs.getInt('pedometer_today_steps') ?? 0;
    int lastBootSteps = prefs.getInt('pedometer_last_boot_steps') ?? stepsSinceBoot;

    if (lastCheckDate != todayStr) {
      // It's a new day! Reset baseline and start from 0
      await prefs.setString('pedometer_last_check_date', todayStr);
      await prefs.setInt('pedometer_last_boot_steps', stepsSinceBoot);
      await prefs.setInt('pedometer_today_steps', 0);
      todaySteps = 0;
      lastBootSteps = stepsSinceBoot;
    } else {
      if (stepsSinceBoot >= lastBootSteps) {
        final diff = stepsSinceBoot - lastBootSteps;
        todaySteps += diff;
        await prefs.setInt('pedometer_today_steps', todaySteps);
        await prefs.setInt('pedometer_last_boot_steps', stepsSinceBoot);
      } else {
        // Device was rebooted
        await prefs.setInt('pedometer_last_boot_steps', stepsSinceBoot);
      }
    }

    // Also write to active day steps so UI can react
    final homeSteps = prefs.getInt('home_steps') ?? 0;
    final currentTodayCombined = await getCombinedStepsToday();
    if (currentTodayCombined > homeSteps) {
      await prefs.setInt('home_steps', currentTodayCombined);
      await prefs.setInt('home_steps_$todayStr', currentTodayCombined);
    }
  }

  // Manually force a baseline reset (useful during timezone / day transitions)
  static Future<void> resetBaselineForNewDay(String newDateStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pedometer_last_check_date', newDateStr);
    final lastBootSteps = prefs.getInt('pedometer_last_boot_steps') ?? 0;
    await prefs.setInt('pedometer_last_boot_steps', lastBootSteps);
    await prefs.setInt('pedometer_today_steps', 0);
  }

  // Get total steps today from the mobile sensor (pedometer)
  static Future<int> getMobileSensorSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final lastCheckDate = prefs.getString('pedometer_last_check_date') ?? '';
    if (lastCheckDate != todayStr) {
      return 0;
    }
    return prefs.getInt('pedometer_today_steps') ?? 0;
  }

  // Get combined steps today (max of Health Connect and Mobile Sensor)
  static Future<int> getCombinedStepsToday() async {
    int healthSteps = 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      final hasPerms = await _health.hasPermissions([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]) ?? false;
      if (hasPerms) {
        final stepsVal = await _health.getTotalStepsInInterval(midnight, now);
        healthSteps = stepsVal ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching health steps: $e");
    }

    final sensorSteps = await getMobileSensorSteps();
    final combined = healthSteps > sensorSteps ? healthSteps : sensorSteps;
    return combined;
  }

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

      // Initialize pedometer listening after activity recognition is granted
      initPedometer();

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
      // Initialize pedometer to ensure stream starts
      initPedometer();

      final bool hasPerms = await requestPermissions();
      if (!hasPerms) {
        // If Health permissions are denied, fallback to mobile sensor
        final sensorSteps = await getMobileSensorSteps();
        return {
          'success': true,
          'data': {
            'steps': sensorSteps,
            'calories': (sensorSteps * 0.04).toInt(),
            'water': 0,
          }
        };
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

      // Combine with mobile sensor steps (pedometer)
      final sensorSteps = await getMobileSensorSteps();
      if (sensorSteps > steps) {
        steps = sensorSteps;
        final sensorCalories = (sensorSteps * 0.04).toInt();
        if (sensorCalories > calories) {
          calories = sensorCalories.toDouble();
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
      final sensorSteps = await getMobileSensorSteps();
      return {
        'success': true,
        'data': {
          'steps': sensorSteps,
          'calories': (sensorSteps * 0.04).toInt(),
          'water': 0,
        }
      };
    }
  }
}
