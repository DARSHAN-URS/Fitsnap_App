import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/preferences_helper.dart';
import 'api_service.dart';

class StepTrackingService {
  static const MethodChannel _channel = MethodChannel('com.sabtrack.ai/steps');
  static final Health _health = Health();

  // Fetch native sensor steps today
  static Future<int> getNativeSteps() async {
    if (!Platform.isAndroid) return 0;
    try {
      final int? steps = await _channel.invokeMethod<int>('getTodaySteps');
      return steps ?? 0;
    } catch (e) {
      debugPrint("Error fetching native steps: $e");
      return 0;
    }
  }

  // Fetch native sensor value (total steps since boot)
  static Future<int> getSensorValue() async {
    if (!Platform.isAndroid) return -1;
    try {
      final int? sensorValue = await _channel.invokeMethod<int>('getSensorValue');
      return sensorValue ?? -1;
    } catch (e) {
      debugPrint("Error fetching sensor value: $e");
      return -1;
    }
  }

  // Fetch native sensor baseline
  static Future<int> getBaseline() async {
    if (!Platform.isAndroid) return -1;
    try {
      final int? baseline = await _channel.invokeMethod<int>('getBaseline');
      return baseline ?? -1;
    } catch (e) {
      debugPrint("Error fetching baseline: $e");
      return -1;
    }
  }

  // Reset native baseline manually
  static Future<bool> resetBaseline(int sensorValue, int steps) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('resetBaseline', {
        'sensorValue': sensorValue,
        'steps': steps,
      });
      return success ?? false;
    } catch (e) {
      debugPrint("Error resetting baseline: $e");
      return false;
    }
  }

  // Request Health Connect and Activity Recognition permissions
  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus.isDenied) {
          debugPrint("Activity recognition permission denied");
          return false;
        }
        if (activityStatus.isGranted) {
          try {
            await _channel.invokeMethod('startStepCounterService');
          } catch (e) {
            debugPrint("Failed to start step counter service: $e");
          }
        }
      }

      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      bool hasPermissions = await _health.hasPermissions(types, permissions: permissions) ?? false;
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(types, permissions: permissions);
      }
      return hasPermissions;
    } catch (e) {
      debugPrint("Error requesting health permissions: $e");
      return false;
    }
  }

  // Fetch today's steps from Health Connect
  static Future<int> getHealthConnectStepsToday() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      final hasPerms = await _health.hasPermissions([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]) ?? false;
      if (hasPerms) {
        final stepsVal = await _health.getTotalStepsInInterval(midnight, now);
        return stepsVal ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching Health Connect steps: $e");
    }
    return 0;
  }

  // Estimate stride length in cm based on height
  static double getStrideLength(double heightCm) {
    return heightCm * 0.414;
  }

  // Estimate active calories using Mifflin-St Jeor formula and speed-based METs
  static int estimateActiveCalories({
    required int steps,
    required double weight,
    required double height,
    required int age,
    required String gender,
  }) {
    if (steps <= 0) return 0;

    // Calculate BMR using Mifflin-St Jeor
    double bmr = 0;
    if (gender.toLowerCase() == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    // Dynamic speed estimation:
    // Stride length (cm) = height * 0.414
    // Assumed cadence = 100 steps/min
    // Speed (km/h) = cadence * 60 min/h * stride (cm) / 100000 cm/km
    final double strideCm = getStrideLength(height);
    final double speedKmh = 100.0 * 60.0 * strideCm / 100000.0;

    // Select MET (Metabolic Equivalent of Task) based on estimated speed
    double met = 3.5;
    if (speedKmh < 3.2) {
      met = 2.0;
    } else if (speedKmh < 4.5) {
      met = 2.8;
    } else if (speedKmh < 5.5) {
      met = 3.5;
    } else if (speedKmh < 6.5) {
      met = 4.3;
    } else {
      met = 5.0;
    }

    // Walking BMR per hour = BMR / 24
    // Active MET = MET - 1 (subtracting resting metabolism)
    // Duration in hours = steps / (cadence of 100 steps/min * 60 minutes)
    final double durationHours = steps / 6000.0;
    final double activeMET = (met - 1.0).clamp(0.0, 5.0);
    final double activeCalories = activeMET * (bmr / 24.0) * durationHours;

    return activeCalories.round();
  }

  // Get full combined steps and metrics today
  static Future<Map<String, dynamic>> getStepsMetricsToday() async {
    final int nativeSteps = await getNativeSteps();
    final int hcSteps = await getHealthConnectStepsToday();
    final int finalSteps = nativeSteps > hcSteps ? nativeSteps : hcSteps;

    // Load user profile details for calculations (fall back to defaults if not set)
    final String ageStr = await PreferencesHelper.readString('profile_age') ?? '25';
    final int age = int.tryParse(ageStr) ?? 25;
    final double weight = await PreferencesHelper.readDouble('profile_weight') ?? 75.0;
    final double height = await PreferencesHelper.readDouble('profile_height') ?? 175.0;
    final String gender = await PreferencesHelper.readString('profile_gender') ?? 'Male';

    // Stride-based distance estimation
    final double strideCm = getStrideLength(height);
    final double distanceKm = finalSteps * (strideCm / 100000.0);

    // Active calories estimation (Mifflin-St Jeor + METs)
    final int calories = estimateActiveCalories(
      steps: finalSteps,
      weight: weight,
      height: height,
      age: age,
      gender: gender,
    );

    // Active minutes estimation: 100 steps per minute cadence
    final int activeMinutes = finalSteps ~/ 100;

    final int baseline = await getBaseline();
    final int sensorValue = await getSensorValue();
    final String todayDate = DateTime.now().toIso8601String().split('T')[0];

    return {
      'date': todayDate,
      'sensor_steps': nativeSteps,
      'health_connect_steps': hcSteps,
      'final_steps': finalSteps,
      'distance': double.parse(distanceKm.toStringAsFixed(3)),
      'calories': calories,
      'active_minutes': activeMinutes,
      'baseline': baseline != -1 ? baseline : 0,
      'last_sensor_value': sensorValue != -1 ? sensorValue : 0,
    };
  }

  // Synchronize steps data with local caching and offline queue recovery
  static Future<Map<String, dynamic>> syncSteps() async {
    try {
      final metrics = await getStepsMetricsToday();
      
      // Cache metrics locally for instant UI loads
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(metrics);
      await prefs.setString('cached_steps_${metrics['date']}', jsonStr);
      await prefs.setInt('home_steps', metrics['final_steps']);
      await prefs.setInt('home_steps_${metrics['date']}', metrics['final_steps']);

      // Attempt online sync if authenticated
      if (ApiService.isAuthenticated) {
        final res = await ApiService.syncSteps(metrics);
        if (res['success'] == true) {
          // Success! Try draining the offline queue.
          await _drainOfflineQueue();
          return {'success': true, 'data': metrics};
        } else {
          // Sync failed but authenticated, queue for later sync
          await _queueOfflineSync(metrics);
        }
      } else {
        // Unauthenticated, just cache locally
        await _queueOfflineSync(metrics);
      }

      return {'success': true, 'data': metrics, 'offline': true};
    } catch (e) {
      debugPrint("Error syncing steps: $e");
      // Fallback: Read last cached steps
      final todayDate = DateTime.now().toIso8601String().split('T')[0];
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_steps_$todayDate');
      if (cachedStr != null) {
        return {'success': true, 'data': jsonDecode(cachedStr), 'offline': true};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // Add steps record to the offline queue
  static Future<void> _queueOfflineSync(Map<String, dynamic> record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList('offline_steps_queue') ?? [];
      
      // Remove any existing duplicate record for the same date to avoid double sync
      queue.removeWhere((item) {
        try {
          final Map<String, dynamic> map = jsonDecode(item);
          return map['date'] == record['date'];
        } catch (_) {
          return false;
        }
      });

      queue.add(jsonEncode(record));
      await prefs.setStringList('offline_steps_queue', queue);
      debugPrint("Step record for ${record['date']} queued offline.");
    } catch (e) {
      debugPrint("Error queuing offline steps: $e");
    }
  }

  // Attempt to upload all queued offline records
  static Future<void> _drainOfflineQueue() async {
    if (!ApiService.isAuthenticated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList('offline_steps_queue') ?? [];
      if (queue.isEmpty) return;

      debugPrint("Draining steps offline queue. Items count: ${queue.length}");
      final List<String> failedItems = [];

      for (final item in queue) {
        try {
          final Map<String, dynamic> record = jsonDecode(item);
          final res = await ApiService.syncSteps(record);
          if (res['success'] != true) {
            failedItems.add(item);
          }
        } catch (e) {
          debugPrint("Failed to sync queued item: $e");
          failedItems.add(item);
        }
      }

      await prefs.setStringList('offline_steps_queue', failedItems);
      debugPrint("Draining complete. Remaining queued items: ${failedItems.length}");
    } catch (e) {
      debugPrint("Error draining steps offline queue: $e");
    }
  }
}
