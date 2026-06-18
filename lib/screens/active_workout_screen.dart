import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // State variables that can be mutated
  late String _activityType;
  late IconData _icon;
  late Color _color;
  late int _avgPaceSeconds;
  late int _kcalPerKm;

  // Geolocator variables
  bool _isMockSimulation = false;
  Position? _lastPosition;
  double? _startLatitude;
  double? _startLongitude;
  double _speedKmH = 0.0;
  bool _isSpeedLimitAlertShowing = false;
  StreamSubscription<Position>? _gpsSubscription;
  bool _simulateSpeeding = false;

  @override
  void initState() {
    super.initState();
    _activityType = widget.activityType;
    _icon = widget.icon;
    _color = widget.color;
    _avgPaceSeconds = widget.avgPaceSeconds;
    _kcalPerKm = widget.kcalPerKm;
    _currentPaceSeconds = widget.avgPaceSeconds;
    
    // Initialize starting route point in center of screen coordinates
    _routePoints.add(const Offset(150, 150));

    // Request permissions and initialize GPS stream
    _initGPSTracking();

    // Setup active duration timer (ticks every second)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        if (_isMockSimulation) {
          _runMockSimulationStep();
        }
      });
      // Check speed limit status periodically
      if (_secondsElapsed % 2 == 0) {
        _checkSpeedLimit();
      }
    });
  }

  Future<void> _initGPSTracking() async {
    // Check and request location permission using permission_handler
    final status = await Permission.location.request();
    
    if (status.isGranted) {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint("Location services are disabled.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable location services to track workouts.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // meters
      );

      _gpsSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        if (!mounted) return;
        setState(() {
          _handleNewPosition(position);
        });
      }, onError: (error) {
        debugPrint("Geolocator stream error: $error.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPS Signal Error: $error')),
          );
        }
      });
    } else {
      debugPrint("Location permission denied.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to track active workouts.')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _handleNewPosition(Position position) {
    if (_simulateSpeeding) {
      _speedKmH = 45.0;
    } else {
      _speedKmH = position.speed * 3.6;
      if (_speedKmH < 0.0) _speedKmH = 0.0;
    }

    if (_lastPosition == null) {
      _startLatitude = position.latitude;
      _startLongitude = position.longitude;
      _lastPosition = position;
    } else {
      final double distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      _distance += distanceInMeters / 1000.0;
      _calories = (_distance * _kcalPerKm).toInt();
      _lastPosition = position;

      if (_speedKmH > 0.5) {
        _currentPaceSeconds = (3600.0 / _speedKmH).round().clamp(120, 1200);
      } else {
        _currentPaceSeconds = _avgPaceSeconds;
      }

      if (_startLatitude != null && _startLongitude != null) {
        final double dx = (position.longitude - _startLongitude!) * 90000.0;
        final double dy = -(position.latitude - _startLatitude!) * 90000.0;
        final double px = (150.0 + dx).clamp(20.0, 280.0);
        final double py = (150.0 + dy).clamp(20.0, 280.0);
        _routePoints.add(Offset(px, py));
      }
    }
  }

  void _runMockSimulationStep() {
    if (_simulateSpeeding) {
      _speedKmH = 45.0;
      _currentPaceSeconds = (3600.0 / _speedKmH).round().clamp(120, 1200);
      _distance += (_speedKmH / 3600.0);
      _calories = (_distance * _kcalPerKm).toInt();
    } else {
      _distance = _secondsElapsed / _avgPaceSeconds;
      _calories = (_distance * _kcalPerKm).toInt();

      if (_secondsElapsed % 5 == 0) {
        final fluctuation = _random.nextInt(31) - 15;
        _currentPaceSeconds = (_avgPaceSeconds + fluctuation).clamp(120, 1200);
        _speedKmH = 3600.0 / _currentPaceSeconds;
      }
    }

    if (_secondsElapsed % 2 == 0) {
      final Offset lastPt = _routePoints.last;
      double dxDir = math.sin(_secondsElapsed * 0.05) * 8;
      double dyDir = math.cos(_secondsElapsed * 0.03) * 8;
      dxDir += (_random.nextDouble() - 0.5) * 5;
      dyDir += (_random.nextDouble() - 0.5) * 5;
      final nextPt = Offset(
        (lastPt.dx + dxDir).clamp(20.0, 280.0),
        (lastPt.dy + dyDir).clamp(20.0, 280.0),
      );
      _routePoints.add(nextPt);
    }
  }

  void _checkSpeedLimit() {
    if (_isSpeedLimitAlertShowing) return;

    double limit = 7.5;
    if (_activityType.toLowerCase() == 'running') {
      limit = 18.0;
    } else if (_activityType.toLowerCase() == 'cycling') {
      limit = 35.0;
    }

    if (_speedKmH > limit) {
      _isSpeedLimitAlertShowing = true;
      _showSpeedLimitDialog();
    }
  }

  void _showSpeedLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _color.withOpacity(0.4), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              const SizedBox(width: 8),
              Text(
                "Speed Limit Exceeded",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You are exceeding the limit! Currently moving at ${_speedKmH.toStringAsFixed(1)} km/h.",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Please confirm if you are running or cycling so we can track your activity accurately:",
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActivityOptionButton(
                  context: context,
                  name: 'Walking',
                  icon: Icons.directions_walk_rounded,
                  color: AppTheme.neonCyan,
                  pace: '10:00',
                  kcal: 60,
                ),
                const SizedBox(height: 8),
                _buildActivityOptionButton(
                  context: context,
                  name: 'Running',
                  icon: Icons.directions_run_rounded,
                  color: AppTheme.neonPink,
                  pace: '5:30',
                  kcal: 75,
                ),
                const SizedBox(height: 8),
                _buildActivityOptionButton(
                  context: context,
                  name: 'Cycling',
                  icon: Icons.directions_bike_rounded,
                  color: AppTheme.neonEmerald,
                  pace: '2:45',
                  kcal: 50,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSpeedLimitAlertShowing = false;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "Ignore Warning",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityOptionButton({
    required BuildContext context,
    required String name,
    required IconData icon,
    required Color color,
    required String pace,
    required int kcal,
  }) {
    final isCurrent = _activityType.toLowerCase() == name.toLowerCase();
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isCurrent ? color.withOpacity(0.15) : Colors.transparent,
        side: BorderSide(
          color: isCurrent ? color : Colors.white24,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: () {
        setState(() {
          _activityType = name;
          _icon = icon;
          _color = color;
          _avgPaceSeconds = _parsePaceString(pace);
          _kcalPerKm = kcal;
          _isSpeedLimitAlertShowing = false;
        });
        Navigator.of(context).pop();
      },
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Est. Pace: $pace/km • $kcal kcal/km",
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
        ],
      ),
    );
  }

  int _parsePaceString(String pace) {
    final parts = pace.split(':');
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return (minutes * 60) + seconds;
  }

  @override
  void dispose() {
    _timer.cancel();
    _gpsSubscription?.cancel();
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
    _gpsSubscription?.cancel();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityReportScreen(
          activityType: _activityType,
          distance: _distance,
          durationSeconds: _secondsElapsed,
          calories: _calories,
          avgPace: _formatPace(_avgPaceSeconds),
          routePoints: _routePoints,
          themeColor: _color,
          icon: _icon,
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
                        Icon(_icon, color: _color, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _activityType.toUpperCase(),
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
                              pathColor: _color,
                            ),
                          ),
                        ),
                        // Overlay HUD instructions (Signal strength & Current speed)
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
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
                                      'GPS: ACTIVE (98%)',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.speed_rounded, color: Colors.amberAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SPEED: ${_speedKmH.toStringAsFixed(1)} KM/H',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox.shrink(),
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
