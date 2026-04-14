import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meal_provider.dart';
import '../providers/step_provider.dart';
import '../providers/water_provider.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'gallery_screen.dart';
import '../models/step.dart';
import '../models/meal.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

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
        title: const Text(
          'FitSnap AI',
          style: TextStyle(
            color: Color(0xFFFF5E3A),
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await mealProvider.fetchMeals();
          await stepProvider.fetchTodaySteps();
          await Provider.of<WaterProvider>(context, listen: false).fetchTodayWater();
        },
        color: const Color(0xFFFF5E3A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
            _buildDateStrip(),
            const SizedBox(height: 20),
            _buildMainCalorieCard(mealStats, mealProvider.calorieGoal),
            const SizedBox(height: 20),
            _buildStepsCard(stepData, stepProvider.stepGoal),
            const SizedBox(height: 20),
            Consumer<WaterProvider>(
              builder: (context, waterProvider, _) => _buildWaterCard(waterProvider),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader("Today's Meals"),
            const SizedBox(height: 12),
            _buildTodayMealsStack(mealProvider.meals.where((m) => 
              m.createdAt.year == _selectedDate.year &&
              m.createdAt.month == _selectedDate.month &&
              m.createdAt.day == _selectedDate.day).toList()),
            const SizedBox(height: 30),
            _buildQuickActions(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTopIcon(IconData icon, String? value) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFFB053)),
          if (value != null) ...[
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    // Generate 7 days with Today at the center (index 3)
    final List<DateTime> dates = List.generate(7, (index) {
        return DateTime.now().add(Duration(days: index - 3));
    });

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: isSelected ? BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(16),
                color: Colors.blueAccent.withOpacity(0.1),
              ) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EE').format(date), 
                    style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey[400], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(DateFormat('d').format(date), 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      color: isSelected ? Colors.white : Colors.white,
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCalorieCard(Map<String, double> stats, double goal) {
    final consumed = stats['calories']!;
    final remaining = (goal - consumed).toInt();
    final progress = (consumed / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          CustomPaint(
            size: const Size(200, 110),
            painter: ArcPainter(progressVal: progress),
            child: SizedBox(
              width: 200,
              height: 110,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    remaining.toString(),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'calories remaining',
                    style: TextStyle(color: Colors.blueGrey[300], fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroMini('Protein', '${stats['protein']!.toInt()}g'),
              _buildMacroMini('Carbs', '${stats['carbs']!.toInt()}g'),
              _buildMacroMini('Fats', '${stats['fat']!.toInt()}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMini(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Container(width: 40, height: 3, color: Colors.blueGrey[700]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildStepsCard(StepData data, int goal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk_rounded, color: Colors.greenAccent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Steps Today', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                Text('${data.stepCount} / $goal', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(
                  value: (data.stepCount / goal).clamp(0.0, 1.0),
                  backgroundColor: Colors.blueGrey[800],
                  valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                  strokeWidth: 5,
                ),
              ),
              if (data.stepCount >= goal)
                const Icon(Icons.check, size: 16, color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTodayMealsStack(List<Meal> meals) {
    if (meals.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF141D2C),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_rounded, size: 48, color: Colors.blueGrey[800]),
            const SizedBox(height: 16),
            Text('Tap + to log a meal', style: TextStyle(color: Colors.blueGrey[400])),
          ],
        ),
      );
    }

    return Column(
      children: meals.map((meal) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                meal.imageUrl ?? 'https://images.unsplash.com/photo-1525351484163-7529414344d8',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.blueGrey, child: const Icon(Icons.fastfood)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.foodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(meal.status == 'processing' ? 'Analysing...' : '${meal.calories.toInt()} kcal', 
                    style: TextStyle(color: meal.status == 'processing' ? Colors.orangeAccent : Colors.blueGrey[400], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.blueGrey),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraScreen())),
                child: _buildActionBtn(Icons.restaurant_menu_rounded, 'Food', const Color(0xFFFF5E3A)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exercise logging coming soon!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: _buildActionBtn(Icons.local_fire_department, 'Exercise', Colors.orange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Consumer<WaterProvider>(
                builder: (context, waterProvider, _) => GestureDetector(
                  onTap: () => waterProvider.addWater(250),
                  child: _buildActionBtn(Icons.water_drop_rounded, 'Water', Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GalleryScreen())),
                child: _buildActionBtn(Icons.photo_library_rounded, 'Gallery', Colors.green),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWaterCard(WaterProvider waterProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hydration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Daily Target: 3L', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(waterProvider.progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: waterProvider.progress,
                      backgroundColor: const Color(0xFF0F172A),
                      color: Colors.blueAccent,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${waterProvider.dailyAmount}ml / ${waterProvider.targetAmount}ml',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => waterProvider.addWater(250),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ArcPainter extends CustomPainter {
  final double progressVal;
  ArcPainter({required this.progressVal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    canvas.drawArc(rect, math.pi, math.pi, false, paint);

    paint.color = const Color(0xFFFF5E3A); // Sunset Orange arc
    canvas.drawArc(rect, math.pi, math.pi * progressVal, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
