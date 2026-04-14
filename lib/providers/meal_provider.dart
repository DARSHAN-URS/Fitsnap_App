import 'dart:async';
import 'package:flutter/material.dart';
import '../models/meal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealProvider with ChangeNotifier {
  List<Meal> _meals = [];
  double _calorieGoal = 2500.0;
  String? _authToken;
  Timer? _pollingTimer;
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
  ));

  List<Meal> get meals => [..._meals];
  double get calorieGoal => _calorieGoal;

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchMeals();
    } else {
      _meals = [];
      _stopPolling();
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchMeals(isBackground: true);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchMeals({bool isBackground = false}) async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        '/meals/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final List<dynamic> data = response.data;
      _meals = data.map((item) => Meal.fromJson(item)).toList();
      
      // If any meal is still processing, keep polling
      bool hasProcessing = _meals.any((m) => m.status == "processing");
      if (hasProcessing) {
        if (_pollingTimer == null) _startPolling();
      } else {
        _stopPolling();
      }

      if (!isBackground) notifyListeners();
      if (isBackground && hasProcessing) notifyListeners(); // Only update UI in background if state changed noticeably
      
      // Force update if we just finished processing something
      if (isBackground && !hasProcessing) notifyListeners();

    } catch (e) {
      print('Fetch Meals Error: $e');
      _stopPolling();
    }
  }

  Future<void> addMealWithImage(String imagePath) async {
    if (_authToken == null) return;
    try {
      String fileName = imagePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imagePath, filename: fileName),
      });

      final response = await _dio.post(
        '/meals/',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      
      final newMeal = Meal.fromJson(response.data);
      _meals.insert(0, newMeal);
      notifyListeners();
    } catch (e) {
      print('Add Meal Error: $e');
    }
  }

  void setCalorieGoal(double goal) {
    _calorieGoal = goal;
    notifyListeners();
  }

  double getCaloriesForDate(DateTime date) {
    return _meals
        .where((meal) =>
            meal.createdAt.year == date.year &&
            meal.createdAt.month == date.month &&
            meal.createdAt.day == date.day)
        .fold(0, (sum, meal) => sum + meal.calories);
  }

  double getProteinForDate(DateTime date) {
    return _meals
        .where((meal) =>
            meal.createdAt.year == date.year &&
            meal.createdAt.month == date.month &&
            meal.createdAt.day == date.day)
        .fold(0, (sum, meal) => sum + meal.protein);
  }

  double getCarbsForDate(DateTime date) {
    return _meals
        .where((meal) =>
            meal.createdAt.year == date.year &&
            meal.createdAt.month == date.month &&
            meal.createdAt.day == date.day)
        .fold(0, (sum, meal) => sum + meal.carbs);
  }

  double getFatForDate(DateTime date) {
    return _meals
        .where((meal) =>
            meal.createdAt.year == date.year &&
            meal.createdAt.month == date.month &&
            meal.createdAt.day == date.day)
        .fold(0, (sum, meal) => sum + meal.fat);
  }

  double get todayCalories => getCaloriesForDate(DateTime.now());
  double get todayProtein => getProteinForDate(DateTime.now());
  double get todayCarbs => getCarbsForDate(DateTime.now());
  double get todayFat => getFatForDate(DateTime.now());
}
