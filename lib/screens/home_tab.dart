import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'activity_tracker_screen.dart';

class HomeTab extends StatefulWidget {
  final int consumed;
  final int protein;
  final int carbs;
  final int fats;
  final List<Map<String, dynamic>> meals;

  const HomeTab({
    super.key,
    required this.consumed,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.meals,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _steps = 6420;
  int _water = 1250; // ml
  final int _stepGoal = 10000;
  final int _waterGoal = 2500; // ml

  // Dynamic calorie burn based on step count
  int get _burnedCalories => 200 + (_steps * 0.04).toInt();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _steps = prefs.getInt('home_steps') ?? 6420;
      _water = prefs.getInt('home_water') ?? 1250;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('home_steps', _steps);
    await prefs.setInt('home_water', _water);

    if (ApiService.isAuthenticated) {
      final res = await ApiService.updateDailyStats(steps: _steps, waterMl: _water);
      if (!res['success']) {
        debugPrint('Failed to sync daily stats: ${res['error']}');
      }
    }
  }

  IconData _getMealIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('toast') || lower.contains('egg')) {
      return Icons.breakfast_dining_rounded;
    } else if (lower.contains('salmon') || lower.contains('fish') || lower.contains('rice') || lower.contains('lunch') || lower.contains('chicken')) {
      return Icons.lunch_dining_rounded;
    } else if (lower.contains('bar') || lower.contains('yogurt') || lower.contains('snack')) {
      return Icons.cookie_rounded;
    }
    return Icons.restaurant_rounded;
  }

  Color _getMealIconColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('toast') || lower.contains('egg')) {
      return Colors.amber;
    } else if (lower.contains('salmon') || lower.contains('fish') || lower.contains('rice') || lower.contains('lunch') || lower.contains('chicken')) {
      return Colors.orange;
    } else if (lower.contains('bar') || lower.contains('yogurt') || lower.contains('snack')) {
      return Colors.pink;
    }
    return AppTheme.accent;
  }

  void _addSteps() {
    setState(() {
      _steps += 1000;
    });
    _saveStats();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logged 1,000 steps! Active energy updated.'),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _addWater() {
    setState(() {
      _water = (_water + 250).clamp(0, 5000);
    });
    _saveStats();
  }

  void _removeWater() {
    setState(() {
      _water = (_water - 250).clamp(0, 5000);
    });
    _saveStats();
  }

  @override
  Widget build(BuildContext context) {
    final int proteinLeft = (170 - widget.protein).clamp(0, 170);
    final double proteinProgress = (widget.protein / 170.0).clamp(0.0, 1.0);

    final int carbsLeft = (350 - widget.carbs).clamp(0, 350);
    final double carbsProgress = (widget.carbs / 350.0).clamp(0.0, 1.0);

    final int fatsLeft = (80 - widget.fats).clamp(0, 80);
    final double fatsProgress = (widget.fats / 80.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning,',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Darshan Urs 👋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Streak Widget
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppTheme.neonPink, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '7 days',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Notification Bell
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: AppTheme.primary, size: 22),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Calendar Strip
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildDate('Sat', '30', false),
                _buildDate('Sun', '31', false),
                _buildDate('Mon', '01', false),
                _buildDate('Tue', '02', false),
                _buildDate('Wed', '03', false),
                _buildDate('Thu', '04', true),
                _buildDate('Fri', '05', false),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Calorie Gauge Card (dynamically linked to local state _burnedCalories)
          CalorieRadialGauge(consumed: widget.consumed, goal: 2000, burned: _burnedCalories),
          const SizedBox(height: 20),

          // Macros Row
          Row(
            children: [
              Expanded(child: _buildMacroCard('${proteinLeft}g', 'Protein left', proteinProgress, AppTheme.proteinColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildMacroCard('${carbsLeft}g', 'Carbs left', carbsProgress, AppTheme.carbsColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildMacroCard('${fatsLeft}g', 'Fats left', fatsProgress, AppTheme.fatsColor)),
            ],
          ),
          const SizedBox(height: 24),

          // Combined Section: Activity & Hydration
          _buildActivityHydrationSection(),
          const SizedBox(height: 28),

          // Recently Uploaded Food Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently uploaded',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Food feed list items
          if (widget.meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No meals logged today yet.',
                  style: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
                ),
              ),
            )
          else
            ...widget.meals.reversed.map((meal) {
              return _buildMealItem(
                title: meal['name'] ?? 'Analyzed Food',
                subtitle: 'P: ${meal['protein']}g • C: ${meal['carbs']}g • F: ${meal['fats']}g',
                calories: '${meal['calories']}',
                time: meal['time'] ?? 'Just now',
                icon: _getMealIcon(meal['name'] ?? ''),
                iconBg: _getMealIconColor(meal['name'] ?? ''),
                tagText: meal['tag'] ?? (meal['protein'] != null && meal['protein'] > 25 ? 'High Protein' : 'Healthy Choice'),
                tagColor: meal['tagColor'] ?? (meal['protein'] != null && meal['protein'] > 25 ? AppTheme.accent : Colors.green),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDate(String day, String date, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            day,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.accent : Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 46,
            height: 46,
            decoration: isSelected
                ? BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  )
                : BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12, width: 1),
                  ),
            child: Center(
              child: Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String amount, String label, double progress, Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: activeColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHydrationSection() {
    final double stepsProgress = (_steps / _stepGoal).clamp(0.0, 1.0);
    final double waterProgress = (_water / _waterGoal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activity & Hydration',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActivityTrackerScreen()),
                ).then((_) {
                  _loadStats();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Track Live',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.cardRadius,
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          ),
          child: Column(
            children: [
              // Row of Icons and Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Column 1: Steps
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_walk_rounded, color: AppTheme.accent, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$_steps',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'steps',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        // Mini steps progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stepsProgress,
                              minHeight: 4,
                              backgroundColor: AppTheme.accent.withOpacity(0.1),
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Plus 1k steps button
                        GestureDetector(
                          onTap: _addSteps,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+1k steps',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  Container(width: 1, height: 110, color: const Color(0xFFF1F5F9)),
                  // Column 2: Calorie Burn
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.neonPink.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.neonPink, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$_burnedCalories',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'kcal burned',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Active Energy',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.neonPink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  Container(width: 1, height: 110, color: const Color(0xFFF1F5F9)),
                  // Column 3: Water Intake
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.neonCyan.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_drink_rounded, color: AppTheme.neonCyan, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_water / 1000.0).toStringAsFixed(1)} L',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'of 2.5 L goal',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        // Mini water progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: waterProgress,
                              minHeight: 4,
                              backgroundColor: AppTheme.neonCyan.withOpacity(0.1),
                              color: AppTheme.neonCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Log Water Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _removeWater,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove, size: 12, color: Colors.black54),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _addWater,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonCyan.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, size: 12, color: AppTheme.neonCyan),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealItem({
    required String title,
    required String subtitle,
    required String calories,
    required String time,
    required IconData icon,
    required Color iconBg,
    required String tagText,
    required Color tagColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconBg, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(time, style: GoogleFonts.inter(fontSize: 12, color: Colors.black38)),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.black45)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories kcal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tagText,
                  style: GoogleFonts.inter(color: tagColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CalorieRadialGauge extends StatelessWidget {
  final int consumed;
  final int goal;
  final int burned;

  const CalorieRadialGauge({
    super.key,
    required this.consumed,
    required this.goal,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    final int left = goal - consumed + burned;
    final double percentage = (consumed - burned) / goal;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$left',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calories left',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildSubStat('Eaten', '$consumed kcal', AppTheme.accent),
                    const SizedBox(width: 24),
                    _buildSubStat('Burned', '$burned kcal', AppTheme.neonPink),
                  ],
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(100, 100),
            painter: _RadialPainter(percentage: percentage.clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
      ],
    );
  }
}

class _RadialPainter extends CustomPainter {
  final double percentage;

  _RadialPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Active arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF6366F1)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Draw arc from top (-pi/2)
    canvas.drawArc(rect, -pi / 2, 2 * pi * percentage, false, activePaint);

    // Inner glow dot at current position
    final double angle = -pi / 2 + 2 * pi * percentage;
    final double dotX = center.dx + radius * cos(angle);
    final double dotY = center.dy + radius * sin(angle);
    
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final shadowPaint = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(dotX, dotY), 6, shadowPaint);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
