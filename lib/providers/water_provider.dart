import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class WaterProvider with ChangeNotifier {
  int _dailyAmount = 0;
  int _targetAmount = 3000; // Default 3L
  String? _authToken;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: (dotenv.env['API_URL'] ?? 'http://localhost:8000').endsWith('/') 
        ? (dotenv.env['API_URL'] ?? 'http://localhost:8000') 
        : '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/',
  ));

  int get dailyAmount => _dailyAmount;
  int get targetAmount => _targetAmount;
  double get progress => _targetAmount > 0 ? (_dailyAmount / _targetAmount).clamp(0.0, 1.0) : 0.0;

  void updateTargetAmount(int newTarget) {
    _targetAmount = newTarget;
    notifyListeners();
  }

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchTodayWater();
    }
  }

  Future<void> fetchTodayWater() async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        '/water/today',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      _dailyAmount = response.data['amount_ml'];
      notifyListeners();
    } catch (e) {
      print('Fetch Water Error: $e');
    }
  }

  Future<void> addWater(int amountMl) async {
    if (_authToken == null) return;
    final newAmount = _dailyAmount + amountMl;
    
    // Optimistic UI
    _dailyAmount = newAmount;
    notifyListeners();

    try {
      await _dio.post(
        '/water/',
        data: {
          'amount_ml': newAmount,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        },
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
    } catch (e) {
      _dailyAmount -= amountMl; // Rollback
      notifyListeners();
      print('Add Water Error: $e');
    }
  }
}
