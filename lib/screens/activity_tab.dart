import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'activity_tracker_screen.dart';

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  List<Map<String, dynamic>> _workoutHistory = [];
  bool _isLoading = true;

  double _totalDistance = 0.0;
  int _totalCalories = 0;
  int _totalDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadWorkoutHistory();
  }

  Future<void> _loadWorkoutHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    double tempDistance = 0.0;
    int tempCalories = 0;
    int tempDuration = 0;
    List<Map<String, dynamic>> parsedHistory = [];

    if (ApiService.isAuthenticated) {
      final res = await ApiService.getWorkouts();
      if (res['success']) {
        final List<dynamic> serverWorkouts = res['data'];
        for (var w in serverWorkouts) {
          final String type = w['workout_name'] ?? 'Workout';
          final double dist = (w['distance'] as num?)?.toDouble() ?? 0.0;
          final int dur = (w['duration_seconds'] as num?)?.toInt() ?? 0;
          final int cal = (w['calories'] as num?)?.toInt() ?? 0;
          final String dateStr = w['completed_at'] ?? DateTime.now().toIso8601String();

          tempDistance += dist;
          tempCalories += cal;
          tempDuration += dur;

          parsedHistory.add({
            'type': type,
            'distance': dist,
            'durationSeconds': dur,
            'calories': cal,
            'date': DateTime.tryParse(dateStr) ?? DateTime.now(),
          });
        }
      }
    }

    if (parsedHistory.isEmpty) {
      final List<String> rawWorkouts = prefs.getStringList('workout_history') ?? [];
      for (var raw in rawWorkouts.reversed) {
        final parts = raw.split('|');
        if (parts.length >= 4) {
          final String type = parts[0];
          final double dist = double.tryParse(parts[1]) ?? 0.0;
          final int dur = int.tryParse(parts[2]) ?? 0;
          final int cal = int.tryParse(parts[3]) ?? 0;
          final String dateStr = parts.length > 4 ? parts[4] : DateTime.now().toIso8601String();
          
          tempDistance += dist;
          tempCalories += cal;
          tempDuration += dur;

          parsedHistory.add({
            'type': type,
            'distance': dist,
            'durationSeconds': dur,
            'calories': cal,
            'date': DateTime.tryParse(dateStr) ?? DateTime.now(),
          });
        }
      }
    }

    setState(() {
      _workoutHistory = parsedHistory;
      _totalDistance = tempDistance;
      _totalCalories = tempCalories;
      _totalDurationSeconds = tempDuration;
      _isLoading = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt).inDays;

    if (difference == 0) {
      return "Today";
    } else if (difference == 1) {
      return "Yesterday";
    } else {
      final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dt.month - 1]} ${dt.day}";
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
      default:
        return Icons.directions_walk_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return AppTheme.neonPink;
      case 'cycling':
        return AppTheme.neonEmerald;
      case 'walking':
      default:
        return AppTheme.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -1,
                ),
              ),
              GestureDetector(
                onTap: _loadWorkoutHistory,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Start live workout launcher card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppTheme.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ready to Track',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.insights_rounded,
                      color: AppTheme.accentLight,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Record Your Next Run or Ride',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Analyze GPS routes, real-time pace, and live active energy burn metrics.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ActivityTrackerScreen(),
                      ),
                    ).then((_) => _loadWorkoutHistory());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
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
                      const Icon(Icons.play_arrow_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Start Live Workout',
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

          // Stats Overview Cards
          Text(
            'Weekly Statistics',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Distance',
                  val: '${_totalDistance.toStringAsFixed(1)} km',
                  icon: Icons.map_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Duration',
                  val: _formatDuration(_totalDurationSeconds),
                  icon: Icons.timer_outlined,
                  color: AppTheme.neonPink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Burned',
                  val: '$_totalCalories kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: AppTheme.neonAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Workout history header
          Text(
            'Workout History',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_workoutHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_run_rounded, color: Colors.grey.shade300, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No workouts recorded yet',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete a live workout session to see it here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workoutHistory.length,
              itemBuilder: (context, index) {
                final workout = _workoutHistory[index];
                final type = workout['type'] as String;
                final distance = workout['distance'] as double;
                final duration = workout['durationSeconds'] as int;
                final calories = workout['calories'] as int;
                final date = workout['date'] as DateTime;

                final IconData icon = _getActivityIcon(type);
                final Color themeColor = _getActivityColor(type);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.cardRadius,
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: themeColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(duration)} • ${distance.toStringAsFixed(2)} km',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$calories kcal',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRelativeDate(date),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String val,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.black38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
