import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'activity_report_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String activityType;
  final IconData icon;
  final Color color;
  final int avgPaceSeconds;
  final int kcalPerKm;

  const ActiveWorkoutScreen({
    super.key,
    required this.activityType,
    required this.icon,
    required this.color,
    required this.avgPaceSeconds,
    required this.kcalPerKm,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late Timer _timer;
  int _secondsElapsed = 0;
  double _distance = 0.0; // km
  int _calories = 0;
  int _currentPaceSeconds = 0;
  
  final List<Offset> _routePoints = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _currentPaceSeconds = widget.avgPaceSeconds;
    
    // Initialize starting route point in center of screen coordinates
    _routePoints.add(const Offset(150, 150));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        
        // Accumulate distance realistically
        // distance (km) = elapsed seconds / pace per km
        _distance = _secondsElapsed / widget.avgPaceSeconds;
        
        // Estimate calories
        _calories = (_distance * widget.kcalPerKm).toInt();

        // Introduce minor pace fluctuations for high fidelity feel
        if (_secondsElapsed % 5 == 0) {
          final fluctuation = _random.nextInt(31) - 15; // ±15 seconds
          _currentPaceSeconds = (widget.avgPaceSeconds + fluctuation).clamp(120, 1200);
        }

        // Add coordinate trace every 2 seconds
        if (_secondsElapsed % 2 == 0) {
          final Offset lastPt = _routePoints.last;
          
          // Generate a semi-random walking path (Brownian motion style with velocity direction bias)
          double dxDir = math.sin(_secondsElapsed * 0.05) * 8;
          double dyDir = math.cos(_secondsElapsed * 0.03) * 8;
          
          // Add random jitter
          dxDir += (_random.nextDouble() - 0.5) * 5;
          dyDir += (_random.nextDouble() - 0.5) * 5;
          
          // Constrain coordinates to stay inside the view screen limits
          final nextPt = Offset(
            (lastPt.dx + dxDir).clamp(20.0, 280.0),
            (lastPt.dy + dyDir).clamp(20.0, 280.0),
          );
          _routePoints.add(nextPt);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  String _formatPace(int paceSeconds) {
    final int minutes = paceSeconds ~/ 60;
    final int seconds = paceSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  void _finishWorkout() {
    _timer.cancel();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityReportScreen(
          activityType: widget.activityType,
          distance: _distance,
          durationSeconds: _secondsElapsed,
          calories: _calories,
          avgPace: _formatPace(widget.avgPaceSeconds),
          routePoints: _routePoints,
          themeColor: widget.color,
          icon: widget.icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium dark theme for athletic tracking focus
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(widget.icon, color: widget.color, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          widget.activityType.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE GPS',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Main metrics panel (Glassmorphic)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatDuration(_secondsElapsed),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'DURATION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSubMetric(
                          val: _distance.toStringAsFixed(2),
                          unit: 'km',
                          label: 'DISTANCE',
                        ),
                        Container(width: 1.5, height: 40, color: Colors.white10),
                        _buildSubMetric(
                          val: _formatPace(_currentPaceSeconds),
                          unit: '/km',
                          label: 'CURRENT PACE',
                        ),
                        Container(width: 1.5, height: 40, color: Colors.white10),
                        _buildSubMetric(
                          val: '$_calories',
                          unit: 'kcal',
                          label: 'CALORIES',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dynamic Route Draw Canvas (Futuristic blueprint display)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: AppTheme.cardRadius,
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: AppTheme.cardRadius,
                    child: Stack(
                      children: [
                        // Custom vector canvas painter
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RoutePainter(
                              points: _routePoints,
                              pathColor: widget.color,
                            ),
                          ),
                        ),
                        // Overlay HUD instructions
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.satellite_alt_rounded, color: Colors.cyanAccent, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'SIGNAL STRENGTH: 98%',
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // End Activity Button
              GestureDetector(
                onTap: _finishWorkout,
                child: Container(
                  height: 62,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'End Workout & Generate Report',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubMetric({required String val, required String unit, required String label}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: Colors.white38,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<Offset> points;
  final Color pathColor;

  _RoutePainter({required this.points, required this.pathColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    // 1. Draw Blueprint grid lines
    const double gridSize = 30.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    if (points.isEmpty) return;

    // 2. Draw route path
    final routePaint = Paint()
      ..color = pathColor
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = pathColor.withOpacity(0.45)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw glowing blur shadow first, then the solid path line
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, routePaint);

    // 3. Draw start point marker (green dot)
    final startPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.first, 8, startPaint);
    
    final startPulsePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.first, 12, startPulsePaint);

    // 4. Draw current end point pulse marker (pulse rings)
    final endPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final endBorderPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 8, endBorderPaint);
    canvas.drawCircle(points.last, 5, endPaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
