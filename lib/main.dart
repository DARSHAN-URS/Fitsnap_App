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
import 'screens/more_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/meal_selection_screen.dart';
import 'screens/weight_screen.dart';
import 'widgets/exercise_modal.dart';
import 'widgets/water_modal.dart';

import 'providers/meal_provider.dart';
import 'providers/step_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/water_provider.dart';
import 'providers/suggestion_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/measurement_provider.dart';
import 'providers/medical_history_provider.dart';

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
        ChangeNotifierProxyProvider<AuthProvider, SuggestionProvider>(
          create: (_) => SuggestionProvider(),
          update: (_, auth, sug) => sug!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, WaterProvider>(
          create: (_) => WaterProvider(),
          update: (_, auth, water) => water!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProgressProvider>(
          create: (_) => ProgressProvider(),
          update: (_, auth, prog) => prog!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MeasurementProvider>(
          create: (_) => MeasurementProvider(),
          update: (_, auth, m) => m!..updateToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MedicalHistoryProvider>(
          create: (_) => MedicalHistoryProvider(),
          update: (_, auth, m) => m!..updateToken(auth.token),
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
      title: 'SabTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05080E), // Deeper Dark Navy
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3ABEF9), // SabTrack Blue
          brightness: Brightness.dark,
          primary: const Color(0xFF3ABEF9),
          secondary: Colors.white,
          surface: const Color(0xFF161F2C),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161F2C),
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
  bool _isMenuOpen = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const StepsScreen(), 
    const MoreScreen(),
  ];

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          if (_isMenuOpen)
            GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 85,
        padding: EdgeInsets.zero,
        notchMargin: 12,
        color: const Color(0xFF05080E),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, 'Home'),
            _buildNavItem(1, Icons.calendar_today_rounded, 'Diary'),
            const SizedBox(width: 60), // Space for FAB
            _buildNavItem(2, Icons.bar_chart_rounded, 'Charts'),
            _buildNavItem(3, Icons.more_horiz_rounded, 'More'),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMenuOpen) ...[
            _buildAddOption(Icons.restaurant_rounded, 'Food', const Color(0xFFFF5252), () {
              setState(() => _isMenuOpen = false);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MealSelectionScreen()));
            }),
            const SizedBox(height: 16),
            _buildAddOption(Icons.local_fire_department_rounded, 'Exercise', const Color(0xFFFFAB40), () {
              setState(() => _isMenuOpen = false);
              ExerciseModal.show(context);
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAddOption(Icons.local_drink_rounded, 'Water', const Color(0xFF40C4FF), () {
                  setState(() => _isMenuOpen = false);
                  WaterModal.show(context);
                }),
                const SizedBox(width: 20),
                _buildAddOption(Icons.monitor_weight_rounded, 'Weight', const Color(0xFF69F0AE), () {
                  setState(() => _isMenuOpen = false);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WeightScreen()));
                }),
              ],
            ),
            const SizedBox(height: 16),
            _buildAddOption(Icons.description, 'Describe', const Color(0xFFE0E0E0), () {
              setState(() => _isMenuOpen = false);
              _showComingSoon(context, 'Manual Description');
            }),
            const SizedBox(height: 20),
          ],
          SizedBox(
            height: 70,
            width: 70,
            child: FloatingActionButton(
              onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
              backgroundColor: _isMenuOpen ? Colors.white : const Color(0xFF3ABEF9),
              shape: const CircleBorder(),
              elevation: 10,
              child: Icon(
                _isMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                color: _isMenuOpen ? Colors.black : Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.blueGrey[600],
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.blueGrey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

