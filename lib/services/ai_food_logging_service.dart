import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AiFoodLoggingService {
  /// Sends meal photo to backend AI analysis endpoint
  static Future<Map<String, dynamic>> analyzeMeal(String imagePath) async {
    try {
      final token = ApiService.token;
      final uri = Uri.parse('${ApiService.baseUrl}/meal/analyze');
      
      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add image file
      final file = await http.MultipartFile.fromPath(
        'image',
        imagePath,
      );
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {'success': false, 'error': errorBody['detail'] ?? 'AI failed to analyze image.'};
        } catch (_) {
          return {'success': false, 'error': 'Failed with status code: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Saves reviewed meal + list of sub items
  static Future<Map<String, dynamic>> saveMeal(Map<String, dynamic> mealPayload) async {
    try {
      final token = ApiService.token;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/meal/save'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(mealPayload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        try {
          final err = jsonDecode(response.body);
          return {'success': false, 'error': err['detail'] ?? 'Failed to save meal'};
        } catch (_) {
          return {'success': false, 'error': 'Failed with status code: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch user meal logging history
  static Future<Map<String, dynamic>> getMealHistory({int page = 1}) async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/meal/history?page=$page&limit=20'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load history'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get daily summary of calories/macros
  static Future<Map<String, dynamic>> getDailyNutrition({String? date}) async {
    try {
      final token = ApiService.token;
      final query = date != null ? '?date=$date' : '';
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nutrition/daily$query'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load daily stats'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get weekly combined nutrition averages
  static Future<Map<String, dynamic>> getWeeklyNutrition() async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nutrition/weekly'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to load weekly totals'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Searches the food database catalog
  static Future<Map<String, dynamic>> searchFoods(String query) async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/foods/search?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to search foods'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches recent food items logged by the user
  static Future<Map<String, dynamic>> getRecentFoods() async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/foods/recent'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to fetch recent foods'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches favorite foods list
  static Future<Map<String, dynamic>> getFavoriteFoods() async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/foods/favorites'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to fetch favorites'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Adds a food to favorites
  static Future<Map<String, dynamic>> addFavoriteFood(Map<String, dynamic> foodData) async {
    try {
      final token = ApiService.token;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/foods/favorites'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(foodData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to add favorite'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Removes a food from favorites
  static Future<Map<String, dynamic>> removeFavoriteFood(String foodName) async {
    try {
      final token = ApiService.token;
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/foods/favorites/${Uri.encodeComponent(foodName)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to remove favorite'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Resolves nutrition metrics by scanning barcode
  static Future<Map<String, dynamic>> scanBarcode(String barcode) async {
    try {
      final token = ApiService.token;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/foods/barcode'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'barcode': barcode}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to scan barcode'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Saves a user meal template
  static Future<Map<String, dynamic>> saveTemplate(String templateName, List<Map<String, dynamic>> foods) async {
    try {
      final token = ApiService.token;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/meal/template'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'template_name': templateName,
          'foods': foods,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to save template'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Retrieves user meal templates
  static Future<Map<String, dynamic>> getTemplates() async {
    try {
      final token = ApiService.token;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/meal/templates'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to retrieve templates'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
