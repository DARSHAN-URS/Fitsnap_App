import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/sabtrack_logo.dart';
import '../widgets/transparent_report_widget.dart';
import '../services/api_service.dart';
import '../utils/share_helper.dart';
import '../utils/preferences_helper.dart';
import 'export_studio_screen.dart';


class ActivityReportScreen extends StatefulWidget {
  final String activityType;
  final double distance;
  final int durationSeconds;
  final int calories;
  final String avgPace;
  final List<Offset> routePoints;
  final Color themeColor;
  final IconData icon;

  const ActivityReportScreen({
    super.key,
    required this.activityType,
    required this.distance,
    required this.durationSeconds,
    required this.calories,
    required this.avgPace,
    required this.routePoints,
    required this.themeColor,
    required this.icon,
  });

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  String _displayName = 'Darshan Urs';
  String? _profilePicUrl;
  double _profileHeight = 175.0;
  double _profileWeight = 75.0;
  String _profileAge = '25';
  String _profileGoal = 'Build Muscle';
  bool _isSaving = false;
  bool _transparentOverlay = false; // controls layout for export
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final name = await PreferencesHelper.readString('profile_name') ?? 'Darshan Urs';
    final picUrl = await PreferencesHelper.readString('profile_pic_url');
    final height = await PreferencesHelper.readDouble('profile_height') ?? 175.0;
    final weight = await PreferencesHelper.readDouble('profile_weight') ?? 75.0;
    
    String age = '25';
    final ageVal = await PreferencesHelper.readInt('profile_age');
    if (ageVal != null) {
      age = ageVal.toString();
    } else {
      final ageStr = await PreferencesHelper.readString('profile_age');
      if (ageStr != null) age = ageStr;
    }
    
    final goal = await PreferencesHelper.readString('profile_goal') ?? 'Build Muscle';

    if (mounted) {
      setState(() {
        _displayName = name;
        _profilePicUrl = picUrl;
        _profileHeight = height;
        _profileWeight = weight;
        _profileAge = age;
        _profileGoal = goal;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    }
    return "${minutes}m ${seconds}s";
  }

  Future<void> _saveWorkoutData() async {
    setState(() => _isSaving = true);

    int stepsToAdd = 0;
    if (widget.activityType.toLowerCase() != 'cycling') {
      stepsToAdd = (widget.distance * 1250).toInt();
    }

    final prefs = await SharedPreferences.getInstance();
    
    final int currentSteps = prefs.getInt('home_steps') ?? 6420;
    final newSteps = currentSteps + stepsToAdd;
    await prefs.setInt('home_steps', newSteps);

    // Sync stats and save workout to backend
    if (ApiService.isAuthenticated) {
      // Sync steps to backend daily stats
      final water = prefs.getInt('home_water') ?? 0;
      await ApiService.updateDailyStats(steps: newSteps, waterMl: water);

      // Save workout
      final List<Map<String, double>> pointsList = widget.routePoints.map((pt) {
        return {'x': pt.dx, 'y': pt.dy};
      }).toList();

      final res = await ApiService.saveWorkout(
        workoutName: widget.activityType,
        distance: widget.distance,
        durationSeconds: widget.durationSeconds,
        calories: widget.calories,
        routePoints: pointsList,
      );
      if (!res['success']) {
        debugPrint('Failed to save workout to backend: ${res['error']}');
      }
    }

    // Log the workout in local storage as a cache fallback
    final List<String> workouts = prefs.getStringList('workout_history') ?? [];
    final workoutStr = "${widget.activityType}|${widget.distance.toStringAsFixed(2)}|${widget.durationSeconds}|${widget.calories}|${DateTime.now().toIso8601String()}";
    workouts.add(workoutStr);
    await prefs.setStringList('workout_history', workouts);

    setState(() => _isSaving = false);

    // Show success dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Workout Saved!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.activityType == 'Cycling'
                    ? 'Recorded activity and updated active calorie burn metrics.'
                    : 'Log added: +${stepsToAdd.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")} steps recorded to your activity history.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.black45, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // return to Home tab
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Go to Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareReal() async {
    await ShareHelper.shareWidgetCapture(_repaintKey, 'Just completed a great ${widget.activityType} workout on Sabtrack AI! 🚀');
  }

  void _showShareOverlay(String platform) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.themeColor, size: 24),
              ),
              const SizedBox(height: 18),
              Text(
                'Sharing to $platform',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generating high-definition card layout overlays with blueprint GPS path vectors...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.black45, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(color: AppTheme.accent),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );

    // Simulate completion and share via OS
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pop(context); // close progress overlay
      _shareReal();
    });
  }

  // Export dialog and handling
  void _showExportDialog() {
    final dataMap = {
      'date': 'Workout Summary',
      'steps': 0,
      'calorieBurned': widget.calories,
      'waterMl': 0,
      'calorieIntake': 0,
      'recoveryScore': 85, // optimal defaults
      'strainScore': 14.8,
      'aiSummary': "Great aerobic performance! Your average pace of ${widget.avgPace} shows strong cardiovascular output.",
      'activityType': widget.activityType,
      'distance': '${widget.distance.toStringAsFixed(2)} km',
      'pace': '${widget.avgPace} /km',
      'duration': _formatDuration(widget.durationSeconds),
    };
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportStudioScreen(
          type: ExportType.workout,
          data: dataMap,
        ),
      ),
    );
  }

  Future<void> _exportReport(bool transparent) async {
    setState(() { _transparentOverlay = transparent; });
    await Future.delayed(const Duration(milliseconds: 200)); // allow UI update
    final fileName = 'Workout_${DateTime.now().millisecondsSinceEpoch}';
    final path = await ShareHelper.saveWidgetCapture(_repaintKey, fileName: fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path != null ? 'Report saved to $path' : 'Failed to save report')),
      );
    }
    setState(() { _transparentOverlay = false; });
  }

  @override
  Widget build(BuildContext context) {
    final String initials = _displayName.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Workout Summary',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 48),
        child: Column(
          children: [
            // Shareable card layout
            RepaintBoundary(
              key: _repaintKey,
              child: _transparentOverlay
                  ? TransparentReportWidget(
                      child: Card(
                      elevation: 8,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                      decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    )
                      )
                    )
                  : Card(
                      elevation: 8,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                      decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                  children: [
                    // Header (User Profile metadata)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: _profilePicUrl == null
                                  ? LinearGradient(
                                      colors: [widget.themeColor, widget.themeColor.withOpacity(0.5)],
                                    )
                                  : null,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1.5),
                              image: _profilePicUrl != null
                                  ? DecorationImage(
                                      image: _profilePicUrl!.startsWith('http')
                                          ? CachedNetworkImageProvider(_profilePicUrl!)
                                          : FileImage(File(_profilePicUrl!)) as ImageProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profilePicUrl == null
                                ? Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SabTrack Elite Athlete • $_profileAge y/o • ${_profileHeight.toInt()}cm • ${_profileWeight.toInt()}kg',
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Goal: $_profileGoal',
                                  style: GoogleFonts.inter(
                                    color: widget.themeColor.withOpacity(0.9),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(widget.icon, color: widget.themeColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  widget.activityType,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map overlay box
                    Container(
                      height: 240,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _ReportRoutePainter(
                            points: widget.routePoints,
                            pathColor: widget.themeColor,
                          ),
                        ),
                      ),
                    ),

                    // Workout metrics section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem('DISTANCE', widget.distance.toStringAsFixed(2), 'km'),
                              _buildMetricItem('DURATION', _formatDuration(widget.durationSeconds), ''),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem('AVG PACE', widget.avgPace, '/km'),
                              _buildMetricItem('ENERGY', '${widget.calories}', 'kcal'),
                            ],
                          ),
                          const Divider(height: 36, thickness: 1, color: Colors.white10),
                          
                          // Watermark branding
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SabtrackLogo(
                                    size: 20,
                                    color: widget.themeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SABTRACK',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Sabtrack AI companion',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                  ),
                  ),
            ),
            const SizedBox(height: 28),

            // Share section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Share Your Workout',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Share buttons row
            Row(
              children: [
                _buildShareCard(
                  name: 'Share Image',
                  logo: const ShareImageLogo(size: 28),
                  onTap: () => _showShareOverlay('Social Media'),
                ),
                const SizedBox(width: 12),
                _buildShareCard(
                  name: 'WhatsApp',
                  logo: const WhatsAppLogo(size: 28),
                  onTap: () => _showShareOverlay('WhatsApp'),
                ),
                const SizedBox(width: 12),
                _buildShareCard(
                  name: 'Instagram',
                  logo: const InstagramLogo(size: 28),
                  onTap: () => _showShareOverlay('Instagram Story'),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Save Activity button
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWorkoutData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Save Workout to Dashboard',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showExportDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Export Report'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Discard Activity',
                style: GoogleFonts.inter(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard({
    required String name,
    required Widget logo,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: Colors.black.withOpacity(0.02), width: 1),
          ),
          child: Column(
            children: [
              logo,
              const SizedBox(height: 6),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String val, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty) const SizedBox(width: 2),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReportRoutePainter extends CustomPainter {
  final List<Offset> points;
  final Color pathColor;

  _ReportRoutePainter({required this.points, required this.pathColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Blueprint map grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1.0;
    const double gridSize = 25.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    if (points.isEmpty) return;

    // To center the map path properly on report, we find min/max values
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (var pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    final pathW = maxX - minX;
    final pathH = maxY - minY;
    
    // Scale and shift factors to fit coordinate points inside size.width - 40, size.height - 40
    const double pad = 40.0;
    final double targetW = size.width - pad * 2;
    final double targetH = size.height - pad * 2;

    double scale = 1.0;
    if (pathW > 0 && pathH > 0) {
      scale = math.min(targetW / pathW, targetH / pathH);
    }
    
    // Calculate center adjustments
    final double shiftX = pad + (targetW - pathW * scale) / 2 - minX * scale;
    final double shiftY = pad + (targetH - pathH * scale) / 2 - minY * scale;

    final List<Offset> scaledPoints = points.map((pt) {
      return Offset(pt.dx * scale + shiftX, pt.dy * scale + shiftY);
    }).toList();

    // Draw route path
    final routePaint = Paint()
      ..color = pathColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = pathColor.withOpacity(0.4)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    for (int i = 1; i < scaledPoints.length; i++) {
      path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, routePaint);

    // Draw start marker (green dot)
    final startPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(scaledPoints.first, 6, startPaint);

    // Draw end marker (solid circle)
    final endPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final endBorderPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(scaledPoints.last, 6, endBorderPaint);
    canvas.drawCircle(scaledPoints.last, 3, endPaint);
  }

  @override
  bool shouldRepaint(covariant _ReportRoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}

class ShareImageLogo extends StatelessWidget {
  final double size;
  const ShareImageLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background photo card
          Positioned(
            left: size * 0.05,
            bottom: size * 0.05,
            child: Container(
              width: size * 0.78,
              height: size * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(size * 0.15),
                border: Border.all(color: AppTheme.accent, width: size * 0.05),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: AppTheme.accent,
                  size: size * 0.45,
                ),
              ),
            ),
          ),
          // Share arrow overlay at top-right
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(size * 0.05),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.reply_rounded,
                color: Colors.white,
                size: size * 0.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WhatsAppLogo extends StatelessWidget {
  final double size;
  const WhatsAppLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppSpeechBubblePainter(),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.04, right: size * 0.02),
            child: Icon(
              Icons.call,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppSpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final double r = w * 0.42;

    final paint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill;

    // Draw main circle
    canvas.drawCircle(center, r, paint);

    // Draw bottom-left speech tail
    final tailPath = Path();
    final double angle1 = 0.65 * math.pi;
    final double angle2 = 0.88 * math.pi;
    final double angleMid = 0.77 * math.pi;

    tailPath.moveTo(w / 2 + r * math.cos(angle1), h / 2 + r * math.sin(angle1));
    tailPath.lineTo(w / 2 + r * 1.35 * math.cos(angleMid), h / 2 + r * 1.35 * math.sin(angleMid));
    tailPath.lineTo(w / 2 + r * math.cos(angle2), h / 2 + r * math.sin(angle2));
    tailPath.close();

    canvas.drawPath(tailPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InstagramLogo extends StatelessWidget {
  final double size;
  const InstagramLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const RadialGradient(
          center: Alignment(-0.6, 0.9),
          radius: 1.2,
          colors: [
            Color(0xFFFEE140),
            Color(0xFFFA709A),
            Color(0xFFE1306C),
            Color(0xFFC13584),
            Color(0xFF833AB4),
            Color(0xFF405DE6),
          ],
          stops: [0.0, 0.25, 0.5, 0.65, 0.85, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.75,
          height: size * 0.75,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: size * 0.08),
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: size * 0.08),
                ),
              ),
              Positioned(
                top: size * 0.05,
                right: size * 0.05,
                child: Container(
                  width: size * 0.08,
                  height: size * 0.08,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
