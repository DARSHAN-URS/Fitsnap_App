import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/progress_photo.dart';
import 'dart:io';

class ProgressProvider with ChangeNotifier {
  List<ProgressImg> _photos = [];
  String? _authToken;
  bool _isLoading = false;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
  ));

  List<ProgressImg> get photos => [..._photos];
  bool get isLoading => _isLoading;

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchPhotos();
    }
  }

  Future<void> fetchPhotos() async {
    if (_authToken == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _dio.get(
        '/progress/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final List<dynamic> data = response.data;
      _photos = data.map((p) => ProgressImg.fromJson(p)).toList();
    } catch (e) {
      print('Fetch Progress Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadPhoto(File imageFile, {double? weight, String? description}) async {
    if (_authToken == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path, filename: fileName),
        if (weight != null) 'weight': weight,
        if (description != null) 'description': description,
      });

      await _dio.post(
        '/progress/',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      
      await fetchPhotos(); // Refresh list
      return true;
    } catch (e) {
      print('Upload Progress Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
