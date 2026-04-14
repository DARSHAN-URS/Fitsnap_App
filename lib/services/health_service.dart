import 'package:health/health.dart';
import 'dart:io' show Platform;

class HealthService {
  final Health health = Health();

  static final types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<bool> authorize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    
    try {
      bool? hasPermissions = await health.hasPermissions(types);
      if (hasPermissions != true) {
        bool authorized = await health.requestAuthorization(types);
        return authorized;
      }
      return true;
    } catch (e) {
      print("Auth Error: $e");
      return false;
    }
  }

  Future<List<HealthDataPoint>> fetchData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: yesterday,
        endTime: now,
      );
      return healthData;
    } catch (e) {
      print("Health Data Error: $e");
      return [];
    }
  }
}
