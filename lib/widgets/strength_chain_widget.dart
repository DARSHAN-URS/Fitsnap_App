import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/preferences_helper.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// --- DATA MODELS ---

class StrengthExercise {
  final String name;
  final double weight;
  final int reps;

  StrengthExercise({
    required this.name,
    required this.weight,
    required this.reps,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'reps': reps,
      };

  factory StrengthExercise.fromJson(Map<String, dynamic> json) {
    return StrengthExercise(
      name: json['name'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      reps: json['reps'] as int? ?? 10,
    );
  }
}

class StrengthWorkout {
  final String id;
  final String title;
  final String category; // Chest, Back, Legs, Shoulders, Arms
  final DateTime date;
  final List<StrengthExercise> exercises;

  StrengthWorkout({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory StrengthWorkout.fromJson(Map<String, dynamic> json) {
    return StrengthWorkout(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Chest',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => StrengthExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// --- MAIN WIDGET ---

class StrengthChainWidget extends StatefulWidget {
  final VoidCallback? onWorkoutLogged;

  const StrengthChainWidget({super.key, this.onWorkoutLogged});

  @override
  State<StrengthChainWidget> createState() => _StrengthChainWidgetState();
}

class _StrengthChainWidgetState extends State<StrengthChainWidget> {
  List<StrengthWorkout> _workouts = [];
  bool _isLoading = true;
  String _selectedCategory = 'Chest';

  final List<String> _categories = ['Chest', 'Shoulders', 'Arms', 'Back', 'Legs'];
  final Map<String, Color> _categoryColors = {
    'Chest': AppTheme.neonPink,
    'Shoulders': AppTheme.neonIndigo,
    'Arms': AppTheme.neonCyan,
    'Back': AppTheme.neonEmerald,
    'Legs': AppTheme.neonAmber,
  };

  final Map<String, IconData> _categoryIcons = {
    'Chest': Icons.fitness_center_rounded,
    'Shoulders': Icons.sports_gymnastics_rounded,
    'Arms': Icons.bolt_rounded,
    'Back': Icons.accessibility_new_rounded,
    'Legs': Icons.directions_run_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final workouts = await _loadWorkouts();
    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
  }

  Future<List<StrengthWorkout>> _loadWorkouts() async {
    // If authenticated, sync with backend
    if (ApiService.isAuthenticated) {
      try {
        final res = await ApiService.getWorkouts();
        if (res['success']) {
          final List<dynamic> serverWorkouts = res['data'];
          final List<StrengthWorkout> parsed = [];
          for (var item in serverWorkouts) {
            if (item['workout_type'] == 'strength') {
              final String id = item['id']?.toString() ?? '';
              final String name = item['workout_name'] ?? 'Workout';
              final String category = item['category'] ?? 'Chest';
              final String dateStr = item['completed_at'] ?? DateTime.now().toIso8601String();
              
              final List<dynamic> exercisesRaw = item['exercises'] ?? [];
              final List<StrengthExercise> exercises = exercisesRaw.map((e) => StrengthExercise(
                name: e['name']?.toString() ?? '',
                weight: (e['weight'] as num?)?.toDouble() ?? 0.0,
                reps: e['reps'] as int? ?? 10,
              )).toList();

              parsed.add(StrengthWorkout(
                id: id,
                title: name,
                category: category,
                date: DateTime.tryParse(dateStr) ?? DateTime.now(),
                exercises: exercises,
              ));
            }
          }

          // Cache them locally
          final stringList = parsed.map((w) => jsonEncode(w.toJson())).toList();
          await PreferencesHelper.saveStringList('strength_workouts', stringList);
          return parsed;
        }
      } catch (e) {
        debugPrint('Failed to sync strength workouts from backend: $e. Falling back to local cache.');
      }
    }

    // Fallback to local cache
    final list = await PreferencesHelper.readStringList('strength_workouts');
    if (list == null) {
      final mock = _getInitialMockData();
      final stringList = mock.map((w) => jsonEncode(w.toJson())).toList();
      await PreferencesHelper.saveStringList('strength_workouts', stringList);
      return mock;
    }
    try {
      return list.map((item) => StrengthWorkout.fromJson(jsonDecode(item))).toList();
    } catch (e) {
      debugPrint('Error loading cached strength workouts: $e');
      return _getInitialMockData();
    }
  }

  Future<void> _saveWorkout(StrengthWorkout workout) async {
    // Save locally first for instant responsive UI
    final updated = List<StrengthWorkout>.from(_workouts)..insert(0, workout);
    final stringList = updated.map((w) => jsonEncode(w.toJson())).toList();
    await PreferencesHelper.saveStringList('strength_workouts', stringList);
    
    // Update active badges/streak if applicable
    final activeDates = await PreferencesHelper.readStringList('active_dates') ?? [];
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (!activeDates.contains(todayStr)) {
      activeDates.add(todayStr);
      await PreferencesHelper.saveStringList('active_dates', activeDates);
    }

    setState(() {
      _workouts = updated;
    });

    if (widget.onWorkoutLogged != null) {
      widget.onWorkoutLogged!();
    }

    // Sync to backend asynchronously if authenticated
    if (ApiService.isAuthenticated) {
      try {
        final exercisesPayload = workout.exercises.map((e) => {
          'name': e.name,
          'weight': e.weight,
          'reps': e.reps,
        }).toList();

        final res = await ApiService.saveStrengthWorkout(
          workoutName: workout.title,
          category: workout.category,
          exercises: exercisesPayload,
        );

        if (res['success']) {
          final serverWorkout = res['data'];
          final serverId = serverWorkout['id']?.toString();
          if (serverId != null) {
            final int index = _workouts.indexWhere((w) => w.id == workout.id);
            if (index != -1) {
              setState(() {
                _workouts[index] = StrengthWorkout(
                  id: serverId,
                  title: workout.title,
                  category: workout.category,
                  date: workout.date,
                  exercises: workout.exercises,
                );
              });
              // Recache updated list
              final recachedStringList = _workouts.map((w) => jsonEncode(w.toJson())).toList();
              await PreferencesHelper.saveStringList('strength_workouts', recachedStringList);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to save strength workout to backend: $e');
      }
    }
  }

  Future<void> _deleteWorkout(String id) async {
    // Delete locally first
    final updated = _workouts.where((w) => w.id != id).toList();
    final stringList = updated.map((w) => jsonEncode(w.toJson())).toList();
    await PreferencesHelper.saveStringList('strength_workouts', stringList);
    setState(() {
      _workouts = updated;
    });

    // Delete on backend if authenticated
    if (ApiService.isAuthenticated) {
      try {
        await ApiService.deleteWorkout(id);
      } catch (e) {
        debugPrint('Failed to delete workout on backend: $e');
      }
    }
  }

  List<StrengthWorkout> _getInitialMockData() {
    final now = DateTime.now();
    return [
      StrengthWorkout(
        id: '1',
        title: 'Chest Destroyer',
        category: 'Chest',
        date: now.subtract(const Duration(days: 7)),
        exercises: [
          StrengthExercise(name: 'Bench Press', weight: 75.0, reps: 10),
          StrengthExercise(name: 'Incline Dumbbell Press', weight: 26.0, reps: 12),
          StrengthExercise(name: 'Chest Flys', weight: 14.0, reps: 15),
        ],
      ),
      StrengthWorkout(
        id: '2',
        title: 'Leg Crusher',
        category: 'Legs',
        date: now.subtract(const Duration(days: 6)),
        exercises: [
          StrengthExercise(name: 'Squats', weight: 90.0, reps: 8),
          StrengthExercise(name: 'Leg Press', weight: 180.0, reps: 12),
          StrengthExercise(name: 'Calf Raises', weight: 45.0, reps: 20),
        ],
      ),
      StrengthWorkout(
        id: '3',
        title: 'Back Pull Routine',
        category: 'Back',
        date: now.subtract(const Duration(days: 4)),
        exercises: [
          StrengthExercise(name: 'Deadlift', weight: 110.0, reps: 5),
          StrengthExercise(name: 'Lat Pulldown', weight: 60.0, reps: 10),
          StrengthExercise(name: 'Seated Cable Row', weight: 55.0, reps: 12),
        ],
      ),
      StrengthWorkout(
        id: '4',
        title: 'Shoulders & Press',
        category: 'Shoulders',
        date: now.subtract(const Duration(days: 3)),
        exercises: [
          StrengthExercise(name: 'Overhead Press', weight: 45.0, reps: 8),
          StrengthExercise(name: 'Dumbbell Lateral Raise', weight: 12.0, reps: 15),
          StrengthExercise(name: 'Front Raise', weight: 10.0, reps: 12),
        ],
      ),
      StrengthWorkout(
        id: '5',
        title: 'Arm Pump Friday',
        category: 'Arms',
        date: now.subtract(const Duration(days: 1)),
        exercises: [
          StrengthExercise(name: 'Bicep Barbell Curl', weight: 30.0, reps: 12),
          StrengthExercise(name: 'Tricep Pushdowns', weight: 35.0, reps: 15),
          StrengthExercise(name: 'Hammer Curls', weight: 14.0, reps: 12),
        ],
      ),
    ];
  }

  // Calculate the max weight lifted in a specific category
  double _getMaxWeightForCategory(String category) {
    double maxWeight = 0.0;
    for (var w in _workouts) {
      if (w.category.toLowerCase() == category.toLowerCase()) {
        for (var e in w.exercises) {
          if (e.weight > maxWeight) {
            maxWeight = e.weight;
          }
        }
      }
    }
    return maxWeight;
  }

  // Get historical max weight progression points for the selected category
  List<double> _getProgressPoints(String category) {
    final filtered = _workouts
        .where((w) => w.category.toLowerCase() == category.toLowerCase())
        .toList();
    // Sort oldest to newest
    filtered.sort((a, b) => a.date.compareTo(b.date));

    final List<double> progress = [];
    for (var w in filtered) {
      double workoutMax = 0.0;
      for (var e in w.exercises) {
        if (e.weight > workoutMax) {
          workoutMax = e.weight;
        }
      }
      if (workoutMax > 0) {
        progress.add(workoutMax);
      }
    }

    if (progress.isEmpty) {
      return [0.0];
    }
    return progress;
  }

  List<String> _getProgressLabels(String category) {
    final filtered = _workouts
        .where((w) => w.category.toLowerCase() == category.toLowerCase())
        .toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));

    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final List<String> labels = [];
    for (var w in filtered) {
      labels.add("${months[w.date.month - 1]} ${w.date.day}");
    }

    if (labels.isEmpty) {
      return ['No data'];
    }
    return labels;
  }

  void _showLogWorkoutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutLogModal(
        categories: _categories,
        categoryColors: _categoryColors,
        onSave: (workout) {
          _saveWorkout(workout);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    final maxWeights = {
      for (var cat in _categories) cat: _getMaxWeightForCategory(cat)
    };

    final progressPoints = _getProgressPoints(_selectedCategory);
    final progressLabels = _getProgressLabels(_selectedCategory);
    final categoryColor = _categoryColors[_selectedCategory] ?? AppTheme.accent;

    final filteredWorkouts = _workouts
        .where((w) => w.category.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Log Strength Workout Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: AppTheme.cardRadius,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: AppTheme.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'STRENGTH LOGGER',
                          style: GoogleFonts.inter(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Record Your Lifting Session',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter exercises, track weight metrics, and build your custom Strength Chain over time.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _showLogWorkoutModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 20, fontWeight: FontWeight.bold),
                    const SizedBox(width: 6),
                    Text(
                      'Log Strength Workout',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Strength Chain Section Title
        Text(
          'Interactive Strength Chain',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap muscle nodes to view progression details.',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),

        // Connected Pentagram Chain graphic
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.cardRadius,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: StrengthChainPentagram(
              categories: _categories,
              categoryColors: _categoryColors,
              categoryIcons: _categoryIcons,
              maxWeights: maxWeights,
              selectedCategory: _selectedCategory,
              onSelectCategory: (cat) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Progression details of selected node
        Text(
          '$_selectedCategory Progression',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Curved line chart showing progression of selected muscle group
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.cardRadius,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_categoryIcons[_selectedCategory], color: categoryColor, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Peak Lift History',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Max: ${maxWeights[_selectedCategory]?.toStringAsFixed(1)} kg',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (progressPoints.length <= 1 && progressPoints[0] == 0.0)
                  Container(
                    height: 160,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      'Log multiple workouts to see progression chart.',
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  StrengthLineChart(
                    dataPoints: progressPoints,
                    labels: progressLabels,
                    chartColor: categoryColor,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Recent Logs of selected category
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent $_selectedCategory Workouts',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (filteredWorkouts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.fitness_center_rounded, color: Colors.grey.shade300, size: 36),
                const SizedBox(height: 12),
                Text(
                  'No $_selectedCategory logs yet',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredWorkouts.length,
            itemBuilder: (context, index) {
              final workout = filteredWorkouts[index];
              final dateStr = "${workout.date.day}/${workout.date.month}/${workout.date.year}";

              // Peak lift calculation
              double peakLift = 0.0;
              for (var e in workout.exercises) {
                if (e.weight > peakLift) peakLift = e.weight;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout.title,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Peak: ${peakLift.toStringAsFixed(0)} kg',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: categoryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _deleteWorkout(workout.id),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    Column(
                      children: workout.exercises.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${e.weight.toStringAsFixed(1)} kg • ${e.reps} reps',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// --- INTERACTIVE PENTAGRAM GRAPHIC ---

class StrengthChainPentagram extends StatelessWidget {
  final List<String> categories;
  final Map<String, Color> categoryColors;
  final Map<String, IconData> categoryIcons;
  final Map<String, double> maxWeights;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  const StrengthChainPentagram({
    super.key,
    required this.categories,
    required this.categoryColors,
    required this.categoryIcons,
    required this.maxWeights,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  Offset _getNodePosition(int index, double width, double height) {
    final double cx = width / 2;
    final double cy = height / 2;
    const double r = 85.0; // Radius from center
    // Math to space 5 points uniformly in a circle
    final double angle = -pi / 2 + (index * 2 * pi / 5);
    return Offset(cx + r * cos(angle), cy + r * sin(angle));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double height = 240.0;

        // Compute coordinate positions of the 5 nodes
        final List<Offset> points = List.generate(
          categories.length,
          (i) => _getNodePosition(i, width, height),
        );

        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom paint connecting line chain behind nodes
              Positioned.fill(
                child: CustomPaint(
                  painter: ChainConnectorPainter(
                    points: points,
                    selectedCategory: selectedCategory,
                    categoryColors: categoryColors,
                    categories: categories,
                  ),
                ),
              ),

              // Render the nodes centered at coordinate offsets
              ...List.generate(categories.length, (i) {
                final category = categories[i];
                final pos = points[i];
                final color = categoryColors[category] ?? AppTheme.accent;
                final isSelected = category == selectedCategory;
                final maxWeight = maxWeights[category] ?? 0.0;

                return Positioned(
                  left: pos.dx - 35,
                  top: pos.dy - 35,
                  child: GestureDetector(
                    onTap: () => onSelectCategory(category),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? color : const Color(0xFF0F172A),
                            border: Border.all(
                              color: isSelected ? Colors.white : color.withOpacity(0.8),
                              width: isSelected ? 3.0 : 2.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                          ),
                          child: Icon(
                            categoryIcons[category],
                            color: isSelected ? const Color(0xFF0F172A) : color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? color.withOpacity(0.3) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? color : const Color(0xFF334155),
                                ),
                              ),
                              Text(
                                '${maxWeight.toStringAsFixed(0)} kg',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? color : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// --- LINE CONNECTOR CUSTOM PAINTER ---

class ChainConnectorPainter extends CustomPainter {
  final List<Offset> points;
  final String selectedCategory;
  final Map<String, Color> categoryColors;
  final List<String> categories;

  ChainConnectorPainter({
    required this.points,
    required this.selectedCategory,
    required this.categoryColors,
    required this.categories,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 5) return;

    // Draw the subtle background chain connections
    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, bgPaint);

    // Draw active connections with glow
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final cat1 = categories[i];
      final cat2 = categories[(i + 1) % points.length];

      // Connection is highlighted if either of the nodes is the selected category
      final bool isHighlighted = (cat1 == selectedCategory || cat2 == selectedCategory);

      final color1 = categoryColors[cat1] ?? AppTheme.accent;
      final color2 = categoryColors[cat2] ?? AppTheme.accent;

      final gradPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            isHighlighted ? color1 : color1.withOpacity(0.15),
            isHighlighted ? color2 : color2.withOpacity(0.15),
          ],
        ).createShader(Rect.fromPoints(p1, p2))
        ..strokeWidth = isHighlighted ? 4.0 : 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Glow effect if highlighted
      if (isHighlighted) {
        final glowPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              color1.withOpacity(0.35),
              color2.withOpacity(0.35),
            ],
          ).createShader(Rect.fromPoints(p1, p2))
          ..strokeWidth = 10.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawLine(p1, p2, glowPaint);
      }

      canvas.drawLine(p1, p2, gradPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChainConnectorPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.points != points;
  }
}

// --- CURVED LINE PROGRESSION CHART ---

class StrengthLineChart extends StatefulWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final Color chartColor;

  const StrengthLineChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    required this.chartColor,
  });

  @override
  State<StrengthLineChart> createState() => _StrengthLineChartState();
}

class _StrengthLineChartState extends State<StrengthLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _chartProgress;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _chartProgress = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant StrengthLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataPoints != widget.dataPoints ||
        oldWidget.chartColor != widget.chartColor) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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
              size: const Size(double.infinity, 150),
              painter: StrengthLineChartPainter(
                dataPoints: widget.dataPoints,
                chartColor: widget.chartColor,
                progress: _chartProgress.value,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: widget.labels
              .map((l) => Text(
                    l,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class StrengthLineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color chartColor;
  final double progress;

  StrengthLineChartPainter({
    required this.dataPoints,
    required this.chartColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Get min and max
    double minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);

    // Padding buffer
    double range = maxVal - minVal;
    if (range == 0) range = 10.0;
    minVal = (minVal - range * 0.15).clamp(0.0, double.infinity);
    maxVal += range * 0.15;
    range = maxVal - minVal;

    // Grid lines (3 horizontal)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      double y = height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);

      final val = maxVal - (range * (i / 2));
      final tp = TextPainter(
        text: TextSpan(
          text: '${val.toStringAsFixed(0)} kg',
          style: GoogleFonts.inter(
            fontSize: 8.5,
            color: Colors.black26,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(4, y - 11));
    }

    final double stepX = width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);

    // Create coordinates
    final List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * stepX;
      final double targetY = height - ((dataPoints[i] - minVal) / range * height);
      final double animatedY = height - (height - targetY) * progress;
      points.add(Offset(x, animatedY));
    }

    if (points.isEmpty) return;

    // Build curve path
    final path = Path();
    if (points.length == 1) {
      path.moveTo(0, points[0].dy);
      path.lineTo(width, points[0].dy);
    } else {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final controlX1 = p1.dx + (p2.dx - p1.dx) / 2;
        final controlY1 = p1.dy;
        final controlX2 = p1.dx + (p2.dx - p1.dx) / 2;
        final controlY2 = p2.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p2.dx, p2.dy);
      }
    }

    // Draw gradient area under path
    final fillPath = Path.from(path);
    if (points.length > 1) {
      fillPath.lineTo(points.last.dx, height);
      fillPath.lineTo(points.first.dx, height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            chartColor.withOpacity(0.2),
            chartColor.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw glow line below the main line
    final glowPaint = Paint()
      ..color = chartColor.withOpacity(0.3)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw main stroke line
    final strokePaint = Paint()
      ..color = chartColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = chartColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(p, 4.5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StrengthLineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.chartColor != chartColor ||
        oldDelegate.dataPoints != dataPoints;
  }
}

// --- GLASSMORPHIC BOTTOM SHEET WORKOUT LOGGER ---

class WorkoutLogModal extends StatefulWidget {
  final List<String> categories;
  final Map<String, Color> categoryColors;
  final ValueChanged<StrengthWorkout> onSave;

  const WorkoutLogModal({
    super.key,
    required this.categories,
    required this.categoryColors,
    required this.onSave,
  });

  @override
  State<WorkoutLogModal> createState() => _WorkoutLogModalState();
}

class _WorkoutLogModalState extends State<WorkoutLogModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _selectedCategory = 'Chest';

  // State to hold lists of controllers for name, weights, and reps
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _weightControllers = [];
  final List<TextEditingController> _repsControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Chest Day Workout';
    _addNewExerciseRow();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    for (var c in _repsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addNewExerciseRow() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _weightControllers.add(TextEditingController());
      _repsControllers.add(TextEditingController());
    });
  }

  void _removeExerciseRow(int index) {
    if (_nameControllers.length > 1) {
      setState(() {
        _nameControllers[index].dispose();
        _weightControllers[index].dispose();
        _repsControllers[index].dispose();
        _nameControllers.removeAt(index);
        _weightControllers.removeAt(index);
        _repsControllers.removeAt(index);
      });
    }
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
        _titleController.text = '$category Day Routine';
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final List<StrengthExercise> exercises = [];
      for (int i = 0; i < _nameControllers.length; i++) {
        final name = _nameControllers[i].text.trim();
        final weight = double.tryParse(_weightControllers[i].text) ?? 0.0;
        final reps = int.tryParse(_repsControllers[i].text) ?? 10;
        if (name.isNotEmpty && weight > 0) {
          exercises.add(StrengthExercise(name: name, weight: weight, reps: reps));
        }
      }

      if (exercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one exercise with a valid weight!'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final newWorkout = StrengthWorkout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : '$_selectedCategory Day Routine',
        category: _selectedCategory,
        date: DateTime.now(),
        exercises: exercises,
      );

      widget.onSave(newWorkout);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.categoryColors[_selectedCategory] ?? AppTheme.accent;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Log Strength Workout',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),

                // Workout Name
                Text(
                  'Workout Routine Name',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Legs Killer, Heavy Chest',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: themeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Category Selection
                Text(
                  'Muscle Group Focus',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1E293B),
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: themeColor),
                    ),
                  ),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.categoryColors[cat],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onCategoryChanged,
                ),
                const SizedBox(height: 24),

                // Exercises Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exercises & Weights',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addNewExerciseRow,
                      icon: Icon(Icons.add_rounded, color: themeColor, size: 18),
                      label: Text(
                        'Add Exercise',
                        style: GoogleFonts.inter(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Exercise Dynamic Rows
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _nameControllers.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Exercise Name
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _nameControllers[idx],
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Exercise',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: themeColor),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Weight (kg)
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _weightControllers[idx],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Wt (kg)',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: themeColor),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Required';
                                }
                                final w = double.tryParse(val);
                                if (w == null || w <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Reps
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _repsControllers[idx],
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Reps',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: themeColor),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Required';
                                }
                                final r = int.tryParse(val);
                                if (r == null || r <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),

                          // Remove Row Button
                          if (_nameControllers.length > 1)
                            IconButton(
                              onPressed: () => _removeExerciseRow(idx),
                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                              padding: const EdgeInsets.only(top: 12, left: 4),
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: const Color(0xFF0F172A),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Workout Log',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
