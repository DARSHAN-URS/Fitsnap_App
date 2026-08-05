import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'utils/preferences_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.configureBaseUrl(isDevelopment: false);

  try {
    await ApiService.initToken();
  } catch (e) {
    debugPrint('Error initializing ApiService token: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Error initializing NotificationService: $e');
  }

  bool onboardingCompleted = false;
  try {
    onboardingCompleted = await PreferencesHelper.readBool('onboarding_completed') ?? false;
  } catch (e) {
    debugPrint('Error reading onboarding_completed status: $e');
  }

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
    // Resolve the real destination based on auth + onboarding state
    final Widget destinationScreen;
    if (isLoggedIn) {
      destinationScreen = onboardingCompleted
          ? const DashboardScreen()
          : const OnboardingScreen();
    } else {
      destinationScreen = const AuthScreen();
    }

    return MaterialApp(
      title: 'SABTRACK AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // Always start with the animated splash — it routes to the correct screen
      home: SplashScreen(nextScreen: destinationScreen),
    );
  }
}
