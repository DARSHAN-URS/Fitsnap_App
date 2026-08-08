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
  static const String productionUrl = 'https://api.sabtrack.in/api';
  static String baseUrl = productionUrl; // Default to Railway live backend
  static String? _token;
  static String? _refreshToken;
  static bool _isRefreshing = false;

  // Always use live production Railway backend
  static void configureBaseUrl({required bool isDevelopment}) {
    baseUrl = productionUrl;
  }

  // Initialize both JWT access token and refresh token from storage on startup.
  // If the stored access token is expired (or expires within 5 min), silently
  // refreshes it using the stored refresh token so the first API call succeeds.
  static Future<void> initToken() async {
    try {
      _token = await PreferencesHelper.readString('auth_token');
      _refreshToken = await PreferencesHelper.readString('auth_refresh_token');

      // Proactively refresh if token is expired or about to expire (within 5 min)
      if (_token != null && _refreshToken != null) {
        final payload = _decodeJwtPayload(_token!);
        final exp = payload['exp'];
        final nowPlusFiveMin = (DateTime.now().millisecondsSinceEpoch / 1000) + 300;
        if (exp != null && exp < nowPlusFiveMin) {
          debugPrint('initToken: access token expired/expiring soon, refreshing...');
          await _refreshAccessToken();
        }
      }
    } catch (e) {
      debugPrint('Error initializing auth token: $e');
    }
  }

  // Decode JWT payload without signature verification (reuse logic from backend)
  static Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final padded = parts[1] + '=' * (-parts[1].length % 4);
        final decoded = utf8.decode(base64Url.decode(padded));
        return jsonDecode(decoded) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Extract the user's ID from the current JWT token (sub field)
  static Future<String?> getCurrentUserId() async {
    final payload = _decodeJwtPayload(_token ?? '');
    final id = payload['sub'] ?? payload['user_id'] ?? payload['id'];
    return id?.toString();
  }

  // Set the JWT access token after login
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

  // Set the refresh token after login
  static void setRefreshToken(String token) {
    _refreshToken = token.isEmpty ? null : token;
    if (token.isNotEmpty) {
      PreferencesHelper.saveString('auth_refresh_token', token).catchError((e) {
        debugPrint('Error saving refresh token: $e');
      });
    }
  }

  // Attempt to silently refresh the access token using the stored refresh token.
  // Returns true if successful.
  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null || _isRefreshing) return false;
    _isRefreshing = true;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newToken != null) setToken(newToken);
        if (newRefresh != null) setRefreshToken(newRefresh);
        _isRefreshing = false;
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }
    _isRefreshing = false;
    return false;
  }

  // Authenticated GET with automatic 401 token refresh
  static Future<http.Response> _authGet(String url) async {
    var response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $_token'},
        );
      }
    }
    return response;
  }

  // Authenticated POST with automatic 401 token refresh
  static Future<http.Response> _authPost(String url, {Object? body}) async {
    var response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.post(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  // Authenticated PUT with automatic 401 token refresh
  static Future<http.Response> _authPut(String url, {Object? body}) async {
    var response = await http.put(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.put(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  // Authenticated DELETE with automatic 401 token refresh
  static Future<http.Response> _authDelete(String url) async {
    var response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.delete(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $_token'},
        );
      }
    }
    return response;
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
        final token = data['token'] ?? data['data']?['token'];
        final refreshToken = data['refresh_token'] ?? data['data']?['refresh_token'];
        if (token != null) setToken(token);
        if (refreshToken != null) setRefreshToken(refreshToken);
        return {'success': true, 'data': data};
      }
      try {
        final data = jsonDecode(response.body);
        final errorMsg = data['detail'] ?? data['error'] ?? data['message'] ?? 'Invalid credentials';
        return {'success': false, 'error': errorMsg};
      } catch (_) {
        return {'success': false, 'error': 'Invalid credentials (Status: ${response.statusCode})'};
      }
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
        final token = data['token'] ?? data['data']?['token'];
        final refreshToken = data['refresh_token'] ?? data['data']?['refresh_token'];
        if (token != null) setToken(token);
        if (refreshToken != null) setRefreshToken(refreshToken);
        return {'success': true, 'data': data};
      }
      try {
        final data = jsonDecode(response.body);
        final errorMsg = data['detail'] ?? data['error'] ?? data['message'] ?? 'Signup failed';
        return {'success': false, 'error': errorMsg};
      } catch (_) {
        return {'success': false, 'error': 'Signup failed (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> googleLogin(
    String idToken, {
    String? displayName,
    String? photoUrl,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          if (displayName != null) 'displayName': displayName,
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (email != null) 'email': email,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['data']?['token'];
        final refreshToken = data['refresh_token'] ?? data['data']?['refresh_token'];
        if (token != null) setToken(token);
        if (refreshToken != null) setRefreshToken(refreshToken);
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
  static Future<Map<String, dynamic>> analyzeNutrition({String? imagePath, String? date, String? description}) async {
    try {
      if (imagePath == null) {
        return {'success': false, 'error': 'Image path is required for analysis.'};
      }
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/nutrition/analyze'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      final file = await http.MultipartFile.fromPath('image', imagePath);
      request.files.add(file);
      if (date != null) {
        request.fields['date'] = date;
      }
      if (description != null) {
        request.fields['description'] = description;
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to analyze food image'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> analyzeNutritionText(String description, {String? date}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nutrition/analyze-text'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'description': description,
          if (date != null) 'date': date,
        }),
      );
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      String errorMsg = 'Failed to analyze text description';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMsg = decoded['detail'];
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> analyzeNutritionLabel({String? imagePath, String? date, String? description}) async {
    try {
      if (imagePath == null) {
        return {'success': false, 'error': 'Image path is required for analysis.'};
      }
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/nutrition/analyze-label'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      final file = await http.MultipartFile.fromPath('image', imagePath);
      request.files.add(file);
      if (date != null) {
        request.fields['date'] = date;
      }
      if (description != null) {
        request.fields['description'] = description;
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to analyze nutrition label image'};
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
    String? username,
    String? gender,
    String? activityLevel,
    double? targetWeight,
    String? goal,
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
          if (username != null) 'username': username,
          if (gender != null) 'gender': gender,
          if (activityLevel != null) 'activity_level': activityLevel,
          if (targetWeight != null) 'target_weight': targetWeight,
          if (goal != null) 'goal': goal,
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

  static Future<Map<String, dynamic>> getProfileHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile/history'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to load weight history'};
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

  static Future<Map<String, dynamic>> getMeals({String? date}) async {
    try {
      final queryParam = date != null ? '?date=$date' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/meals$queryParam'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final data = responseBody['data'];
        if (data is Map && data['meals'] is List) {
          // Backend returned a full nutrition summary with embedded meals list
          return {
            'success': true,
            'data': data['meals'],
            'summary': data,
          };
        } else if (data is List) {
          return {'success': true, 'data': data};
        }
        return {'success': true, 'data': []};
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
    String? date,
    String? description,
    String? imageUrl,
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
          if (date != null) 'date': date,
          if (description != null) 'description': description,
          if (imageUrl != null) 'image_url': imageUrl,
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

  static Future<Map<String, dynamic>> saveStrengthWorkout({
    required String workoutName,
    required String category,
    required List<Map<String, dynamic>> exercises,
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
          'workout_type': 'strength',
          'category': category,
          'exercises': exercises,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to save strength workout'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteWorkout(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/workouts/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to delete workout'};
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

  // --- Fasting ---
  static Future<Map<String, dynamic>> getActiveFast() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fasting/active'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to retrieve active fast'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> startFast(String protocol) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fasting/start'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'protocol': protocol}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to start fast'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> stopFast(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fasting/stop'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to stop fast'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getFastingHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fasting/history'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve fasting history'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Leaderboard ---
  static Future<Map<String, dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leaderboard'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve leaderboard'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Groups ---
  static Future<Map<String, dynamic>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve groups'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createGroup(String name, String description, {bool isPublic = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'is_public': isPublic,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to create group'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getGroupMembers(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/members'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'data': []};
    } catch (e) {
      return {'success': false, 'data': []};
    }
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'data': []};
    } catch (e) {
      return {'success': false, 'data': []};
    }
  }

  static Future<void> markNotificationRead(String notifId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/$notifId/read'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> joinGroup(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      String errorMsg = 'Failed to join group';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMsg = decoded['detail'];
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/leave'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      String errorMsg = 'Failed to leave group';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMsg = decoded['detail'];
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Group Messages ---
  static Future<Map<String, dynamic>> getGroupMessages(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/messages'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve messages'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendGroupMessage(String groupId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/messages'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to send message'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Friends ---
  static Future<Map<String, dynamic>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve friends'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/search?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to search users'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getFriendSuggestions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/suggestions'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve friend suggestions'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addFriend(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/add'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      String errorMsg = 'Failed to add friend';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMsg = decoded['detail'];
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Challenges ---
  static Future<Map<String, dynamic>> getChallenges() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve challenges'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserChallenges() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/user'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve user challenges'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> joinChallenge(String challengeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/join'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to join challenge'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateChallengeProgress(String challengeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/progress'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to update challenge progress'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDailyReport(String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/insights/daily?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to retrieve daily report'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Step Tracking Endpoints ---
  static Future<Map<String, dynamic>> syncSteps(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/steps/sync'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to sync steps (Status: ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDailySteps(String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/steps/daily?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to retrieve daily steps'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getStepsHistory(int days) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/steps/history?days=$days'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve steps history'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Supplements ---
  static Future<Map<String, dynamic>> getSupplements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/supplements'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to retrieve supplements (Status: ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addSupplement({
    required String name,
    required String dosage,
    required String time,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/supplements'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'name': name,
          'dosage': dosage.isEmpty ? null : dosage,
          'time': time,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to add supplement (Status: ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteSupplement(String supplementId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/supplements/$supplementId'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Supplement deleted'};
      }
      return {'success': false, 'error': 'Failed to delete supplement'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Referrals ---
  static Future<Map<String, dynamic>> getReferralInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/referrals'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to retrieve referral details (Status: ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> claimReferralCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/referrals/claim'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'code': code}),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': responseData['message'] ?? 'Claimed successfully!'};
      }
      return {
        'success': false,
        'error': responseData['detail'] ?? 'Failed to claim referral code (Status: ${response.statusCode})'
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Support Desk ---
  static Future<Map<String, dynamic>> submitSupportTicket({
    required String email,
    required String category,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support/tickets'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'email': email,
          'category': category,
          'message': message,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to submit ticket (Status: ${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Badges ---
  static Future<Map<String, dynamic>> getUserBadges() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/badges'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve badges'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> awardBadge(String badgeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/badges'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'badge_id': badgeId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to award badge'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Nutrition Goals ---
  static Future<Map<String, dynamic>> getNutritionGoals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/nutrition-goals'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to retrieve nutrition goals'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateNutritionGoals({
    required double calorieGoal,
    required double proteinGoal,
    required double carbsGoal,
    required double fatsGoal,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/nutrition-goals'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'calorie_goal': calorieGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fats_goal': fatsGoal,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to update nutrition goals'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Supplement Take Logging ---
  static Future<Map<String, dynamic>> logSupplementTaken(String supplementId, String date) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/supplements/$supplementId/log?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to log supplement taken'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSupplementLogs(String date) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/supplements/logs?date=$date'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve supplement logs'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Group Invites ---
  static Future<Map<String, dynamic>> inviteToGroup(String groupId, String inviteeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/invite?invitee_id=$inviteeId'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to send group invite'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getGroupInvites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/invites'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to retrieve group invites'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> acceptGroupInvite(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/accept-invite'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to accept invite'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Forgot Password ---
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to send reset email'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Direct Messages ---
  static Future<Map<String, dynamic>> getDmMessages(String friendId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dm/$friendId'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to load messages'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendDm(String friendId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dm/$friendId'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      return {'success': false, 'error': 'Failed to send message'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Challenge Invite ---
  static Future<Map<String, dynamic>> inviteFriendToChallenge(String friendId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/invite/$friendId'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to send challenge invite'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // --- Friend Requests ---
  static Future<Map<String, dynamic>> getPendingFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests/pending'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body)['data'] ?? [];
        return {'success': true, 'data': list};
      }
      return {'success': false, 'error': 'Failed to fetch friend requests'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/requests/$requestId/accept'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'error': err['detail'] ?? 'Failed to accept request'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> declineFriendRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/requests/$requestId/decline'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)['data']};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'error': err['detail'] ?? 'Failed to decline request'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}






