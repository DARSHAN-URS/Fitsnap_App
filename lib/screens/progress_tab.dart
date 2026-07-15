import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';
import '../widgets/staggered_animation.dart';
import '../services/api_service.dart';
import '../providers/badge_provider.dart';
import 'badges_screen.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> with TickerProviderStateMixin {
  int _selectedSegment = 0; // 30D, 90D, 6M, ALL

  late AnimationController _entryAnimController;

  final List<Map<String, dynamic>> _metrics = [
    {
      'name': 'Weight',
      'icon': Icons.monitor_weight_outlined,
      'unit': 'kg',
      'data': [78.5, 78.2, 77.8, 78.0, 77.3, 76.9, 76.4],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.accent,
      'insight': '-2.1 kg from goal',
    },
    {
      'name': 'Distance Traveled',
      'icon': Icons.directions_run_rounded,
      'unit': 'km',
      'data': [3.2, 4.5, 2.8, 5.0, 3.6, 4.2, 5.8],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonCyan,
      'insight': '0.0 km total',
    },
    {
      'name': 'Strength Gain',
      'icon': Icons.fitness_center_rounded,
      'unit': 'kg',
      'data': [5.0, 5.0, 5.0, 7.5, 7.5, 7.5, 10.0],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonPink,
      'insight': '+5.0 kg progress',
    },
    {
      'name': 'Waist Size',
      'icon': Icons.accessibility_new_rounded,
      'unit': 'in',
      'data': [34.0, 33.8, 33.5, 33.6, 33.2, 33.0, 32.8],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonCyan,
      'insight': '-1.2 in shredded',
    },
    {
      'name': 'Chest Size',
      'icon': Icons.sports_gymnastics_rounded,
      'unit': 'in',
      'data': [38.5, 38.6, 38.8, 39.0, 39.2, 39.3, 39.5],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonAmber,
      'insight': '+1.0 in gained',
    },
    {
      'name': 'Thighs Size',
      'icon': Icons.directions_run_rounded,
      'unit': 'in',
      'data': [22.0, 22.1, 22.1, 22.3, 22.4, 22.4, 22.6],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonEmerald,
      'insight': '+0.6 in volume',
    },
    {
      'name': 'Arms Size',
      'icon': Icons.gesture_rounded,
      'unit': 'in',
      'data': [13.2, 13.3, 13.3, 13.5, 13.6, 13.7, 13.8],
      'labels': ['May 1', 'May 5', 'May 10', 'May 15', 'May 20', 'May 25', 'Jun 1'],
      'color': AppTheme.neonIndigo,
      'insight': '+0.6 in peak',
    },
  ];

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimController.forward();
    _loadProgressData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(badgeProvider.notifier).updateStreakDaily();
    });
  }

  Future<void> _loadProgressData() async {
    // Sync workouts from backend if authenticated to make Distance Traveled dynamic
    if (ApiService.isAuthenticated) {
      final res = await ApiService.getWorkouts();
      if (res['success'] == true) {
        final List<dynamic> list = res['data'];
        final List<String> wHistory = [];
        for (var item in list) {
          final name = item['workout_name'] ?? 'Workout';
          final dist = item['distance'] ?? 0.0;
          final duration = item['duration_seconds'] ?? 0;
          final calories = item['calories'] ?? 0;
          final dateStr = item['completed_at'] ?? DateTime.now().toIso8601String();
          final durationStr = "${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}";
          wHistory.add("$name|$dist|$durationStr|$calories|$dateStr");
        }
        await PreferencesHelper.saveStringList('workout_history', wHistory);
      }
    }

    // Load measurements from backend if authenticated
    Map<String, List<Map<String, dynamic>>> fetchedData = {};
    if (ApiService.isAuthenticated) {
      final res = await ApiService.getMeasurements();
      if (res['success'] == true) {
        final List<dynamic> list = res['data'];
        for (var item in list) {
          final type = item['metric_type'] as String;
          fetchedData.putIfAbsent(type, () => []);
          fetchedData[type]!.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Load fallbacks from cache if missing
    for (var type in ['weight', 'waist', 'chest', 'arms', 'thighs', 'strength']) {
      if (!fetchedData.containsKey(type) || fetchedData[type]!.isEmpty) {
        final String cacheKey = type == 'weight' ? 'weight_logs' : 'cached_logs_$type';
        final String? cacheJson = await PreferencesHelper.readString(cacheKey);
        if (cacheJson != null) {
          try {
            final List<dynamic> decoded = jsonDecode(cacheJson);
            fetchedData[type] = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
          } catch (e) {
            debugPrint('Error parsing cached $type logs: $e');
          }
        }
      }
    }

    // Weight target
    final double currentWeight = await PreferencesHelper.readDouble('weight_current') ?? 76.4;
    final double targetWeight = await PreferencesHelper.readDouble('weight_target') ?? 74.3;
    final double diffWeight = currentWeight - targetWeight;
    final String weightInsight = diffWeight > 0
        ? '${diffWeight.toStringAsFixed(1)} kg from goal'
        : '${diffWeight.abs().toStringAsFixed(1)} kg from goal';

    // Waist target
    final double currentWaist = await PreferencesHelper.readDouble('waist_current') ?? 34.0;
    final double targetWaist = await PreferencesHelper.readDouble('waist_target') ?? 32.0;
    final double diffWaist = currentWaist - targetWaist;
    final String waistInsight = diffWaist > 0
        ? '${diffWaist.toStringAsFixed(1)} in from goal'
        : '${diffWaist.abs().toStringAsFixed(1)} in from goal';

    // Chest target
    final double currentChest = await PreferencesHelper.readDouble('chest_current') ?? 38.5;
    final double targetChest = await PreferencesHelper.readDouble('chest_target') ?? 40.0;
    final double diffChest = targetChest - currentChest;
    final String chestInsight = diffChest > 0
        ? '${diffChest.toStringAsFixed(1)} in from goal'
        : '${diffChest.abs().toStringAsFixed(1)} in from goal';

    // Arms target
    final double currentArms = await PreferencesHelper.readDouble('arms_current') ?? 13.2;
    final double targetArms = await PreferencesHelper.readDouble('arms_target') ?? 14.0;
    final double diffArms = targetArms - currentArms;
    final String armsInsight = diffArms > 0
        ? '${diffArms.toStringAsFixed(1)} in from goal'
        : '${diffArms.abs().toStringAsFixed(1)} in from goal';

    // Thighs target
    final double currentThighs = await PreferencesHelper.readDouble('thighs_current') ?? 22.0;
    final double targetThighs = await PreferencesHelper.readDouble('thighs_target') ?? 23.0;
    final double diffThighs = targetThighs - currentThighs;
    final String thighsInsight = diffThighs > 0
        ? '${diffThighs.toStringAsFixed(1)} in from goal'
        : '${diffThighs.abs().toStringAsFixed(1)} in from goal';

    // Strength target
    final double currentStrength = await PreferencesHelper.readDouble('strength_current') ?? 5.0;
    final double targetStrength = await PreferencesHelper.readDouble('strength_target') ?? 15.0;
    final double diffStrength = targetStrength - currentStrength;
    final String strengthInsight = diffStrength > 0
        ? '${diffStrength.toStringAsFixed(1)} kg from goal'
        : '${diffStrength.abs().toStringAsFixed(1)} kg from goal';

    // Parse values for each metric type
    Map<String, List<double>> chartValues = {};
    Map<String, List<String>> chartLabels = {};



    for (var type in ['weight', 'waist', 'chest', 'arms', 'thighs', 'strength']) {
      List<double> vals = [];
      List<String> lbls = [];
      
      final typeLogs = fetchedData[type] ?? [];
      final chronLogs = typeLogs.reversed.toList();
      
      for (var item in chronLogs) {
        final double val = (item['value'] ?? item['weight'] ?? 0.0) as double;
        String dateStr = (item['date'] ?? '') as String;
        if (dateStr.contains(',')) {
          dateStr = dateStr.split(',')[0].trim();
        }
        if (val > 0 && dateStr.isNotEmpty) {
          vals.add(val);
          lbls.add(dateStr);
        }
      }
      
      if (vals.isEmpty) {
        chartValues[type] = [];
        chartLabels[type] = [];
      } else {
        chartValues[type] = vals;
        chartLabels[type] = lbls;
      }
    }

    // Load distance traveled logs
    double totalDistance = 0.0;
    List<double> distanceData = [];
    List<String> distanceLabels = [];
    
    final List<String> rawWorkouts = await PreferencesHelper.readStringList('workout_history') ?? [];
    Map<String, double> distanceByDay = {};
    
    for (var raw in rawWorkouts) {
      final parts = raw.split('|');
      if (parts.length >= 2) {
        final double dist = double.tryParse(parts[1]) ?? 0.0;
        final String dateStr = parts.length > 4 ? parts[4] : DateTime.now().toIso8601String();
        final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
        
        final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final String dayKey = "${months[parsedDate.month - 1]} ${parsedDate.day}";
        distanceByDay[dayKey] = (distanceByDay[dayKey] ?? 0.0) + dist;
      }
    }
    
    if (distanceByDay.isNotEmpty) {
      final keys = distanceByDay.keys.toList();
      final start = keys.length > 7 ? keys.length - 7 : 0;
      for (int i = start; i < keys.length; i++) {
        distanceLabels.add(keys[i]);
        distanceData.add(distanceByDay[keys[i]]!);
        totalDistance += distanceByDay[keys[i]]!;
      }
    }
    
    if (distanceData.isEmpty) {
      distanceData = [];
      distanceLabels = [];
      totalDistance = 0.0;
    }

    if (mounted) {
      setState(() {
        _updateMetricData('Weight', chartValues['weight']!, chartLabels['weight']!, weightInsight);
        _updateMetricData('Distance Traveled', distanceData, distanceLabels, '${totalDistance.toStringAsFixed(1)} km total');
        _updateMetricData('Strength Gain', chartValues['strength']!, chartLabels['strength']!, strengthInsight);
        _updateMetricData('Waist Size', chartValues['waist']!, chartLabels['waist']!, waistInsight);
        _updateMetricData('Chest Size', chartValues['chest']!, chartLabels['chest']!, chestInsight);
        _updateMetricData('Thighs Size', chartValues['thighs']!, chartLabels['thighs']!, thighsInsight);
        _updateMetricData('Arms Size', chartValues['arms']!, chartLabels['arms']!, armsInsight);
      });
    }
  }

  void _updateMetricData(String name, List<double> data, List<String> labels, String insight) {
    try {
      final metric = _metrics.firstWhere((m) => m['name'] == name);
      metric['data'] = data;
      metric['labels'] = labels;
      metric['insight'] = insight;
    } catch (e) {
      debugPrint('Metric not found: $name');
    }
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeState = ref.watch(badgeProvider);
    
    // Calculate which weekdays are active based on the current week's dates
    final now = DateTime.now();
    final int currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final List<bool> activeWeekdays = List.generate(7, (index) {
      final int diff = (index + 1) - currentWeekday;
      final DateTime dayDate = now.add(Duration(days: diff));
      final String dayStr = dayDate.toIso8601String().split('T')[0];
      return badgeState.activeDates.contains(dayStr);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          StaggeredListItem(
            index: 0,
            animationController: _entryAnimController,
            child: Text(
            'Progress',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            ),
          ),
          ),
          const SizedBox(height: 24),
          
          // Stats Row
          StaggeredListItem(
            index: 1,
            animationController: _entryAnimController,
            child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppTheme.cardRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.cardRadius,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        color: Colors.white.withOpacity(0.55),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.local_fire_department_rounded, color: Colors.orange.shade800, size: 48),
                            const SizedBox(height: 6),
                            Text(
                              '${badgeState.streakDays} ${badgeState.streakDays == 1 ? "Day" : "Days"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active streak',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Weekly dot matrix
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _StreakDot(label: 'M', isActive: activeWeekdays[0]),
                                _StreakDot(label: 'T', isActive: activeWeekdays[1]),
                                _StreakDot(label: 'W', isActive: activeWeekdays[2]),
                                _StreakDot(label: 'T', isActive: activeWeekdays[3]),
                                _StreakDot(label: 'F', isActive: activeWeekdays[4]),
                                _StreakDot(label: 'S', isActive: activeWeekdays[5]),
                                _StreakDot(label: 'S', isActive: activeWeekdays[6]),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BadgesScreen()),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: AppTheme.cardRadius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: AppTheme.cardRadius,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          color: Colors.white.withOpacity(0.55),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
                              const SizedBox(height: 6),
                              Text(
                                '${badgeState.earnedBadges.length} Earned',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total achievements',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Badge mini circles
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _buildMiniBadges(badgeState.earnedBadges),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 24),

          // Global Time Window Segment Slider
          StaggeredListItem(
            index: 2,
            animationController: _entryAnimController,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSegmentButton(0, '30D'),
                  _buildSegmentButton(1, '90D'),
                  _buildSegmentButton(2, '6M'),
                  _buildSegmentButton(3, 'ALL'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Vertical Stack of Bar Charts
          Column(
            children: _metrics.asMap().entries.map((entry) {
              final int idx = entry.key;
              final Map<String, dynamic> metric = entry.value;

              return StaggeredListItem(
                index: 3 + idx,
                animationController: _entryAnimController,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(metric['icon'], color: metric['color'], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${metric['name']} Tracker',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.bar_chart_rounded, size: 14, color: metric['color']),
                                    const SizedBox(width: 4),
                                    Text(
                                      metric['insight'],
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Custom Bar Chart
                          metric['data'] == null || (metric['data'] as List).isEmpty
                              ? Container(
                                  height: 160,
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.analytics_outlined,
                                        size: 32,
                                        color: const Color(0xFF64748B).withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No data logged yet',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Start tracking to view charts',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B).withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ProgressBarChart(
                                  dataPoints: List<double>.from(metric['data']),
                                  labels: List<String>.from(metric['labels']),
                                  chartColor: metric['color'],
                                  unit: metric['unit'],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Tip / Insights banner
          StaggeredListItem(
            index: 3 + _metrics.length,
            animationController: _entryAnimController,
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: Colors.green.shade100, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Colors.green, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Analytics Insight',
                        style: GoogleFonts.inter(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "You've stayed below your calorie budget 6 out of 7 days. Your weight is down by 0.5kg this week!",
                        style: GoogleFonts.inter(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          )
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return ClipRRect(
      borderRadius: AppTheme.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: AppTheme.cardRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  List<Widget> _buildMiniBadges(List<String> earned) {
    if (earned.isEmpty) {
      return [
        Text(
          'No badges yet',
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
        )
      ];
    }
    
    final List<Widget> list = [];
    for (int i = 0; i < earned.length && i < 3; i++) {
      final name = earned[i];
      IconData icon = Icons.stars_rounded;
      Color color = Colors.amber;
      
      try {
        final badge = allBadges.firstWhere((b) => b.id == name);
        icon = badge.icon;
        color = badge.color;
      } catch (_) {}
      
      list.add(Icon(icon, color: color, size: 20));
      if (i < earned.length - 1 && i < 2) {
        list.add(const SizedBox(width: 6));
      }
    }
    return list;
  }
}

class _StreakDot extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StreakDot({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.neonEmerald : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.neonEmerald.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: isActive
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        )
      ],
    );
  }
}

class ProgressBarChart extends StatefulWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final Color chartColor;
  final String unit;

  const ProgressBarChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    required this.chartColor,
    required this.unit,
  });

  @override
  State<ProgressBarChart> createState() => _ProgressBarChartState();
}

class _ProgressBarChartState extends State<ProgressBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartAnimController;
  late Animation<double> _chartProgress;

  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _chartProgress = CurvedAnimation(
      parent: _chartAnimController,
      curve: Curves.easeOutCubic,
    );
    _chartAnimController.forward();
  }

  @override
  void didUpdateWidget(covariant ProgressBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataPoints != widget.dataPoints ||
        oldWidget.chartColor != widget.chartColor) {
      _chartAnimController.reset();
      _chartAnimController.forward();
    }
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _chartProgress,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _ProgressBarChartPainter(
                dataPoints: widget.dataPoints,
                color: widget.chartColor,
                unit: widget.unit,
                progress: _chartProgress.value,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: widget.labels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.black38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ProgressBarChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;
  final String unit;
  final double progress;

  _ProgressBarChartPainter({
    required this.dataPoints,
    required this.color,
    required this.unit,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Determine min and max
    double minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    
    // Add small buffer to top and bottom of chart
    double range = maxVal - minVal;
    if (range == 0) range = 1.0;
    minVal = (minVal - range * 0.25).clamp(0.0, double.infinity);
    maxVal += range * 0.15;
    range = maxVal - minVal;

    final double stepX = width / dataPoints.length;
    final double barWidth = (stepX * 0.55).clamp(6.0, 32.0);
    
    // Draw Grid Lines (3 horizontal lines)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 4; i++) {
      double y = height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
      
      // Draw label on grid lines
      final double val = maxVal - (range * (i / 3));
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${val.toStringAsFixed(1)} $unit',
          style: GoogleFonts.inter(fontSize: 8.5, color: Colors.black26, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 11));
    }

    // Draw the vertical bars
    for (int i = 0; i < dataPoints.length; i++) {
      final double val = dataPoints[i];
      double barHeight = ((val - minVal) / range * height) * progress;
      if (barHeight < 0.0) barHeight = 0.0;

      // Center the bar within its step segment
      final double x = (i * stepX) + (stepX - barWidth) / 2;
      final double y = height - barHeight;

      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            color,
            color.withOpacity(0.35),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(barRect, barPaint);

      // Subtle stroke border for premium definition
      final borderPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(barRect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.color != color ||
        oldDelegate.unit != unit ||
        oldDelegate.progress != progress;
  }
}

