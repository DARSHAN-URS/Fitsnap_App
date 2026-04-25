import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/measurement.dart';

class MeasurementProvider with ChangeNotifier {
  List<Measurement> _measurements = [];
  String? _authToken;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: (dotenv.env['API_URL'] ?? 'http://localhost:8000').endsWith('/') 
        ? (dotenv.env['API_URL'] ?? 'http://localhost:8000') 
        : '${dotenv.env['API_URL'] ?? 'http://localhost:8000'}/',
  ));

  List<Measurement> get measurements => [..._measurements];

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchMeasurements();
    }
  }

  Future<void> fetchMeasurements() async {
    if (_authToken == null) {
      _loadMockData();
      return;
    }
    try {
      final response = await _dio.get(
        'measurements/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final List<dynamic> data = response.data;
      _measurements = data.map((item) => Measurement.fromJson(item)).toList();
      notifyListeners();
    } catch (e) {
      print('Fetch Measurements Error: $e');
      _loadMockData(); // Fallback to mock data if API fails
    }
  }

  void _loadMockData() {
    final now = DateTime.now();
    _measurements = List.generate(5, (i) {
      return Measurement(
        id: i,
        chest: 100.0 + i * 0.5,
        waist: 85.0 - i * 0.3,
        hips: 95.0 + i * 0.2,
        neck: 38.0,
        shoulders: 110.0 + i * 0.4,
        leftBicep: 35.0 + i * 0.1,
        rightBicep: 35.1 + i * 0.1,
        createdAt: now.subtract(Duration(days: (4 - i) * 7)),
      );
    });
    notifyListeners();
  }

  Future<bool> addMeasurement(Measurement measurement) async {
    if (_authToken == null) {
      _measurements.add(measurement);
      notifyListeners();
      return true;
    }
    try {
      final response = await _dio.post(
        'measurements/',
        data: measurement.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _measurements.add(Measurement.fromJson(response.data));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Add Measurement Error: $e');
      return false;
    }
  }
}
