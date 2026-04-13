import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  final _storage = const FlutterSecureStorage();
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
  ));

  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      _isAuthenticated = true;
      fetchProfile();
      notifyListeners();
    }
  }

  Future<void> fetchProfile() async {
    if (_token == null) return;
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      _user = response.data;
      notifyListeners();
    } catch (e) {
      print('Fetch Profile Error: $e');
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_token == null) return false;
    try {
      final response = await _dio.put(
        '/auth/profile',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      _user = response.data;
      notifyListeners();
      return true;
    } catch (e) {
      print('Update Profile Error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      // For demo, we simulate a successful login
      await Future.delayed(const Duration(seconds: 2));
      _token = "mock_jwt_token_for_demo";
      
      await _storage.write(key: 'auth_token', value: _token);
      
      _isAuthenticated = true;
      fetchProfile();
      notifyListeners();
      return true;
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      print('Register Error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }
}
