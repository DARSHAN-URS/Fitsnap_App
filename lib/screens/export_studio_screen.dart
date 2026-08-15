import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../theme/sabtrack_logo.dart';
import '../utils/share_helper.dart';
import '../providers/profile_provider.dart';
import '../services/api_service.dart';

enum ExportType { daily, workout }

class ExportStudioScreen extends ConsumerStatefulWidget {
  final ExportType type;
  
  // Data maps to populate layouts
  final Map<String, dynamic> data;

  const ExportStudioScreen({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  ConsumerState<ExportStudioScreen> createState() => _ExportStudioScreenState();
}

class _ExportStudioScreenState extends ConsumerState<ExportStudioScreen> {
  // Key to capture layout
  final GlobalKey _repaintKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  // Customization States
  int _activeStep = 0; // 0: Layouts, 1: Styles, 2: Ratios
  String _layout = 'minimal'; // minimal, glass, rings, strava, whoop, oura, garmin, nutrition, sleep, hydration, ai, dashboard, transparent
  String _aspectRatio = 'square'; // square, story, post, landscape
  String _theme = 'dark'; // dark, light, glass, gradient, black, transparent
  Color _accentColor = AppTheme.accent;
  Color _textColor = Colors.white;
  double _cornerRadius = 24.0;
  double _glassOpacity = 0.2;
  bool _showLogo = true;
  String _customTitle = "Sabtrack AI Performance";
  String _backgroundType = "color"; // color, photo
  String _photoUrl = "https://images.unsplash.com/photo-1502680390469-be75c86b636f?q=80&w=1200";
  String? _localPhotoPath;
  double _photoDimming = 0.25; // 0.0 to 0.8
  String _stravaPosition = 'top_right'; // top_right, top_left, bottom_right, bottom_left, center
  bool _showRouteLine = true;
  Color _routeLineColor = const Color(0xFFFC5200); // Signature Strava/Sabtrack Athletic Orange
  double _routeStrokeWidth = 3.5;
  String _watermarkStyle = 'SABTRACK'; // SABTRACK, STRAVA, SABTRACK AI, CUSTOM, NONE

  final List<Map<String, String>> _curatedBackdrops = [
    {
      'title': 'Tea Hills Trail',
      'url': 'https://images.unsplash.com/photo-1502680390469-be75c86b636f?q=80&w=1200',
    },
    {
      'title': 'Mountain Summit',
      'url': 'https://images.unsplash.com/photo-1483721074575-47000966a3d1?q=80&w=1200',
    },
    {
      'title': 'Morning Run',
      'url': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=1200',
    },
    {
      'title': 'Scenic Road',
      'url': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1200',
    },
    {
      'title': 'Cycling Trail',
      'url': 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?q=80&w=1200',
    },
    {
      'title': 'Training Gym',
      'url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1200',
    },
  ];

  bool _isExporting = false;
  int? _hrvMs;
  double? _sleepHoursLogged;
  int? _sleepScoreLogged;

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
    {'id': 'transparent', 'name': 'Transparent Info', 'desc': 'Completely transparent stats summary'},
  ];

  IconData _getLayoutIcon(String id) {
    switch (id) {
      case 'minimal':
        return Icons.analytics_outlined;
      case 'glass':
        return Icons.blur_on_rounded;
      case 'rings':
        return Icons.published_with_changes_rounded;
      case 'strava':
        return Icons.directions_run_rounded;
      case 'whoop':
        return Icons.donut_large_rounded;
      case 'oura':
        return Icons.watch_rounded;
      case 'garmin':
        return Icons.show_chart_rounded;
      case 'nutrition':
        return Icons.restaurant_rounded;
      case 'sleep':
        return Icons.nights_stay_rounded;
      case 'hydration':
        return Icons.water_drop_rounded;
      case 'ai':
        return Icons.psychology_rounded;
      case 'dashboard':
        return Icons.grid_view_rounded;
      case 'transparent':
        return Icons.opacity_rounded;
      default:
        return Icons.dashboard_customize_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.data['initialLayout'] != null) {
      _layout = widget.data['initialLayout'].toString();
      if (_layout == 'strava') {
        _backgroundType = 'photo';
        _aspectRatio = 'story';
      }
    }
    if (widget.data['photoUrl'] != null) {
      _photoUrl = widget.data['photoUrl'].toString();
      _backgroundType = 'photo';
    }
    if (widget.data['localPhotoPath'] != null) {
      _localPhotoPath = widget.data['localPhotoPath'].toString();
      _backgroundType = 'photo';
    }
    _updateThemeColors();
    _fetchUserVitalsFromBackend();
  }

  Future<void> _fetchUserVitalsFromBackend() async {
    try {
      final res = await ApiService.getUserMeasurements();
      if (res['success'] && res['data'] != null) {
        final List<dynamic> list = res['data'];
        for (var item in list) {
          final type = item['metric_type'];
          final val = double.tryParse(item['value'].toString());
          if (val == null) continue;
          if (type == 'hrv' && _hrvMs == null) {
            if (mounted) setState(() => _hrvMs = val.round());
          } else if (type == 'sleep_hours' && _sleepHoursLogged == null) {
            if (mounted) setState(() => _sleepHoursLogged = val);
          } else if (type == 'sleep_score' && _sleepScoreLogged == null) {
            if (mounted) setState(() => _sleepScoreLogged = val.round());
          }
        }
      }
    } catch (_) {}
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
      final metricType = widget.type == ExportType.daily ? 'daily' : 'workout';
      final res = await ApiService.logExportImage(
        metricType: metricType,
        layoutType: _layout,
        theme: _theme,
        customSettings: {
          'aspect_ratio': _aspectRatio,
          'title': _customTitle,
        },
      );

      String? exportId;
      if (res['success'] && res['data'] != null) {
        exportId = res['data']['id']?.toString();
      }

      await ShareHelper.shareWidgetCapture(_repaintKey, 'My Sabtrack Fitness card: $_customTitle');

      if (exportId != null) {
        await ApiService.logExportShare(exportId, 'system_share', 'Shared export card');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _saveExport() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final metricType = widget.type == ExportType.daily ? 'daily' : 'workout';
      await ApiService.logExportImage(
        metricType: metricType,
        layoutType: _layout,
        theme: _theme,
        customSettings: {
          'aspect_ratio': _aspectRatio,
          'title': _customTitle,
        },
      );

      final fileName = 'Sabtrack_${widget.type == ExportType.daily ? "Daily" : "Workout"}_${DateTime.now().millisecondsSinceEpoch}';
      final path = await ShareHelper.saveWidgetCapture(_repaintKey, fileName: fileName);
      if (mounted) {
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved successfully to gallery:\n$path')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save file to disk.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
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
                      padding: _layout == 'strava' ? EdgeInsets.zero : const EdgeInsets.all(24),
                      child: _layout == 'strava'
                          ? _buildStravaFullCanvasLayout(profileState, canvasSize)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCanvasHeader(profileState),
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
                child: Column(
                  children: [
                    _buildStepIndicator(),
                    Expanded(
                      child: _buildActiveStepContent(),
                    ),
                    _buildNavigationButtons(),
                  ],
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
    if (_backgroundType == "photo" || _layout == 'strava') {
      ImageProvider photoProvider;
      if (_localPhotoPath != null && File(_localPhotoPath!).existsSync()) {
        photoProvider = FileImage(File(_localPhotoPath!));
      } else {
        photoProvider = NetworkImage(_photoUrl);
      }

      return BoxDecoration(
        borderRadius: radius,
        image: DecorationImage(
          image: photoProvider,
          fit: BoxFit.cover,
          colorFilter: _photoDimming > 0
              ? ColorFilter.mode(Colors.black.withOpacity(_photoDimming), BlendMode.darken)
              : null,
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
      case 'transparent':
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
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

  Widget _buildCanvasHeader(ProfileState profileState) {
    final hasImage = profileState.profilePictureUrl != null && profileState.profilePictureUrl!.isNotEmpty;
    final isNetworkImage = hasImage && profileState.profilePictureUrl!.startsWith('http');

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
                  image: DecorationImage(
                    image: hasImage
                        ? (isNetworkImage
                            ? CachedNetworkImageProvider(profileState.profilePictureUrl!)
                            : FileImage(File(profileState.profilePictureUrl!)) as ImageProvider)
                        : const NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profileState.name.isNotEmpty ? profileState.name : 'Guest User',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: _textColor),
                  ),
                  Text(
                    profileState.username.startsWith('@')
                        ? profileState.username
                        : '@${profileState.username.isNotEmpty ? profileState.username : 'guest_user'}',
                    style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (_showLogo)
            Row(
              children: [
                const SabtrackLogo(size: 20),
                const SizedBox(width: 6),
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
      case 'transparent':
        return _buildTransparentLayout();
      case 'minimal':
      default:
        return _buildMinimalLayout();
    }
  }

  Widget _buildTransparentLayout() {
    final steps = widget.data['steps'] ?? 10840;
    final calories = widget.data['calorieBurned'] ?? 480;
    final recovery = widget.data['recoveryScore'] ?? 84;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'DAILY SUMMARY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _accentColor.withOpacity(0.8),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTransparentStatItem('Steps', '$steps', Icons.directions_walk_rounded),
              _buildTransparentStatItem('Burn', '$calories kcal', Icons.local_fire_department_rounded),
              _buildTransparentStatItem('Recovery', '$recovery%', Icons.bolt_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransparentStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _accentColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: _textColor.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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
    final moveCalories = (widget.data['calorieBurned'] as num?)?.toDouble() ?? 480.0;
    final moveGoal = (widget.data['calorieGoal'] as num?)?.toDouble() ?? 600.0;
    final moveProgress = (moveCalories / moveGoal).clamp(0.0, 1.0);

    final exerciseMins = (widget.data['activeMinutes'] as num?)?.toDouble() ?? 20.0;
    final exerciseGoal = 30.0;
    final exerciseProgress = (exerciseMins / exerciseGoal).clamp(0.0, 1.0);

    final workoutsCount = (widget.data['workoutsCount'] as num?)?.toInt() ?? 1;
    final standHours = (8 + workoutsCount).clamp(1, 12);
    final standProgress = (standHours / 12.0).clamp(0.0, 1.0);

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
                value: moveProgress,
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
                value: exerciseProgress,
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
                value: standProgress,
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
            _buildRingLabel('Move', '${moveCalories.toInt()} / ${moveGoal.toInt()} kcal', Colors.redAccent),
            const SizedBox(height: 12),
            _buildRingLabel('Exercise', '${exerciseMins.toInt()} / 30 min', Colors.lightGreenAccent),
            const SizedBox(height: 12),
            _buildRingLabel('Stand', '$standHours / 12 hr', Colors.cyanAccent),
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
    final distance = widget.data['distance'] ?? '${((widget.data['steps'] ?? 10840) * 0.0008).toStringAsFixed(2)} km';
    final pace = widget.data['pace'] ?? '6:15 /km';
    final duration = widget.data['duration'] ?? '${widget.data['activeMinutes'] ?? 42} min';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildStravaStatItem('Distance', distance),
          const SizedBox(height: 10),
          _buildStravaStatItem('Pace', pace),
          const SizedBox(height: 10),
          _buildStravaStatItem('Time', duration),
        ],
      ),
    );
  }

  Widget _buildStravaFullCanvasLayout(ProfileState profileState, Size canvasSize) {
    final distance = widget.data['distance'] ?? '${((widget.data['steps'] ?? 10840) * 0.0008).toStringAsFixed(2)} km';
    final pace = widget.data['pace'] ?? '6:15 /km';
    final duration = widget.data['duration'] ?? '${widget.data['activeMinutes'] ?? 42} min';
    final routePoints = _getRoutePoints();

    String watermarkText = _watermarkStyle;
    if (watermarkText == 'CUSTOM') {
      watermarkText = _customTitle.isNotEmpty ? _customTitle.toUpperCase() : 'SABTRACK';
    }

    CrossAxisAlignment statAlign = CrossAxisAlignment.end;
    if (_stravaPosition == 'top_left' || _stravaPosition == 'bottom_left') {
      statAlign = CrossAxisAlignment.start;
    } else if (_stravaPosition == 'center') {
      statAlign = CrossAxisAlignment.center;
    }

    final statsColumn = Column(
      crossAxisAlignment: statAlign,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStravaStatItem('Distance', distance, align: statAlign),
        const SizedBox(height: 14),
        _buildStravaStatItem('Pace', pace, align: statAlign),
        const SizedBox(height: 14),
        _buildStravaStatItem('Time', duration, align: statAlign),
        if (_showRouteLine) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: 140,
            height: 60,
            child: CustomPaint(
              painter: _StravaRoutePolylinePainter(
                points: routePoints,
                routeColor: _routeLineColor,
                strokeWidth: _routeStrokeWidth,
              ),
            ),
          ),
        ],
        if (_showLogo && watermarkText != 'NONE') ...[
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: statAlign == CrossAxisAlignment.start
                ? MainAxisAlignment.start
                : (statAlign == CrossAxisAlignment.center
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.end),
            children: [
              if (watermarkText == 'SABTRACK' || watermarkText == 'SABTRACK AI') ...[
                const SabtrackLogo(size: 22, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                watermarkText,
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.9),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_cornerRadius),
      child: Stack(
        children: [
          // Subtle gradient vignette to protect legibility on bright backgrounds
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.black.withOpacity(0.32),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                ),
              ),
            ),
          ),

          // Main Stats Block Position
          if (_stravaPosition == 'top_right')
            Positioned(
              top: 28,
              right: 28,
              child: statsColumn,
            )
          else if (_stravaPosition == 'top_left')
            Positioned(
              top: 28,
              left: 28,
              child: statsColumn,
            )
          else if (_stravaPosition == 'bottom_right')
            Positioned(
              bottom: 32,
              right: 28,
              child: statsColumn,
            )
          else if (_stravaPosition == 'bottom_left')
            Positioned(
              bottom: 32,
              left: 28,
              child: statsColumn,
            )
          else
            Positioned.fill(
              child: Center(
                child: statsColumn,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStravaStatItem(String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.end}) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.85),
                offset: const Offset(0, 1.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.9),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Offset> _getRoutePoints() {
    if (widget.data['routePoints'] != null) {
      final raw = widget.data['routePoints'];
      if (raw is List<Offset> && raw.isNotEmpty) {
        return raw;
      }
      if (raw is List) {
        final List<Offset> pts = [];
        for (var item in raw) {
          if (item is Offset) {
            pts.add(item);
          } else if (item is Map) {
            final x = (item['x'] as num?)?.toDouble() ?? 0.0;
            final y = (item['y'] as num?)?.toDouble() ?? 0.0;
            pts.add(Offset(x, y));
          }
        }
        if (pts.isNotEmpty) return pts;
      }
    }
    return _getDefaultTrailRoute();
  }

  List<Offset> _getDefaultTrailRoute() {
    return const [
      Offset(10, 30),
      Offset(25, 28),
      Offset(40, 35),
      Offset(55, 32),
      Offset(70, 42),
      Offset(85, 48),
      Offset(100, 45),
      Offset(115, 52),
      Offset(130, 56),
      Offset(145, 54),
      Offset(160, 60),
      Offset(175, 58),
      Offset(190, 65),
      Offset(205, 70),
      Offset(210, 85),
      Offset(212, 100),
    ];
  }

  Widget _buildWhoopLayout() {
    final recovery = widget.data['recoveryScore'] ?? 84;
    final strain = widget.data['strainScore'] ?? 14.8;
    final hrvVal = _hrvMs ?? 74;
    
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
            Text('$hrvVal ms', style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildOuraLayout() {
    final readiness = widget.data['recoveryScore'] ?? 87;
    final sleepScore = _sleepScoreLogged ?? ((readiness as int) - 3).clamp(50, 99);
    final activityScore = (widget.data['strainScore'] != null
        ? ((widget.data['strainScore'] as num) * 5.5).clamp(50, 99).toInt()
        : 90);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'OURA READINESS',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Text('$readiness', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: _accentColor)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOuraMiniDial('Sleep', sleepScore, Colors.purpleAccent),
            _buildOuraMiniDial('Activity', activityScore, Colors.orangeAccent),
            _buildOuraMiniDial('Readiness', readiness, Colors.blueAccent),
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
    final distance = widget.data['distance'] ?? '${((widget.data['steps'] ?? 10840) * 0.0008).toStringAsFixed(1)} km';
    final calories = widget.data['calorieBurned'] ?? 480;
    final pace = widget.data['pace'] ?? '5:24 /km';
    final duration = widget.data['duration'] ?? '${widget.data['activeMinutes'] ?? 42} min';

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
    final intake = widget.data['calorieIntake'] ?? 1740;
    final calGoal = widget.data['calorieGoal'] ?? 2000;
    final protein = widget.data['proteinIntake'] ?? 118;
    final proteinGoal = widget.data['proteinGoal'] ?? 130;
    final carbs = widget.data['carbsIntake'] ?? 192;
    final carbsGoal = widget.data['carbsGoal'] ?? 220;
    final fats = widget.data['fatsIntake'] ?? 54;
    final fatsGoal = widget.data['fatsGoal'] ?? 65;

    final pRatio = (protein / proteinGoal).clamp(0.0, 1.0);
    final cRatio = (carbs / carbsGoal).clamp(0.0, 1.0);
    final fRatio = (fats / fatsGoal).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('CALORIES CONSUMED', style: GoogleFonts.inter(fontSize: 9, color: _textColor.withOpacity(0.5), fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('$intake / $calGoal kcal', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _textColor)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMacroSegment('Protein', '${protein}g', pRatio, Colors.indigoAccent),
            _buildMacroSegment('Carbs', '${carbs}g', cRatio, Colors.amberAccent),
            _buildMacroSegment('Fats', '${fats}g', fRatio, Colors.tealAccent),
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
    final sleepHrs = _sleepHoursLogged ?? 7.75;
    final hrs = sleepHrs.floor();
    final mins = ((sleepHrs - hrs) * 60).round();

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
                Text('$hrs hrs $mins mins', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            'SELECT A LAYOUT STYLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _layoutsList.length,
              itemBuilder: (context, index) {
                final item = _layoutsList[index];
                final isSelected = _layout == item['id'];
                final icon = _getLayoutIcon(item['id']!);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _layout = item['id']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 135,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent.withOpacity(0.12)
                          : const Color(0xFF1E293B).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.08),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.black : Colors.white70,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['name']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['desc']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white60 : Colors.white38,
                            fontSize: 9,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Show preview features of active layout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(
                  _getLayoutIcon(_layout),
                  color: AppTheme.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _layoutsList.firstWhere((item) => item['id'] == _layout)['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _layoutsList.firstWhere((item) => item['id'] == _layout)['desc']!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: [
          _buildStepNode(0, 'Layout'),
          _buildStepLine(0),
          _buildStepNode(1, 'Styles'),
          _buildStepLine(1),
          _buildStepNode(2, 'Ratio'),
        ],
      ),
    );
  }

  Widget _buildStepNode(int stepIndex, String title) {
    final isCompleted = _activeStep > stepIndex;
    final isActive = _activeStep == stepIndex;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppTheme.accent
                : isActive
                    ? AppTheme.accent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive ? AppTheme.accent : Colors.white24,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    color: isActive ? AppTheme.accent : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int stepIndex) {
    final isCompleted = _activeStep > stepIndex;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: isCompleted ? AppTheme.accent : Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildActiveStepContent() {
    switch (_activeStep) {
      case 0:
        return _buildLayoutSelector();
      case 1:
        return _buildStylesEditor();
      case 2:
      default:
        return _buildRatioSelector();
    }
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildNavigationButtonsContent(),
      ),
    );
  }

  Widget _buildNavigationButtonsContent() {
    if (_activeStep == 0) {
      return SizedBox(
        key: const ValueKey('step0_nav'),
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          onPressed: () {
            setState(() {
              _activeStep = 1;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Configure Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      );
    } else if (_activeStep == 1) {
      return Row(
        key: const ValueKey('step1_nav'),
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _activeStep = 0;
                });
              },
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: () {
                setState(() {
                  _activeStep = 2;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Adjust Ratio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Step 2: Ratios + Export buttons
      return Column(
        key: const ValueKey('step2_nav'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
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
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Card', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isExporting ? null : _shareExport,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              setState(() {
                _activeStep = 1;
              });
            },
            child: Text(
              '← Back to Styles',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildStylesEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If Strava layout is selected, show dedicated Strava controls
          if (_layout == 'strava') ...[
            _buildStravaStyleControls(),
          ] else ...[
            // Standard Styles controls for other layouts
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
                _buildStyleTab('transparent', 'Transparent'),
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
              _buildPhotoPickerButtons(),
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
        ],
      ),
    );
  }

  Widget _buildStravaStyleControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ATHLETE PHOTO BACKDROP
        const Text(
          'ATHLETE WORKOUT PHOTO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),
        _buildPhotoPickerButtons(),
        const SizedBox(height: 14),
        
        // Curated Running Backdrops presets
        const Text(
          'OR PICK A RUNNING BACKDROP PRESET',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _curatedBackdrops.length,
            itemBuilder: (context, index) {
              final item = _curatedBackdrops[index];
              final isSelected = _localPhotoPath == null && _photoUrl == item['url'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _localPhotoPath = null;
                    _photoUrl = item['url']!;
                    _backgroundType = 'photo';
                  });
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : Colors.white24,
                      width: isSelected ? 2.5 : 1,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(item['url']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      item['title']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Photo Contrast / Dimming Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Photo Dimming (Contrast Protection)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${(_photoDimming * 100).round()}%', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: _photoDimming,
          min: 0.0,
          max: 0.75,
          divisions: 15,
          activeColor: AppTheme.accent,
          inactiveColor: Colors.white12,
          onChanged: (val) => setState(() => _photoDimming = val),
        ),
        const SizedBox(height: 16),

        // 2. OVERLAY POSITION
        const Text(
          'OVERLAY STATS POSITION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPositionChip('top_right', 'Top Right (Strava)'),
            _buildPositionChip('top_left', 'Top Left'),
            _buildPositionChip('bottom_right', 'Bottom Right'),
            _buildPositionChip('bottom_left', 'Bottom Left'),
            _buildPositionChip('center', 'Center Focus'),
          ],
        ),
        const SizedBox(height: 20),

        // 3. GPS ROUTE POLYLINE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GPS ROUTE POLYLINE MAP',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0),
            ),
            Switch(
              value: _showRouteLine,
              activeColor: AppTheme.accent,
              onChanged: (val) => setState(() => _showRouteLine = val),
            ),
          ],
        ),
        if (_showRouteLine) ...[
          const SizedBox(height: 6),
          const Text('Route Color', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _buildRouteColorSelector(const Color(0xFFFC5200), 'Strava Orange'),
              _buildRouteColorSelector(AppTheme.neonCyan, 'Cyan'),
              _buildRouteColorSelector(AppTheme.neonEmerald, 'Emerald'),
              _buildRouteColorSelector(AppTheme.neonPink, 'Pink'),
              _buildRouteColorSelector(Colors.white, 'White'),
              _buildRouteColorSelector(AppTheme.neonAmber, 'Amber'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Route Stroke Width', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('${_routeStrokeWidth.toStringAsFixed(1)}px', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _routeStrokeWidth,
            min: 2.0,
            max: 6.0,
            divisions: 8,
            activeColor: AppTheme.accent,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() => _routeStrokeWidth = val),
          ),
        ],
        const SizedBox(height: 16),

        // 4. WATERMARK BRANDING
        const Text(
          'WATERMARK BRANDING',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildWatermarkChip('SABTRACK', 'SABTRACK'),
            _buildWatermarkChip('STRAVA', 'STRAVA'),
            _buildWatermarkChip('SABTRACK AI', 'SABTRACK AI'),
            _buildWatermarkChip('CUSTOM', 'Custom Text'),
            _buildWatermarkChip('NONE', 'Hide Watermark'),
          ],
        ),
        if (_watermarkStyle == 'CUSTOM') ...[
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: _customTitle),
            onChanged: (val) => setState(() => _customTitle = val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              hintText: "Enter custom watermark text...",
              hintStyle: const TextStyle(color: Colors.white30),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoPickerButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _localPhotoPath != null ? AppTheme.accent : Colors.white12),
              ),
            ),
            icon: const Icon(Icons.photo_library_rounded, size: 18, color: AppTheme.accent),
            label: const Text('Pick Gallery Photo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            onPressed: _pickPhotoFromGallery,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12),
              ),
            ),
            icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.neonCyan),
            label: const Text('Take Photo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            onPressed: _takePhotoWithCamera,
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _localPhotoPath = image.path;
          _backgroundType = 'photo';
        });
      }
    } catch (e) {
      debugPrint('Error picking photo from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _localPhotoPath = image.path;
          _backgroundType = 'photo';
        });
      }
    } catch (e) {
      debugPrint('Error capturing photo from camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture photo: $e')),
        );
      }
    }
  }

  Widget _buildPositionChip(String id, String label) {
    final isSelected = _stravaPosition == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      side: BorderSide(color: isSelected ? AppTheme.accent : Colors.white12),
      onSelected: (selected) {
        if (selected) {
          setState(() => _stravaPosition = id);
        }
      },
    );
  }

  Widget _buildWatermarkChip(String id, String label) {
    final isSelected = _watermarkStyle == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      side: BorderSide(color: isSelected ? AppTheme.accent : Colors.white12),
      onSelected: (selected) {
        if (selected) {
          setState(() => _watermarkStyle = id);
        }
      },
    );
  }

  Widget _buildRouteColorSelector(Color c, String tooltip) {
    final isSelected = _routeLineColor.value == c.value;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _routeLineColor = c),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
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

// Custom Painter for Strava Route Polyline Trace
class _StravaRoutePolylinePainter extends CustomPainter {
  final List<Offset> points;
  final Color routeColor;
  final double strokeWidth;

  _StravaRoutePolylinePainter({
    required this.points,
    required this.routeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

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

    const double pad = 8.0;
    final double targetW = size.width - pad * 2;
    final double targetH = size.height - pad * 2;

    double scale = 1.0;
    if (pathW > 0 && pathH > 0) {
      scale = math.min(targetW / pathW, targetH / pathH);
    }

    final double shiftX = pad + (targetW - pathW * scale) / 2 - minX * scale;
    final double shiftY = pad + (targetH - pathH * scale) / 2 - minY * scale;

    final List<Offset> scaled = points.map((p) {
      return Offset(p.dx * scale + shiftX, p.dy * scale + shiftY);
    }).toList();

    // Route shadow / glow
    final glowPaint = Paint()
      ..color = routeColor.withOpacity(0.45)
      ..strokeWidth = strokeWidth + 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Route stroke
    final strokePaint = Paint()
      ..color = routeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(scaled.first.dx, scaled.first.dy);
    for (int i = 1; i < scaled.length; i++) {
      path.lineTo(scaled[i].dx, scaled[i].dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);

    // Start marker (green dot)
    final startDot = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(scaled.first, strokeWidth + 1.2, startDot);

    // End marker (white dot)
    final endDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(scaled.last, strokeWidth + 1.2, endDot);
  }

  @override
  bool shouldRepaint(covariant _StravaRoutePolylinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.strokeWidth != strokeWidth;
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
