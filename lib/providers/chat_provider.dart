import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMsg> _messages = [];
  String? _authToken;
  bool _isLoading = false;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8000',
  ));

  List<ChatMsg> get messages => [..._messages];
  bool get isLoading => _isLoading;

  void updateToken(String? token) {
    _authToken = token;
    if (token != null) {
      fetchMessages();
    }
  }

  Future<void> fetchMessages() async {
    if (_authToken == null) return;
    try {
      final response = await _dio.get(
        '/chat/',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      final List<dynamic> data = response.data;
      _messages = data.map((m) => ChatMsg.fromJson(m)).toList();
      notifyListeners();
    } catch (e) {
      print('Fetch Chat Error: $e');
    }
  }

  Future<void> sendMessage(String content, {int? mealId}) async {
    if (_authToken == null || content.trim().isEmpty) return;

    // Optimistic UI update
    final tempMsg = ChatMsg(
      id: -1,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
      mealId: mealId,
    );
    _messages.add(tempMsg);
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.post(
        '/chat/',
        data: {'content': content, 'meal_id': mealId},
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );
      
      // Update with real response
      final aiMsg = ChatMsg.fromJson(response.data);
      _messages.removeLast(); // Remove temp user msg
      
      // Sync with full history from backend to ensure order and real IDs
      fetchMessages();
    } catch (e) {
      print('Send Chat Error: $e');
      _messages.removeLast();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
