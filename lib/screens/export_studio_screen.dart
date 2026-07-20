import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/share_helper.dart';

enum ExportType { daily, workout }

class ExportStudioScreen extends StatefulWidget {
  final ExportType type;
  
  // Data maps to populate layouts
  final Map<String, dynamic> data;

  const ExportStudioScreen({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  State<ExportStudioScreen> createState() => _ExportStudioScreenState();
}

class _ExportStudioScreenState extends State<ExportStudioScreen> {
  // Key to capture layout
  final GlobalKey _repaintKey = GlobalKey();

  // Customization States
  String _layout = 'minimal'; // minimal, glass, rings, strava, whoop, oura, garmin, nutrition, sleep, hydration, ai, dashboard
  String _aspectRatio = 'square'; // square, story, post, landscape
  String _theme = 'dark'; // dark, light, glass, gradient, black
  Color _accentColor = AppTheme.accent;
  Color _textColor = Colors.white;
  double _cornerRadius = 24.0;
  double _glassOpacity = 0.2;
  bool _showLogo = true;
  String _customTitle = "Sabtrack AI Performance";
  String _backgroundType = "color"; // color, photo
  String _photoUrl = "https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=800";

  bool _isExporting = false;

  // Static list of layout presets
  final List<Map<String, String>> _layoutsList = [
    {'id': 'minimal', 'name': 'Minimal Stats', 'desc': 'Clean, large stats text'},
    {'id': 'glass', 'name': 'Glass Card', 'desc': 'Frosted premium glass blur'},
    {'id': 'rings', 'name': 'Apple Rings', 'desc': 'Concentric activity circles'},
    {'id': 'strava', 'name': 'Strava Overlay', 'desc': 'Athletic photo with stats overlay'},
    {'id': 'whoop', 'name': 'Whoop style', 'desc': 'Concentric strain & recovery dials'},
    {'id': 'oura', 'name': 'Oura style', 'desc': 'Readiness and sleep summary dials'},
    {'id': 'garmin', 'name': 'Garmin style', 'desc': 'Stats board with heart rate chart'},
    {'id': 'nutrition', 'name': 'Nutrition macro', 'desc': 'Macros rings progress tracker'},
    {'id': 'sleep', 'name': 'Sleep Timeline', 'desc': 'Sleep stages color horizontal bar'},
    {'id': 'hydration', 'name': 'Hydration bottle', 'desc': 'Liquid level bottle tracker'},
    {'id': 'ai', 'name': 'AI Coach insights', 'desc': 'Focus on generative feedback'},
    {'id': 'dashboard', 'name': 'Dashboard board', 'desc': 'All health metrics grid'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate some parameters based on theme
    _updateThemeColors();
  }

  void _updateThemeColors() {
    setState(() {
      if (_theme == 'light') {
        _textColor = const Color(0xFF0F172A);
      } else {
        _textColor = Colors.white;
      }
    });
  }

  double _getAspectRatioValue() {
    switch (_aspectRatio) {
      case 'story':
        return 9 / 16;
      case 'post':
        return 4 / 5;
      case 'landscape':
        return 16 / 9;
      case 'square':
      default:
        return 1 / 1;
    }
  }

  Size _getCanvasSize() {
    switch (_aspectRatio) {
      case 'story':
        return const Size(360, 640);
      case 'post':
        return const Size(360, 450);
      case 'landscape':
        return const Size(640, 360);
      case 'square':
      default:
        return const Size(360, 360);
    }
  }

  Future<void> _shareExport() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100)); // let frame draw
    try {
      final fileName = 'SabtrackExport_${DateTime.now().millisecondsSinceEpoch}';
      await ShareHelper.shareWidgetCapture(_repaintKey, 'My Sabtrack Fitness card: $_customTitle');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing export: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _saveExport() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final fileName = 'Sabtrack_${widget.type == ExportType.daily ? "Daily" : "Workout"}_${DateTime.now().millisecondsSinceEpoch}';
      final path = await ShareHelper.saveWidgetCapture(_repaintKey, fileName: fileName);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved successfully to gallery:\n$path')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save file to disk.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = _getCanvasSize();

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1424),
        foregroundColor: Colors.white,
        title: Text(
          'EXPORT & SHARE STUDIO',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0, color: AppTheme.accent),
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
            ),
        ],
      ),
      body: Column(
        children: [
          // PREVIEW CANVAS AREA
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: InteractiveViewer(
                minScale: 0.1,
                maxScale: 2.0,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      decoration: _buildCanvasDecoration(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCanvasHeader(),
                          Expanded(
                            child: Center(
                              child: _buildLayoutContent(),
                            ),
                          ),
                          _buildCanvasFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // DESIGN & PARAMETERS CONTROLS
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1424),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                top: false,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: AppTheme.accent,
                        unselectedLabelColor: Colors.white60,
                        indicatorColor: AppTheme.accent,
                        tabs: const [
                          Tab(text: 'Layouts'),
                          Tab(text: 'Styles'),
                          Tab(text: 'Ratios'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildLayoutSelector(),
                            _buildStylesEditor(),
                            _buildRatioSelector(),
                          ],
                        ),
                      ),
                      
                      // EXPORT ACTIONS FOOTER
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Save to Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _isExporting ? null : _saveExport,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.share_rounded),
                                label: const Text('Share Card', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _isExporting ? null : _shareExport,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CANVAS GENERATOR BUILDERS ---
  
  BoxDecoration _buildCanvasDecoration() {
    BorderRadius radius = BorderRadius.circular(_cornerRadius);
    
    // Background images overrides
    if (_backgroundType == "photo") {
      return BoxDecoration(
        borderRadius: radius,
        image: DecorationImage(
          image: NetworkImage(_photoUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.65), BlendMode.srcOver),
        ),
      );
    }

    // Default decorations based on selected theme
    switch (_theme) {
      case 'light':
        return BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        );
      case 'glass':
        return BoxDecoration(
          color: Colors.black.withOpacity(_glassOpacity),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        );
      case 'gradient':
        return BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF090D16), Color(0xFF020617)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'black':
        return BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFF1E293B), width: 1),
        );
      case 'dark':
      default:
        return BoxDecoration(
          color: const Color(0xFF090D16),
          borderRadius: radius,
          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        );
    }
  }

  Widget _buildCanvasHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.2),
                  image: const DecorationImage(
                    image: NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alex Rivera',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _textColor),
                  ),
                  Text(
                    '@alex_lifts',
                    style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (_showLogo)
            Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: _accentColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'SABTRACK',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _accentColor, letterSpacing: 0.5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCanvasFooter() {
    final dateLabel = widget.data['date'] ?? 'Daily Metrics';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _customTitle,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: _textColor.withOpacity(0.5)),
          ),
          Text(
            dateLabel,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: _textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  // --- PRESETS IMPLEMENTATIONS (12 styles) ---
  
  Widget _buildLayoutContent() {
    switch (_layout) {
      case 'glass':
        return _buildGlassLayout();
      case 'rings':
        return _buildAppleRingsLayout();
      case 'strava':
        return _buildStravaLayout();
      case 'whoop':
        return _buildWhoopLayout();
      case 'oura':
        return _buildOuraLayout();
      case 'garmin':
        return _buildGarminLayout();
      case 'nutrition':
        return _buildNutritionLayout();
      case 'sleep':
        return _buildSleepLayout();
      case 'hydration':
        return _buildHydrationLayout();
      case 'ai':
        return _buildAiLayout();
      case 'dashboard':
        return _buildDashboardLayout();
      case 'minimal':
      default:
        return _buildMinimalLayout();
    }
  }

  Widget _buildMinimalLayout() {
    final steps = widget.data['steps'] ?? 10840;
    final calories = widget.data['calorieBurned'] ?? 480;
    final water = widget.data['waterMl'] ?? 2100;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'TODAY\'S STEPS',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _textColor.withOpacity(0.5), letterSpacing: 2.0),
        ),
        const SizedBox(height: 8),
        Text(
          '$steps',
          style: GoogleFonts.inter(fontSize: 56, fontWeight: FontWeight.w900, color: _accentColor, letterSpacing: -1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 1.5,
          width: 80,
          color: _textColor.withOpacity(0.15),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text('${calories} kcal', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _textColor)),
                Text('Active Burn', style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              children: [
                Text('${water}ml', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _textColor)),
                Text('Water', style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassLayout() {
    final steps = widget.data['steps'] ?? 10840;
    final score = widget.data['recoveryScore'] ?? 84;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FITNESS PROFILE',
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('OPTIMAL', style: TextStyle(fontSize: 8, color: _accentColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Readiness', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$score%', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: _accentColor)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Logged Steps', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$steps', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppleRingsLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: 0.85, // Move (Move target 600)
                strokeWidth: 14,
                backgroundColor: Colors.redAccent.withOpacity(0.12),
                color: Colors.redAccent,
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(
              width: 106,
              height: 106,
              child: CircularProgressIndicator(
                value: 0.65, // Exercise (Ex target 30)
                strokeWidth: 14,
                backgroundColor: Colors.lightGreenAccent.withOpacity(0.12),
                color: Colors.lightGreenAccent,
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: 0.75, // Stand (Stand target 12h)
                strokeWidth: 14,
                backgroundColor: Colors.cyanAccent.withOpacity(0.12),
                color: Colors.cyanAccent,
                strokeCap: StrokeCap.round,
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRingLabel('Move', '510 / 600 kcal', Colors.redAccent),
            const SizedBox(height: 12),
            _buildRingLabel('Exercise', '20 / 30 min', Colors.lightGreenAccent),
            const SizedBox(height: 12),
            _buildRingLabel('Stand', '9 / 12 hr', Colors.cyanAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildRingLabel(String label, String val, Color c) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textColor.withOpacity(0.6), fontWeight: FontWeight.bold)),
            Text(val, style: GoogleFonts.inter(fontSize: 12, color: _textColor, fontWeight: FontWeight.w900)),
          ],
        )
      ],
    );
  }

  Widget _buildStravaLayout() {
    final activityName = widget.data['activityType'] ?? 'Cardio Workout';
    final distance = widget.data['distance'] ?? '7.8 km';
    final pace = widget.data['pace'] ?? '5:24 /km';
    final duration = widget.data['duration'] ?? '42 min';

    return Container(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_run_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(activityName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
            const Divider(height: 20, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStravaMetric('Distance', distance),
                _buildStravaMetric('Pace', pace),
                _buildStravaMetric('Time', duration),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStravaMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.inter(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildWhoopLayout() {
    final recovery = widget.data['recoveryScore'] ?? 84;
    final strain = widget.data['strainScore'] ?? 14.8;
    
    Color whoopColor = Colors.redAccent;
    if (recovery >= 66) whoopColor = Colors.greenAccent;
    else if (recovery >= 33) whoopColor = Colors.yellowAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: recovery / 100,
                strokeWidth: 10,
                backgroundColor: Colors.white10,
                color: whoopColor,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$recovery%', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('Recovery', style: GoogleFonts.inter(fontSize: 8, color: whoopColor, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
        const SizedBox(width: 32),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAY STRAIN', style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
            Text('$strain / 21', style: GoogleFonts.inter(fontSize: 22, color: Colors.cyanAccent, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('HRV AVERAGE', style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
            Text('74 ms', style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildOuraLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'OURA READINESS',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Text('87', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: _accentColor)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOuraMiniDial('Sleep', 82, Colors.purpleAccent),
            _buildOuraMiniDial('Activity', 90, Colors.orangeAccent),
            _buildOuraMiniDial('Readiness', 87, Colors.blueAccent),
          ],
        )
      ],
    );
  }

  Widget _buildOuraMiniDial(String label, int val, Color c) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: val / 100,
                strokeWidth: 4.5,
                backgroundColor: Colors.white10,
                color: c,
              ),
            ),
            Text('$val', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGarminLayout() {
    final activityName = widget.data['activityType'] ?? 'Running';
    final distance = widget.data['distance'] ?? '7.8 km';
    final calories = widget.data['calorieBurned'] ?? 480;
    final pace = widget.data['pace'] ?? '5:24 /km';
    final duration = widget.data['duration'] ?? '42 min';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GARMIN PERFORMANCE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.cyanAccent)),
            Text('$activityName Stats', style: GoogleFonts.inter(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGarminMetric('Distance', distance)),
            Expanded(child: _buildGarminMetric('Calories', '$calories kcal')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGarminMetric('Avg Pace', pace)),
            Expanded(child: _buildGarminMetric('Duration', duration)),
          ],
        ),
        const SizedBox(height: 12),
        // Heart rate chart mock using custom painter sparkline
        Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: CustomPaint(
            painter: SparklinePainter(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildGarminMetric(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildNutritionLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('CALORIES CONSUMED', style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('1740 / 2000 kcal', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _textColor)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMacroSegment('Protein', '118g', 0.85, Colors.indigoAccent),
            _buildMacroSegment('Carbs', '192g', 0.78, Colors.amberAccent),
            _buildMacroSegment('Fats', '54g', 0.70, Colors.tealAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroSegment(String label, String value, double ratio, Color c) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 5,
                backgroundColor: Colors.white10,
                color: c,
              ),
            ),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _textColor)),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSleepLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SLEEP DURATION', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('7 hrs 45 mins', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
            const Icon(Icons.nights_stay_rounded, color: Colors.indigoAccent, size: 36),
          ],
        ),
        const SizedBox(height: 20),
        Text('SLEEP STAGES', style: GoogleFonts.inter(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        // Horizontal sleep stages bar chart
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 16,
            width: double.infinity,
            child: Row(
              children: [
                Expanded(flex: 8, child: Container(color: Colors.redAccent)), // Awake
                Expanded(flex: 47, child: Container(color: Colors.blueAccent)), // Light
                Expanded(flex: 25, child: Container(color: Colors.indigo)), // Deep
                Expanded(flex: 20, child: Container(color: Colors.purpleAccent)), // REM
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Awake (8%)', style: TextStyle(fontSize: 8, color: Colors.white38)),
            Text('Light (47%)', style: TextStyle(fontSize: 8, color: Colors.white38)),
            Text('Deep (25%)', style: TextStyle(fontSize: 8, color: Colors.white38)),
            Text('REM (20%)', style: TextStyle(fontSize: 8, color: Colors.white38)),
          ],
        )
      ],
    );
  }

  Widget _buildHydrationLayout() {
    final water = widget.data['waterMl'] ?? 2100;
    final percent = ((water / 2500) * 100).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HYDRATION LEVEL', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
            Text('${water} ml', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
            const SizedBox(height: 12),
            Text('$percent% of daily goal logged', style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Daily hydration target: 2500 ml', style: GoogleFonts.inter(fontSize: 8, color: Colors.white38)),
          ],
        ),
        const SizedBox(width: 40),
        // Hydration bottle illustration
        Container(
          width: 50,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent, width: 2.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(2),
          alignment: Alignment.bottomCenter,
          child: Container(
            height: (120 * (percent / 100).clamp(0.0, 1.0)).toDouble(),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiLayout() {
    final aiSummary = widget.data['aiSummary'] ?? "Your active steps are optimal! Hydration is on target. Great workload distribution.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, color: Colors.indigoAccent, size: 18),
                  const SizedBox(width: 6),
                  Text('AI COACH INSIGHTS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('GEMINI AI', style: TextStyle(fontSize: 8, color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '"$aiSummary"',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLayout() {
    final steps = widget.data['steps'] ?? 10840;
    final calories = widget.data['calorieBurned'] ?? 480;
    final water = widget.data['waterMl'] ?? 2100;
    final recovery = widget.data['recoveryScore'] ?? 84;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('SABTRACK INFOGRAPHIC', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _textColor.withOpacity(0.5))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMiniDashboardItem('Steps', '$steps', Colors.cyanAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildMiniDashboardItem('Active burn', '$calories kcal', Colors.orangeAccent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMiniDashboardItem('Hydration', '${water}ml', Colors.blueAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildMiniDashboardItem('Readiness', '$recovery%', Colors.greenAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniDashboardItem(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 8, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
        ],
      ),
    );
  }

  // --- CONTROLS TABS BUILDERS ---
  
  Widget _buildLayoutSelector() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _layoutsList.length,
      itemBuilder: (context, index) {
        final item = _layoutsList[index];
        final isSelected = _layout == item['id'];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.accent : Colors.white10, width: 1.2),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            subtitle: Text(item['desc']!, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            onTap: () {
              setState(() {
                _layout = item['id']!;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildStylesEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Picker
          const Text('THEME SELECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStyleTab('dark', 'Dark Theme'),
              _buildStyleTab('light', 'Light Theme'),
              _buildStyleTab('glass', 'Glassmorphic'),
              _buildStyleTab('gradient', 'Gradient Glow'),
              _buildStyleTab('black', 'AMOLED Black'),
            ],
          ),
          const SizedBox(height: 20),
          
          // Background Type Picker
          const Text('BACKGROUND DECORATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Solid Theme'),
                  selected: _backgroundType == "color",
                  onSelected: (_) => setState(() => _backgroundType = "color"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Photo backdrop'),
                  selected: _backgroundType == "photo",
                  onSelected: (_) => setState(() => _backgroundType = "photo"),
                ),
              ),
            ],
          ),
          if (_backgroundType == "photo") ...[
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _photoUrl),
              onChanged: (val) => setState(() => _photoUrl = val),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                hintText: "Backdrop photo URL",
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Accent Color picker
          const Text('ACCENT THEME COLOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _buildColorSelector(AppTheme.accent),
              _buildColorSelector(AppTheme.neonIndigo),
              _buildColorSelector(AppTheme.neonPink),
              _buildColorSelector(AppTheme.neonCyan),
              _buildColorSelector(AppTheme.neonEmerald),
              _buildColorSelector(AppTheme.neonAmber),
            ],
          ),
          const SizedBox(height: 20),

          // Custom title
          const Text('CUSTOM INFOGRAPHIC TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: _customTitle),
            onChanged: (val) => setState(() => _customTitle = val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              hintText: "Type custom header text...",
              hintStyle: const TextStyle(color: Colors.white30),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          
          const SizedBox(height: 16),
          // Logo checkbox
          CheckboxListTile(
            title: const Text('Display logo brand watermark', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            value: _showLogo,
            activeColor: AppTheme.accent,
            checkColor: Colors.black,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _showLogo = val ?? true),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleTab(String id, String label) {
    final isSelected = _theme == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _theme = id;
            _updateThemeColors();
          });
        }
      },
    );
  }

  Widget _buildColorSelector(Color c) {
    final isSelected = _accentColor.value == c.value;
    return GestureDetector(
      onTap: () => setState(() => _accentColor = c),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Widget _buildRatioSelector() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(20),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildRatioCard('square', 'Square 1:1', 'Instagram post', Icons.crop_square_rounded),
        _buildRatioCard('story', 'Story 9:16', 'Insta/WhatsApp Status', Icons.stay_current_portrait_rounded),
        _buildRatioCard('post', 'Post 4:5', 'Portrait post', Icons.portrait_rounded),
        _buildRatioCard('landscape', 'Landscape 16:9', 'LinkedIn/Twitter', Icons.crop_landscape_rounded),
      ],
    );
  }

  Widget _buildRatioCard(String id, String title, String desc, IconData icon) {
    final isSelected = _aspectRatio == id;
    return GestureDetector(
      onTap: () => setState(() => _aspectRatio = id),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.accent : Colors.white10, width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : Colors.white60, size: 24),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            Text(desc, style: const TextStyle(fontSize: 9, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// Sparkline heart-rate graph painter for Garmin Style
class SparklinePainter extends CustomPainter {
  final Color color;

  SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.5),
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.3, size.height * 0.45),
      Offset(size.width * 0.4, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 0.65),
      Offset(size.width * 0.6, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.25),
      Offset(size.width * 0.9, size.height * 0.4),
      Offset(size.width, size.height * 0.35),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw shaded area
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    fillPaint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      [color.withOpacity(0.2), color.withOpacity(0.0)],
    );

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
