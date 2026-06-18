import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'utils/preferences_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.configureBaseUrl(isDevelopment: kDebugMode);
  await ApiService.initToken();
  await NotificationService.initialize();

  final bool onboardingCompleted = await PreferencesHelper.readBool('onboarding_completed') ?? false;
  final bool isLoggedIn = ApiService.isAuthenticated;

  runApp(
    ProviderScope(
      child: SabtrackApp(
        isLoggedIn: isLoggedIn,
        onboardingCompleted: onboardingCompleted,
      ),
    ),
  );
}

class SabtrackApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool onboardingCompleted;

  const SabtrackApp({
    super.key,
    required this.isLoggedIn,
    required this.onboardingCompleted,
  });

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (isLoggedIn) {
      homeScreen = onboardingCompleted ? const DashboardScreen() : const OnboardingScreen();
    } else {
      homeScreen = const AuthScreen();
    }

    return MaterialApp(
      title: 'SABTRACK AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: homeScreen,
    );
  }
}

