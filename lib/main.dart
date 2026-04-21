import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/steps_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chat_screen.dart';

import 'providers/meal_provider.dart';
import 'providers/step_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/water_provider.dart';
import 'providers/progress_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MealProvider>(
          create: (_) => MealProvider(),
          update: (_, auth, meal) => meal!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, StepProvider>(
          create: (_) => StepProvider(),
          update: (_, auth, step) => step!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, WaterProvider>(
          create: (_) => WaterProvider(),
          update: (_, auth, water) => water!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
          create: (_) => ProgressProvider(),
          update: (_, auth, prog) => prog!..updateToken(auth.token),
        ),
      ],
      child: const FitSnapApp(),
    ),
  );
}

class FitSnapApp extends StatelessWidget {
  const FitSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitSnap AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Deep Navy
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5E3A), // Sunset Orange
          brightness: Brightness.dark,
          primary: const Color(0xFFFF5E3A),
          surface: const Color(0xFF1E293B),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return authProvider.isAuthenticated 
              ? const MainNavigation() 
              : const LoginScreen();
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const StepsScreen(),
    const ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 80,
        padding: EdgeInsets.zero,
        notchMargin: 12,
        color: const Color(0xFF0F172A),
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, 'Home'),
            _buildNavItem(1, Icons.calendar_today_rounded, 'Diary'),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(2, Icons.bar_chart_rounded, 'Charts'),
            _buildNavItem(3, Icons.psychology_rounded, 'Advisor'),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 20),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          ),
          backgroundColor: const Color(0xFFFF5E3A),
          shape: const CircleBorder(),
          elevation: 8,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.blueGrey[400],
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.blueGrey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
