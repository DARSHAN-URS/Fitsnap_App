import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'screens/home_tab.dart';
import 'screens/activity_tab.dart';
import 'screens/progress_tab.dart';
import 'screens/groups_tab.dart';
import 'screens/profile_tab.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Dynamic state for logged calories, macros, and meals list
  int _consumed = 0;
  int _protein = 0;
  // Initialize carbs and fats to 0
  int _carbs = 0;
  int _fats = 0;

  final List<Map<String, dynamic>> _meals = [];

  List<Widget> get _screens => [
    HomeTab(
      consumed: _consumed,
      protein: _protein,
      carbs: _carbs,
      fats: _fats,
      meals: _meals,
    ),
    const ActivityTab(),
    const ProgressTab(),
    const GroupsTab(),
    const ProfileTab(),
  ];

  bool _isAnalyzing = false;
  late AnimationController _pulseController;

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    int consumedTemp = prefs.getInt('dashboard_consumed') ?? 0;
    int proteinTemp = prefs.getInt('dashboard_protein') ?? 0;
    int carbsTemp = prefs.getInt('dashboard_carbs') ?? 0;
    int fatsTemp = prefs.getInt('dashboard_fats') ?? 0;
    List<Map<String, dynamic>> mealsTemp = [];

    final String? mealsJson = prefs.getString('dashboard_meals');
    if (mealsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(mealsJson);
        for (var item in decoded) {
          final Map<String, dynamic> meal = Map<String, dynamic>.from(item);
          if (meal['tagColor'] != null && meal['tagColor'] is int) {
            meal['tagColor'] = Color(meal['tagColor'] as int);
          }
          mealsTemp.add(meal);
        }
      } catch (e) {
        debugPrint('Error loading local meals: $e');
      }
    }

    if (ApiService.isAuthenticated) {
      // 1. Fetch meals from backend
      final mealsRes = await ApiService.getMeals();
      if (mealsRes['success']) {
        final List<dynamic> serverMeals = mealsRes['data'];
        mealsTemp.clear();
        consumedTemp = 0;
        proteinTemp = 0;
        carbsTemp = 0;
        fatsTemp = 0;

        for (var meal in serverMeals) {
          final double proteinVal = (meal['protein'] as num?)?.toDouble() ?? 0.0;
          final double carbsVal = (meal['carbs'] as num?)?.toDouble() ?? 0.0;
          final double fatsVal = (meal['fats'] as num?)?.toDouble() ?? 0.0;
          final int caloriesVal = (meal['calories'] as num?)?.toInt() ?? 0;

          mealsTemp.add({
            'name': meal['name'] ?? 'Meal Log',
            'calories': caloriesVal,
            'protein': proteinVal.toInt(),
            'carbs': carbsVal.toInt(),
            'fats': fatsVal.toInt(),
            'time': meal['logged_at'] != null 
                ? '${DateTime.parse(meal['logged_at']).toLocal().hour.toString().padLeft(2, '0')}:${DateTime.parse(meal['logged_at']).toLocal().minute.toString().padLeft(2, '0')}'
                : 'Just now',
          });
          consumedTemp += caloriesVal;
          proteinTemp += proteinVal.toInt();
          carbsTemp += carbsVal.toInt();
          fatsTemp += fatsVal.toInt();
        }
      }

      // 2. Fetch daily stats from backend
      final statsRes = await ApiService.getDailyStats();
      if (statsRes['success']) {
        final stats = statsRes['data'];
        await prefs.setInt('home_steps', (stats['steps'] as num?)?.toInt() ?? 0);
        await prefs.setInt('home_water', (stats['water_ml'] as num?)?.toInt() ?? 0);
      }
    }

    setState(() {
      _consumed = consumedTemp;
      _protein = proteinTemp;
      _carbs = carbsTemp;
      _fats = fatsTemp;
      _meals.clear();
      _meals.addAll(mealsTemp);
    });
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dashboard_consumed', _consumed);
    await prefs.setInt('dashboard_protein', _protein);
    await prefs.setInt('dashboard_carbs', _carbs);
    await prefs.setInt('dashboard_fats', _fats);

    final List<Map<String, dynamic>> serializableMeals = _meals.map((meal) {
      final Map<String, dynamic> copy = Map<String, dynamic>.from(meal);
      if (copy['tagColor'] != null && copy['tagColor'] is Color) {
        copy['tagColor'] = (copy['tagColor'] as Color).value;
      }
      return copy;
    }).toList();

    await prefs.setString('dashboard_meals', jsonEncode(serializableMeals));
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showScanToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleAnalysisResponse(Map<String, dynamic> result, String successMsg) {
    if (result['success']) {
      final data = result['data']['data'];
      
      // Calculate current time formatted string
      final now = DateTime.now();
      final String timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

      setState(() {
        _meals.add({
          'name': data['name'] ?? 'Analyzed Meal',
          'calories': data['calories'] ?? 0,
          'protein': data['protein'] ?? 0,
          'carbs': data['carbs'] ?? 0,
          'fats': data['fats'] ?? 0,
          'time': timeStr,
        });
        _consumed += (data['calories'] as num).toInt();
        _protein += (data['protein'] as num).toInt();
        _carbs += (data['carbs'] as num).toInt();
        _fats += (data['fats'] as num).toInt();
      });
      _saveLogs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Analysis failed. Please check backend connection.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _handleCameraScan({bool mock = false, String? imagePath}) async {
    setState(() => _isAnalyzing = true);
    _showScanToast(mock ? 'Demo Mode: Simulating camera nutrition scan...' : 'Uploading and analyzing food image...');
    
    final result = await ApiService.analyzeNutrition(imagePath: mock ? null : imagePath);
    setState(() => _isAnalyzing = false);
    
    _handleAnalysisResponse(result, 'Meal parsed successfully! Macros updated.');
  }

  void _handleLabelScan({bool mock = false, String? imagePath}) async {
    setState(() => _isAnalyzing = true);
    _showScanToast(mock ? 'Demo Mode: Simulating label nutrition scan...' : 'Uploading and analyzing nutrition label...');
    
    final result = await ApiService.analyzeNutritionLabel(imagePath: mock ? null : imagePath);
    setState(() => _isAnalyzing = false);
    
    _handleAnalysisResponse(result, 'Nutrition facts parsed successfully!');
  }

  void _handleTextDescribe(String text) async {
    setState(() => _isAnalyzing = true);
    _showScanToast('AI parsing text description...');
    
    final result = await ApiService.analyzeNutritionText(text);
    setState(() => _isAnalyzing = false);
    
    _handleAnalysisResponse(result, 'Text description parsed successfully!');
  }

  void _pickAndAnalyzeImage({required ImageSource source, required bool isLabelScan}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) {
        return;
      }
      
      if (isLabelScan) {
        _handleLabelScan(mock: false, imagePath: image.path);
      } else {
        _handleCameraScan(mock: false, imagePath: image.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _selectImageSource({required bool isLabelScan}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLabelScan ? 'Scan Nutrition Label' : 'Scan Food Image',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how you want to capture the image',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildOptionItem(
                    icon: Icons.camera_alt_rounded,
                    title: 'Use Camera',
                    desc: 'Take a new photo using your camera',
                    color: AppTheme.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAnalyzeImage(source: ImageSource.camera, isLabelScan: isLabelScan);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from Gallery',
                    desc: 'Select an existing photo from gallery',
                    color: AppTheme.neonPink,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAnalyzeImage(source: ImageSource.gallery, isLabelScan: isLabelScan);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Demo Mode (Mock Scan)',
                    desc: 'Run a mock scan using pre-configured mock food data',
                    color: AppTheme.neonEmerald,
                    onTap: () {
                      Navigator.pop(context);
                      if (isLabelScan) {
                        _handleLabelScan(mock: true);
                      } else {
                        _handleCameraScan(mock: true);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDescribeDialog() {
    final TextEditingController descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
         return AlertDialog(
           backgroundColor: Colors.white,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
           title: Text(
             'Describe Your Meal',
             style: GoogleFonts.plusJakartaSans(
               fontWeight: FontWeight.w800,
               color: AppTheme.primary,
             ),
           ),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 'Enter whatever you ate, including portions, to calculate macros instantly.',
                 style: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
               ),
               const SizedBox(height: 18),
               Container(
                 decoration: BoxDecoration(
                   color: const Color(0xFFF1F5F9),
                   borderRadius: BorderRadius.circular(16),
                 ),
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: TextField(
                   controller: descController,
                   maxLines: 3,
                   style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary),
                   decoration: InputDecoration(
                     hintText: 'e.g., Two eggs, two slices of sourdough toast, and a small cup of black coffee',
                     hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                     border: InputBorder.none,
                     contentPadding: const EdgeInsets.symmetric(vertical: 12),
                   ),
                 ),
               ),
             ],
           ),
           actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: Text(
                 'Cancel',
                 style: GoogleFonts.inter(color: Colors.black45, fontWeight: FontWeight.w600),
               ),
             ),
             ElevatedButton(
               onPressed: () {
                 final String text = descController.text.trim();
                 Navigator.pop(context);
                 if (text.isNotEmpty) {
                   _handleTextDescribe(text);
                 }
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppTheme.primary,
                 foregroundColor: Colors.white,
                 elevation: 0,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
               ),
               child: Text(
                 'Analyze',
                 style: GoogleFonts.inter(fontWeight: FontWeight.w700),
               ),
             ),
           ],
         );
      },
    );
  }

  void _showBarcodeScannerOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Barcode Scanner',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _BarcodeScannerSimOverlay(
          onScanComplete: (scannedProduct) {
            _handleAnalysisResponse({
              'success': true,
              'data': {
                'success': true,
                'data': scannedProduct,
              }
            }, 'Barcode scanned: ${scannedProduct['name']}!');
          },
        );
      },
    );
  }

  void _showEntryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Track Your Meal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a method to calculate calories & macros',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Options List
                  _buildOptionItem(
                    icon: Icons.camera_alt_rounded,
                    title: 'Take a Picture',
                    desc: 'Analyze meal instantly using computer vision',
                    color: AppTheme.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _selectImageSource(isLabelScan: false);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.edit_note_rounded,
                    title: 'Describe Meal',
                    desc: 'Type what you ate (e.g. 2 eggs and whole wheat toast)',
                    color: AppTheme.neonPink,
                    onTap: () {
                      Navigator.pop(context);
                      _showDescribeDialog();
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Scan Barcode',
                    desc: 'Scan UPC barcode on packaged foods',
                    color: AppTheme.neonEmerald,
                    onTap: () {
                      Navigator.pop(context);
                      _showBarcodeScannerOverlay();
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nutrition Label Scan',
                    desc: 'Scan back label information table',
                    color: AppTheme.neonAmber,
                    onTap: () {
                      Navigator.pop(context);
                      _selectImageSource(isLabelScan: true);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Colors.black.withOpacity(0.03), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildPremiumFooter() {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset > 0 ? bottomInset : 16,
      ),
      height: 80 + 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.82),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left navigation items
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(child: _buildNavItem(0, Icons.grid_view_rounded, 'Home')),
                              Expanded(child: _buildNavItem(1, Icons.directions_run_rounded, 'Activity')),
                            ],
                          ),
                        ),
                        
                        // Centered space for the FAB
                        const SizedBox(width: 80),
                        
                        // Right navigation items
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(child: _buildNavItem(2, Icons.bar_chart_rounded, 'Progress', customIcon: _buildProgressIcon())),
                              Expanded(child: _buildNavItem(3, Icons.explore_outlined, 'Groups')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Pulsing FAB centered
          Positioned(
            top: 0,
            child: _buildPulseFAB(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true, // Let content scroll behind the floating bottom bar
      body: Stack(
        children: [
          // Global Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          
          Column(
            children: [
              // Main Tab Content
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentIndex),
                      child: _screens[_currentIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Floating Bottom Navigation Bar (Footer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildPremiumFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseFAB() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF06B6D4), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 2.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _isAnalyzing ? null : _showEntryOptions,
          child: Center(
            child: _isAnalyzing
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(
                    Icons.center_focus_strong_rounded, // scanning look
                    color: Colors.white,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIcon() {
    final isSelected = _currentIndex == 2;
    final color = isSelected ? Colors.white : const Color(0xFF64748B);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 3.5,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2.5),
        Container(
          width: 3.5,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2.5),
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {Widget? customIcon, bool isProfile = false}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.white : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProfile)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.neonIndigo : Colors.black.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(
                    'DU',
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.inter().fontFamily,
                    ),
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF00FFA3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: customIcon ?? Icon(
                    icon,
                    color: color,
                    size: isSelected ? 20 : 22,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: GoogleFonts.inter(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeScannerSimOverlay extends StatefulWidget {
  final Function(Map<String, dynamic>) onScanComplete;
  
  const _BarcodeScannerSimOverlay({required this.onScanComplete});

  @override
  State<_BarcodeScannerSimOverlay> createState() => _BarcodeScannerSimOverlayState();
}

class _BarcodeScannerSimOverlayState extends State<_BarcodeScannerSimOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scannerController);

    // Simulate scanning detection after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _hasDetected = true);
      
      // Complete scan with random commercial product data
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        
        final mockBarcodeStr = 'UPC-${10000000000 + math.Random().nextInt(9000000000)}';
        final res = await ApiService.scanBarcode(mockBarcodeStr);
        
        if (!mounted) return;
        Navigator.pop(context);

        if (res['success']) {
          widget.onScanComplete(Map<String, dynamic>.from(res['data']));
        } else {
          widget.onScanComplete({
            'name': 'Greek Yogurt Honey (Barcode)',
            'calories': 150,
            'protein': 12,
            'carbs': 15,
            'fats': 4
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Viewfinder background placeholder
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Align Barcode in the Frame',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scanning UPC codes automatically...',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Frame Viewfinder
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 280,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white30, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      
                      // Animated scanning red line
                      if (!_hasDetected)
                        AnimatedBuilder(
                          animation: _scannerAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 10 + (_scannerAnimation.value * 160),
                              child: Container(
                                width: 260,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                      // Scanning success green overlay
                      if (_hasDetected)
                        Container(
                          width: 280,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            border: Border.all(color: Colors.greenAccent, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.greenAccent,
                              size: 56,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  
                  // Cancel Button
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: Text(
                      'Cancel Scan',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

