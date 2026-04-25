import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SuggestionProvider with ChangeNotifier {
  String? _foodSuggestion;
  String? _exerciseSuggestion;
  bool _isLoading = false;
  String? _authToken;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: (dotenv.env['API_URL'] ?? 'http://localhost:8000').endsWith('/') 
        ? (dotenv.env['API_URL'] ?? 'http://localhost:8000') 
        : '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/',
  ));

  String? get foodSuggestion => _foodSuggestion;
  String? get exerciseSuggestion => _exerciseSuggestion;
  bool get isLoading => _isLoading;

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchDailySuggestions();
    }
  }

  Future<void> fetchDailySuggestions() async {
    if (_authToken == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get(
        'suggestions/daily',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      _foodSuggestion = response.data['food_suggestion'];
      _exerciseSuggestion = response.data['exercise_suggestion'];
    } catch (e) {
      print('Fetch Suggestions Error: $e');
      _foodSuggestion = "Focus on a balanced breakfast with high fiber.";
      _exerciseSuggestion = "A 15-minute stretching session can improve your flexibility.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
