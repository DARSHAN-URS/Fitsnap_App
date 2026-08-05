import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

// Simple auth state model
class AuthState {
  final bool isLoading;
  final bool success;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.success = false,
    this.errorMessage,
  });

  AuthState copyWith({bool? isLoading, bool? success, String? errorMessage}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// StateNotifier that handles authentication logic
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState());

  // Authenticate either login or signup based on isLogin flag
  Future<void> authenticate({required String email, required String password, required bool isLogin}) async {
    // set loading
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);
    try {
      final result = isLogin
          ? await ApiService.login(email, password)
          : await ApiService.signup(email, password);

      if (result['success'] == true) {
        // store token securely if provided
        final token = result['data']?['token'] ?? result['data']?['data']?['token'];
        if (token != null) {
          ApiService.setToken(token as String);
        }
        state = state.copyWith(isLoading: false, success: true);
      } else {
        state = state.copyWith(isLoading: false, success: false, errorMessage: result['error'] ?? 'Authentication failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, success: false, errorMessage: e.toString());
    }
  }

  // Google login flow
  Future<void> authenticateWithGoogle(
    String idToken, {
    String? displayName,
    String? photoUrl,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);
    try {
      final result = await ApiService.googleLogin(
        idToken,
        displayName: displayName,
        photoUrl: photoUrl,
        email: email,
      );
      if (result['success'] == true) {
        final token = result['data']?['token'] ?? result['data']?['data']?['token'];
        final refreshToken = result['data']?['refresh_token'] ?? result['data']?['data']?['refresh_token'];
        if (token != null) {
          ApiService.setToken(token as String);
        }
        if (refreshToken != null) {
          ApiService.setRefreshToken(refreshToken as String);
        }
        state = state.copyWith(isLoading: false, success: true);
      } else {
        state = state.copyWith(isLoading: false, success: false, errorMessage: result['error'] ?? 'Google authentication failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, success: false, errorMessage: e.toString());
    }
  }

  // Helper to read token when needed
  Future<String?> getToken() async => await _secureStorage.read(key: 'auth_token');
}

// Provider expose the notifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
