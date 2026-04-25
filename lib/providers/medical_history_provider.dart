import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/medical_history.dart';

class MedicalHistoryProvider with ChangeNotifier {
  MedicalHistory? _history;
  String? _authToken;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: (dotenv.env['API_URL'] ?? 'http://localhost:8000').endsWith('/') 
        ? (dotenv.env['API_URL'] ?? 'http://localhost:8000') 
        : '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/',
  ));

  MedicalHistory? get history => _history;

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchMedicalHistory();
    }
  }

  Future<void> fetchMedicalHistory() async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        'medical-history/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      _history = MedicalHistory.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      print('Fetch Medical History Error: $e');
    }
  }

  Future<bool> updateMedicalHistory(MedicalHistory history) async {
    if (_authToken == null) return false;
    try {
      final response = await _dio.post(
        'medical-history/',
        data: history.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _history = MedicalHistory.fromJson(response.data);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Update Medical History Error: $e');
      return false;
    }
  }
}
