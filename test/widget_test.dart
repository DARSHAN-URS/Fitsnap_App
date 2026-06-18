import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabtrack_ai/main.dart';
import 'package:sabtrack_ai/auth_screen.dart';
import 'package:sabtrack_ai/screens/profile_tab.dart';

void main() {
  testWidgets('App renders AuthScreen by default when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SabtrackApp(
          isLoggedIn: false,
          onboardingCompleted: false,
        ),
      ),
    );

    // Wait for animations/loading
    await tester.pump();

    // Verify AuthScreen is loaded
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('ProfileTab renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProfileTab(),
          ),
        ),
      ),
    );

    // Wait for staggering animations
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify key UI elements render
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Active Days'), findsOneWidget);
    expect(find.text('Meals Scanned'), findsOneWidget);
    expect(find.text('Workout Reminder'), findsOneWidget);
  });
}
