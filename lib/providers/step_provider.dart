import 'dart:async';
import 'package:flutter/material.dart';
import '../models/step.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepProvider with ChangeNotifier {
  int _stepGoal = 10000;
  Stream<StepCount>? _stepCountStream;
  String? _authToken;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: (dotenv.env['API_URL'] ?? 'http://localhost:8000').endsWith('/') 
        ? (dotenv.env['API_URL'] ?? 'http://localhost:8000') 
        : '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/',
  ));

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchTodaySteps();
      fetchWeeklySteps();
    }
  }

  void updateStepGoal(int goal) {
    _stepGoal = goal;
    notifyListeners();
  }
  
  int _baselineSteps = -1; 
  String? _lastTrackedDay;

  List<StepData> _weeklySteps = [];

  StepProvider() {
    _loadBaseline();
    initPedometer();
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    _baselineSteps = prefs.getInt('baseline_steps') ?? -1;
    _lastTrackedDay = prefs.getString('last_tracked_day') ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastTrackedDay != todayStr) {
      _baselineSteps = -1; // Reset for new day
    }
  }

  Future<void> _saveBaseline(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setInt('baseline_steps', steps);
    await prefs.setString('last_tracked_day', todayStr);
    _baselineSteps = steps;
    _lastTrackedDay = todayStr;
  }

  Future<void> initPedometer() async {
    bool granted = await Permission.activityRecognition.request().isGranted;
    if (granted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen(onStepCount).onError(onStepCountError);
    }
  }

  void onStepCount(StepCount event) {
    _processStepDelta(event.steps);
  }

  Future<void> _processStepDelta(int totalStepsSinceBoot) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (_baselineSteps == -1 || _lastTrackedDay != todayStr) {
      // First time tracking today, or first time ever
      // We assume today starts at 0, so baseline is the current total count
      await _saveBaseline(totalStepsSinceBoot);
    }

    int stepsToday = totalStepsSinceBoot - _baselineSteps;
    if (stepsToday < 0) {
      // Phone probably rebooted, reset baseline
      await _saveBaseline(totalStepsSinceBoot);
      stepsToday = 0;
    }

    updateSteps(stepsToday);
  }

  void onStepCountError(error) {
    print('Pedometer Error: $error');
  }

  Future<void> fetchTodaySteps() async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        '/steps/today',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final todayData = StepData.fromJson(response.data);
      
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final index = _weeklySteps.indexWhere((s) => s.date == todayStr);
      
      // Merge with local count if backend is lower (unsynced local steps)
      if (index != -1) {
        if (todayData.stepCount > _weeklySteps[index].stepCount) {
          _weeklySteps[index] = todayData;
        }
      } else {
        _weeklySteps.add(todayData);
      }
      notifyListeners();
    } catch (e) {
      print('Fetch Today Steps Error: $e');
    }
  }

  Future<void> syncStepsToBackend(StepData data) async {
    if (_authToken == null) return;
    try {
      await _dio.post(
        '/steps/',
        data: data.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
    } catch (e) {
      print('Sync Steps Error: $e');
    }
  }

  Future<void> fetchWeeklySteps() async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        '/steps/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final List<dynamic> data = response.data;
      _weeklySteps = data.map((item) => StepData.fromJson(item)).toList();
      notifyListeners();
    } catch (e) {
      print('Fetch Weekly Steps Error: $e');
    }
  }

  StepData getStepsForDate(String dateStr) {
    return _weeklySteps.firstWhere(
      (data) => data.date == dateStr,
      orElse: () => StepData(stepCount: 0, date: dateStr, distance: 0, caloriesBurned: 0),
    );
  }

  int get currentSteps => getStepsForDate(DateFormat('yyyy-MM-dd').format(DateTime.now())).stepCount;
  int get stepGoal => _stepGoal;
  List<StepData> get weeklySteps => [..._weeklySteps];

  double get caloriesBurned => currentSteps * 0.04;
  double get distanceKm => getStepsForDate(DateFormat('yyyy-MM-dd').format(DateTime.now())).distance;

  Timer? _syncTimer;

  void updateSteps(int steps) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayIndex = _weeklySteps.indexWhere((data) => data.date == todayStr);
    
    final newData = StepData(
      stepCount: steps,
      date: todayStr,
      distance: (steps * 0.78) / 1000,
      caloriesBurned: steps * 0.04,
    );

    if (todayIndex != -1) {
      _weeklySteps[todayIndex] = newData;
    } else {
      _weeklySteps.add(newData);
    }
    notifyListeners();
    
    // Debounce sync to backend
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 10), () {
      syncStepsToBackend(newData);
    });
  }
}
