import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meal_provider.dart';
import '../providers/step_provider.dart';
import '../providers/water_provider.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';
import 'profile_screen.dart';
import '../providers/suggestion_provider.dart';
import 'gallery_screen.dart';
import 'camera_screen.dart';
import 'friends_screen.dart';
import '../models/step.dart';
import '../models/meal.dart';
import 'ai_insights_screen.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);
    final stepProvider = Provider.of<StepProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    final mealStats = {
      'calories': mealProvider.getCaloriesForDate(_selectedDate),
      'protein': mealProvider.getProteinForDate(_selectedDate),
      'carbs': mealProvider.getCarbsForDate(_selectedDate),
      'fat': mealProvider.getFatForDate(_selectedDate),
    };

    final stepData = stepProvider.getStepsForDate(dateStr);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(fontSize: 22),
        actions: [
          _buildTopIcon(Icons.local_fire_department_rounded, '0'),
          IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: Color(0xFF3ABEF9), size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AIInsightsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await mealProvider.fetchMeals();
          await stepProvider.fetchTodaySteps();
          await Provider.of<WaterProvider>(context, listen: false).fetchTodayWater();
          await Provider.of<SuggestionProvider>(context, listen: false).fetchDailySuggestions();
        },
        color: const Color(0xFF3ABEF9),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateStrip(),
              const SizedBox(height: 10),
              SizedBox(
                height: 330,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildCaloriesSlide(mealStats, mealProvider.calorieGoal),
                    _buildNutrientGrid(mealStats),
                    _buildTopStatsRow(stepData, stepProvider.stepGoal),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index ? const Color(0xFF3ABEF9) : Colors.blueGrey[800],
                  ),
                )),
              ),
              const SizedBox(height: 24),
              _buildWatchAIInsightsButton(),
              const SizedBox(height: 30),
              _buildSectionHeader("Today's Meals"),
              const SizedBox(height: 12),
              _buildTodayMealsStack(mealProvider.meals.where((m) => 
                m.createdAt.year == _selectedDate.year &&
                m.createdAt.month == _selectedDate.month &&
                m.createdAt.day == _selectedDate.day).toList()),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaloriesSlide(Map<String, double> stats, double goal) {
    final consumed = stats['calories']!;
    final remaining = (goal - consumed).toInt();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF161F2C),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3ABEF9).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF3ABEF9)],
                  ).createShader(bounds),
                  child: Text(
                    remaining.toString(),
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                Text(
                  'calories remaining',
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroMini('Protein', '${stats['protein']!.toInt()}g', const Color(0xFF3ABEF9)),
                _buildMacroMini('Carbs', '${stats['carbs']!.toInt()}g', Colors.white70),
                _buildMacroMini('Fats', '${stats['fat']!.toInt()}g', Colors.white70),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMini(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopIcon(IconData icon, String? value) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orangeAccent),
          if (value != null) ...[
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final List<DateTime> dates = List.generate(7, (index) {
        return DateTime.now().add(Duration(days: index - 5));
    });

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3ABEF9).withOpacity(0.15) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF3ABEF9) : Colors.white10, 
                  width: isSelected ? 2 : 1
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected ? [
                  BoxShadow(color: const Color(0xFF3ABEF9).withOpacity(0.3), blurRadius: 8)
                ] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EE').format(date), 
                    style: TextStyle(color: isSelected ? const Color(0xFF3ABEF9) : Colors.blueGrey[400], fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  const SizedBox(height: 4),
                  Text(DateFormat('d').format(date), 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 20,
                      color: isSelected ? Colors.white : Colors.white70,
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStatsRow(StepData stepData, int stepGoal) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(Icons.directions_walk_rounded, '${stepData.stepCount}', 'Steps', color: const Color(0xFF3ABEF9))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(Icons.fitness_center_rounded, '0', 'Exercise', unit: 'cal', color: Colors.orangeAccent)),
        const SizedBox(width: 10),
        Expanded(
          child: Consumer<WaterProvider>(
            builder: (context, water, _) => _buildStatCard(Icons.local_drink_rounded, '${water.dailyAmount}', 'Water', unit: 'ml', color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, {String? unit, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? Colors.blueGrey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.blueGrey[400], size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (unit != null) Text(unit, style: TextStyle(color: Colors.blueGrey[400], fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildNutrientGrid(Map<String, double> stats) {
    final List<Map<String, dynamic>> nutrients = [
      {'label': 'Fiber', 'value': '0g', 'target': '28g', 'icon': Icons.eco_rounded},
      {'label': 'Sugar', 'value': '0g', 'target': '26g', 'icon': Icons.bubble_chart_rounded},
      {'label': 'Sodium', 'value': '0mg', 'target': '2300mg', 'icon': Icons.waves_rounded},
      {'label': 'Cholesterol', 'value': '0mg', 'target': '300mg', 'icon': Icons.favorite_rounded},
      {'label': 'Potassium', 'value': '0mg', 'target': '3400mg', 'icon': Icons.bolt_rounded},
      {'label': 'Saturates', 'value': '0g', 'target': '24g', 'icon': Icons.opacity_rounded},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: nutrients.length,
      itemBuilder: (context, index) {
        final n = nutrients[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161F2C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: 0,
                      strokeWidth: 3,
                      backgroundColor: Colors.blueGrey[900],
                      color: const Color(0xFF3ABEF9),
                    ),
                  ),
                  Icon(n['icon'], size: 18, color: Colors.blueGrey[600]),
                ],
              ),
              const SizedBox(height: 10),
              Text(n['target'], style: TextStyle(color: Colors.blueGrey[400], fontSize: 11, fontWeight: FontWeight.bold)),
              Text(n['label'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF3ABEF9),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildTodayMealsStack(List<Meal> meals) {
    if (meals.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fastfood_rounded, size: 48, color: Colors.blueGrey[800]),
            ),
            const SizedBox(height: 16),
            Text('Tap + to log a meal', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      children: meals.map((meal) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
          Hero(
            tag: meal.id ?? meal.hashCode,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  meal.imageUrl ?? 'https://images.unsplash.com/photo-1525351484163-7529414344d8',
                  width: 65,
                  height: 65,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 65, height: 65, color: Colors.blueGrey[900], child: const Icon(Icons.fastfood)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.foodName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (meal.status == 'processing' ? Colors.orange : const Color(0xFF3ABEF9)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      meal.status == 'processing' ? 'Analysing...' : '${meal.calories.toInt()} kcal', 
                      style: TextStyle(
                        color: meal.status == 'processing' ? Colors.orangeAccent : const Color(0xFF3ABEF9), 
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildWatchAIInsightsButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AIInsightsScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF161F2C), const Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3ABEF9).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3ABEF9).withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Watch AI Insights', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  SizedBox(height: 2),
                  Text('Get personalized health tips', style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueGrey, size: 16),
          ],
        ),
      ),
    );
  }

}
