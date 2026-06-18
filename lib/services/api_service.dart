import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/preferences_helper.dart';

class ApiService {
  static String get _localHost {
    if (kIsWeb) return 'localhost';
    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  static String get localUrl => 'http://$_localHost:3000/api';
  static const String productionUrl = 'https://snapcal-production.up.railway.app/api';
  static String baseUrl = productionUrl; // Default to production
  static String? _token;

  // Configure baseUrl based on environment
  static void configureBaseUrl({required bool isDevelopment}) {
    baseUrl = isDevelopment ? localUrl : productionUrl;
  }

  // Initialize the JWT token from secure storage on startup
  static Future<void> initToken() async {
    try {
      _token = await PreferencesHelper.readString('auth_token');
    } catch (e) {
      debugPrint('Error initializing auth token: $e');
    }
  }

  // Set the JWT token after login
  static void setToken(String token) {
    _token = token.isEmpty ? null : token;
    if (token.isEmpty) {
      PreferencesHelper.delete('auth_token').catchError((e) {
        debugPrint('Error deleting token: $e');
      });
    } else {
      PreferencesHelper.saveString('auth_token', token).catchError((e) {
        debugPrint('Error saving token: $e');
      });
    }
  }

  // --- Authentication ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) setToken(data['token']);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Invalid credentials'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> signup(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) setToken(data['token']);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Signup failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) setToken(data['token']);
        return {'success': true, 'data': data};
      }
      try {
        final data = jsonDecode(response.body);
        return {'success': false, 'error': data['error'] ?? 'Google authentication failed'};
      } catch (_) {
        return {'success': false, 'error': 'Google authentication failed (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Smart Nutrition (Cal AI Feature) ---
  static Future<Map<String, dynamic>> analyzeNutrition({String? imagePath}) async {
    try {
      if (imagePath != null) {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/nutrition/analyze'));
        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }
        final file = await http.MultipartFile.fromPath('image', imagePath);
        request.files.add(file);
        
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          return {'success': true, 'data': jsonDecode(response.body)};
        }
        return {'success': false, 'error': 'Failed to analyze food image'};
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/nutrition/analyze'),
          headers: {
            'Content-Type': 'application/json',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'mockImage': true}),
        );
        
        if (response.statusCode == 200) {
          return {'success': true, 'data': jsonDecode(response.body)};
        }
        return {'success': false, 'error': 'Failed to analyze food'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> analyzeNutritionText(String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nutrition/describe'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'description': description}),
      );
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to analyze text description'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> analyzeNutritionLabel({String? imagePath}) async {
    try {
      if (imagePath != null) {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/nutrition/analyze-label'));
        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }
        final file = await http.MultipartFile.fromPath('image', imagePath);
        request.files.add(file);
        
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          return {'success': true, 'data': jsonDecode(response.body)};
        }
        return {'success': false, 'error': 'Failed to analyze nutrition label image'};
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/nutrition/analyze-label'),
          headers: {
            'Content-Type': 'application/json',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'mockImage': true}),
        );
        
        if (response.statusCode == 200) {
          return {'success': true, 'data': jsonDecode(response.body)};
        }
        return {'success': false, 'error': 'Failed to analyze nutrition label'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static bool get isAuthenticated => _token != null;
  static String? get token => _token;

  // --- User Profile Endpoints ---
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': jsonDecode(response.body)['error'] ?? 'Failed to load profile'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required int age,
    required double weight,
    required double height,
    required String goals,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'name': name,
          'age': age,
          'weight': weight,
          'height': height,
          'goals': goals,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': jsonDecode(response.body)['error'] ?? 'Failed to update profile'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfilePicture(String imagePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/user/profile/picture'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      final file = await http.MultipartFile.fromPath('image', imagePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {'success': true, 'url': decoded['url']};
      }
      return {'success': false, 'error': 'Failed to upload profile picture'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Meals Logging & Fetching ---
  static Future<Map<String, dynamic>> getMeals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meals'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve meals'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> logMeal({
    required String name,
    required int calories,
    int? protein,
    int? carbs,
    int? fats,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/meals'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'name': name,
          'calories': calories,
          'protein': protein ?? 0,
          'carbs': carbs ?? 0,
          'fats': fats ?? 0,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to save meal'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Workouts Logging & Fetching ---
  static Future<Map<String, dynamic>> getWorkouts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/workouts'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve workouts'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> saveWorkout({
    required String workoutName,
    double? distance,
    int? durationSeconds,
    int? calories,
    List<Map<String, double>>? routePoints,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/workouts'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'workout_name': workoutName,
          'distance': distance ?? 0.0,
          'duration_seconds': durationSeconds ?? 0,
          'calories': calories ?? 0,
          'route_points': routePoints ?? [],
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to save workout'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Daily Stats Sync (Steps & Water) ---
  static Future<Map<String, dynamic>> getDailyStats({String? date}) async {
    try {
      final dateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('$baseUrl/daily-stats?date=$dateStr'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to load stats'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateDailyStats({
    String? date,
    int? steps,
    int? waterMl,
  }) async {
    try {
      final dateStr = date ?? DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(
        Uri.parse('$baseUrl/daily-stats'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'date': dateStr,
          if (steps != null) 'steps': steps,
          if (waterMl != null) 'water_ml': waterMl,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to update stats'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Body Measurements Logging & Fetching ---
  static Future<Map<String, dynamic>> logMeasurement({
    required String metricType,
    required double value,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/measurements'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'metric_type': metricType,
          'value': value,
          if (date != null) 'date': date,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      try {
        final err = jsonDecode(response.body)['error'];
        return {'success': false, 'error': err ?? 'Failed to log measurement'};
      } catch (_) {
        return {'success': false, 'error': 'Failed to log measurement (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMeasurements({String? metricType}) async {
    try {
      final queryParam = metricType != null ? '?metric_type=$metricType' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/user/measurements$queryParam'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve measurements'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteMeasurement(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user/measurements/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to delete measurement'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- AI Barcode Lookup ---
  static Future<Map<String, dynamic>> scanBarcode(String barcode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nutrition/barcode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'barcode': barcode}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to recognize barcode'};
    } catch (e) {
      debugPrint('Sync Stats Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // AI Workout Insights
  static Future<Map<String, dynamic>> getWorkoutInsight() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/insights'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      debugPrint('Insights Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
