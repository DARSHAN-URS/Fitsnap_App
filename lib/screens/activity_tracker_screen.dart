import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';

class ActivityTrackerScreen extends StatefulWidget {
  const ActivityTrackerScreen({super.key});

  @override
  State<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends State<ActivityTrackerScreen> {
  String _selectedActivity = 'Running';

  final List<Map<String, dynamic>> _activities = [
    {
      'name': 'Walking',
      'icon': Icons.directions_walk_rounded,
      'desc': 'A relaxed stroll or active power walk to keep moving.',
      'color': AppTheme.neonCyan,
      'pace': '10:00', // min/km
      'kcalPerKm': 60,
    },
    {
      'name': 'Running',
      'icon': Icons.directions_run_rounded,
      'desc': 'High intensity cardio training to build endurance.',
      'color': AppTheme.neonPink,
      'pace': '5:30',
      'kcalPerKm': 75,
    },
    {
      'name': 'Cycling',
      'icon': Icons.directions_bike_rounded,
      'desc': 'Outdoor road ride or trail session for speed and power.',
      'color': AppTheme.neonEmerald,
      'pace': '2:45',
      'kcalPerKm': 50,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Start Activity',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Activity Type',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your activity to calibrate GPS stats and energy expenditure calculations.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Activity selector cards
            Column(
              children: _activities.map((activity) {
                final isSelected = _selectedActivity == activity['name'];
                final Color activeCol = activity['color'] as Color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.cardRadius,
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(
                      color: isSelected ? activeCol.withOpacity(0.5) : const Color(0xFFF1F5F9),
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppTheme.cardRadius,
                      onTap: () => setState(() => _selectedActivity = activity['name']),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: activeCol.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(activity['icon'], color: activeCol, size: 28),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['name'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activity['desc'],
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.speed_rounded, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Est. Pace: ${activity['pace']} /km',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${activity['kcalPerKm']} kcal/km',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.check_circle_rounded, color: activeCol, size: 24),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle_outlined, color: Colors.grey.shade300, size: 24),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            // Pulsing Start Activity Button
            Container(
              height: 58,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  final config = _activities.firstWhere((act) => act['name'] == _selectedActivity);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveWorkoutScreen(
                        activityType: _selectedActivity,
                        icon: config['icon'],
                        color: config['color'],
                        avgPaceSeconds: _parsePace(config['pace']),
                        kcalPerKm: config['kcalPerKm'],
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  'Start Live Workout',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _parsePace(String pace) {
    final parts = pace.split(':');
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return (minutes * 60) + seconds;
  }
}
