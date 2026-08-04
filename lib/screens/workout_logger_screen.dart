import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

import '../data/exercise_database.dart';
import '../services/api_service.dart';

class WorkoutLoggerScreen extends StatefulWidget {
  const WorkoutLoggerScreen({super.key});

  @override
  State<WorkoutLoggerScreen> createState() => _WorkoutLoggerScreenState();
}

class _WorkoutLoggerScreenState extends State<WorkoutLoggerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _searchResults = [];
  bool _isSearching = false;
  late TabController _tabController;

  // Local state for Recent and Favorites (In a real app, this would be persisted or fetched)
  final List<Exercise> _favorites = [];
  final List<Exercise> _recent = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Populate some initial recent for demo
    _recent.addAll(ExerciseDatabase.exercises.take(3));
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchResults = ExerciseDatabase.searchExercises(query);
    });
  }

  void _openExerciseLogger(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseLoggerSheet(
        exercise: exercise,
        onSave: (Map<String, dynamic> data) async {
          Navigator.pop(context); // Close sheet
          _logWorkoutToApi(exercise, data);
        },
      ),
    );
  }

  Future<void> _logWorkoutToApi(Exercise exercise, Map<String, dynamic> data) async {
    // Optimistic UI updates
    if (!_recent.contains(exercise)) {
      setState(() {
        _recent.insert(0, exercise);
        if (_recent.length > 10) _recent.removeLast();
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saving ${exercise.name}...', style: GoogleFonts.inter()),
        backgroundColor: AppTheme.accent,
        duration: const Duration(seconds: 1),
      ),
    );

    if (!ApiService.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save workouts.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Convert to backend schema exercise structure
    final List<Map<String, dynamic>> exercisesList = [
      {
        "name": exercise.name,
        "sets": (data['sets'] as num?)?.toInt() ?? 1,
        "reps": data['reps']?.toString() ?? "10",
        "weight": (data['weight'] as num?)?.toDouble() ?? 0.0,
        "duration_seconds": (data['duration_seconds'] as num?)?.toInt() ?? 0,
        "notes": data['notes']?.toString() ?? ""
      }
    ];

    try {
      final res = await ApiService.saveStrengthWorkout(
        workoutName: "Quick Log: ${exercise.name}",
        category: exercise.category,
        exercises: exercisesList,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${exercise.name} logged successfully!', style: GoogleFonts.inter()),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to log workout.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFavorite(Exercise exercise) {
    setState(() {
      if (_favorites.contains(exercise)) {
        _favorites.remove(exercise);
      } else {
        _favorites.add(exercise);
      }
    });
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        final isFav = _favorites.contains(ex);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.cardRadius,
            boxShadow: AppTheme.cardShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              ex.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            subtitle: Text(
              ex.primaryMuscle,
              style: GoogleFonts.inter(color: Colors.black45, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFav ? Colors.amber : Colors.black26,
                  ),
                  onPressed: () => _toggleFavorite(ex),
                ),
                const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accent),
              ],
            ),
            onTap: () => _openExerciseLogger(ex),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView(String category) {
    final list = ExerciseDatabase.exercises.where((e) => e.category == category).toList();
    return _buildExerciseList(list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Log Workout',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: GoogleFonts.inter(color: Colors.black38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isSearching
          ? _buildExerciseList(_searchResults)
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.accent,
                  unselectedLabelColor: Colors.black45,
                  indicatorColor: AppTheme.accent,
                  tabs: const [
                    Tab(text: 'Weight 🏋️'),
                    Tab(text: 'Body 🤸'),
                    Tab(text: 'Time ⏱️'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryView('Weight'),
                      _buildCategoryView('Bodyweight'),
                      _buildCategoryView('Timed'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------
// Bottom Sheet for Logging
// ---------------------------------------------------------
class _ExerciseLoggerSheet extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic>) onSave;

  const _ExerciseLoggerSheet({required this.exercise, required this.onSave});

  @override
  State<_ExerciseLoggerSheet> createState() => _ExerciseLoggerSheetState();
}

class _ExerciseLoggerSheetState extends State<_ExerciseLoggerSheet> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: "1");
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bool isWeight = widget.exercise.measurementType == MeasurementType.weightReps;
    final bool isTime = widget.exercise.measurementType == MeasurementType.time;
    final bool isBodyweight = widget.exercise.measurementType == MeasurementType.bodyweightReps;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Avoid keyboard
        left: 20, right: 20, top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.exercise.name,
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            
            // Dynamic Inputs based on type
            if (isWeight) ...[
              _buildInputRow('Weight (kg/lb)', _weightController, isNumber: true),
              const SizedBox(height: 12),
            ],
            
            if (isTime) ...[
              _buildInputRow('Duration (Seconds)', _durationController, isNumber: true),
              const SizedBox(height: 12),
            ],

            _buildInputRow('Sets', _setsController, isNumber: true),
            const SizedBox(height: 12),

            if (isWeight || isBodyweight) ...[
              _buildInputRow('Reps', _repsController, isNumber: true),
              const SizedBox(height: 12),
            ],

            _buildInputRow('Notes (Optional)', _notesController, isNumber: false),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  final data = <String, dynamic>{
                    'sets': int.tryParse(_setsController.text) ?? 1,
                    'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
                  };
                  if (isWeight) data['weight'] = double.tryParse(_weightController.text);
                  if (isWeight || isBodyweight) data['reps'] = int.tryParse(_repsController.text);
                  if (isTime) data['duration_seconds'] = int.tryParse(_durationController.text);
                  
                  widget.onSave(data);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller, {required bool isNumber}) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
        Expanded(
          flex: 3,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
            ),
          ),
        ),
      ],
    );
  }
}
