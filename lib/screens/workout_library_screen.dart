import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

import 'active_workout_screen.dart';

class WorkoutLibraryScreen extends StatelessWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> workouts = [
      {
        'title': '15-Min Core Blast',
        'duration': '15 mins',
        'level': 'Beginner',
        'image': Icons.fitness_center_rounded,
        'color': AppTheme.neonPink,
      },
      {
        'title': 'HIIT Cardio Burn',
        'duration': '30 mins',
        'level': 'Advanced',
        'image': Icons.directions_run_rounded,
        'color': AppTheme.accent,
      },
      {
        'title': 'Morning Yoga Flow',
        'duration': '20 mins',
        'level': 'All Levels',
        'image': Icons.self_improvement_rounded,
        'color': AppTheme.neonCyan,
      },
      {
        'title': 'Upper Body Strength',
        'duration': '45 mins',
        'level': 'Intermediate',
        'image': Icons.fitness_center_rounded,
        'color': Colors.orange,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Workout Library',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          final workout = workouts[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              boxShadow: AppTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: AppTheme.cardRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final String title = workout['title'] as String;
                    final IconData icon = workout['image'] as IconData;
                    final Color color = workout['color'] as Color;
                    
                    int avgPace = 360;
                    int kcalPerKm = 100;
                    if (title.contains('Core')) {
                      avgPace = 480;
                      kcalPerKm = 120;
                    } else if (title.contains('HIIT') || title.contains('Cardio')) {
                      avgPace = 300;
                      kcalPerKm = 150;
                    } else if (title.contains('Yoga')) {
                      avgPace = 600;
                      kcalPerKm = 80;
                    } else if (title.contains('Strength') || title.contains('Upper')) {
                      avgPace = 420;
                      kcalPerKm = 135;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveWorkoutScreen(
                          activityType: title,
                          icon: icon,
                          color: color,
                          avgPaceSeconds: avgPace,
                          kcalPerKm: kcalPerKm,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        color: workout['color'].withOpacity(0.1),
                        child: Icon(
                          workout['image'],
                          size: 40,
                          color: workout['color'],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout['title'],
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Text(
                                    workout['duration'],
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.signal_cellular_alt_rounded, size: 14, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Text(
                                    workout['level'],
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Icon(Icons.play_circle_fill_rounded, color: AppTheme.accent, size: 36),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
