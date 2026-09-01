import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_food_logging_service.dart';
import '../theme/app_theme.dart';
import '../dashboard_screen.dart';
import '../providers/subscription_provider.dart';

class MealReviewScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> initialFoods;
  final String imagePath;

  const MealReviewScreen({
    super.key,
    required this.initialFoods,
    required this.imagePath,
  });

  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen> {
  late List<Map<String, dynamic>> _foods;
  late String _currentImagePath;
  bool _isSaving = false;
  bool _isRetaking = false;
  String _retakeStatusText = "AI Recognizing New Photo...";
  String? _errorMsg;

  // Local helper to track macro densities per gram for live zero-latency weight edits
  final Map<int, Map<String, double>> _macroDensities = {};

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    // Deep copy initial foods list to allow mutability
    _foods = widget.initialFoods.map((f) => Map<String, dynamic>.from(f)).toList();
    _calculateDensities();
  }

  void _calculateDensities() {
    for (int i = 0; i < _foods.length; i++) {
      final f = _foods[i];
      final double weight = (f['weight_g'] as num?)?.toDouble() ?? 150.0;
      final double cal = (f['calories'] as num?)?.toDouble() ?? 0.0;
      final double prot = (f['protein'] as num?)?.toDouble() ?? 0.0;
      final double carb = (f['carbs'] as num?)?.toDouble() ?? 0.0;
      final double fat = ((f['fat'] ?? f['fats']) as num?)?.toDouble() ?? 0.0;
      final double fib = (f['fiber'] as num?)?.toDouble() ?? 0.0;

      // If calories are 0, mark this item as having no nutrition data — do NOT inject fake values.
      // The user can manually edit the weight or food name to trigger a re-resolution.
      if (cal == 0.0) {
        // Use a 0-density density map so weight changes don't produce fake numbers
        _macroDensities[i] = {
          'calories': 0.0,
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 0.0,
          'fiber': 0.0,
        };
        continue;
      }

      _macroDensities[i] = {
        'calories': weight > 0 ? cal / weight : 0.0,
        'protein': weight > 0 ? prot / weight : 0.0,
        'carbs': weight > 0 ? carb / weight : 0.0,
        'fat': weight > 0 ? fat / weight : 0.0,
        'fiber': weight > 0 ? fib / weight : 0.0,
      };
    }
  }

  // Update item macros when weight changes
  void _updateItemWeight(int index, double newWeight) {
    if (newWeight < 5.0) newWeight = 5.0; // clamp min weight to 5g
    
    final density = _macroDensities[index];
    if (density == null) return;

    setState(() {
      _foods[index]['weight_g'] = newWeight;
      _foods[index]['serving_label'] = 'custom';
      _foods[index]['serving'] = '${newWeight.toInt()} g';
    });
    _updateItemMacros(index);
  }

  // Unified zero-latency macro calculation matching the backend engine
  void _updateItemMacros(int index) {
    final f = _foods[index];
    final double weight = (f['weight_g'] as num?)?.toDouble() ?? 100.0;
    final String method = (f['cooking_method'] as String? ?? "cooked").toLowerCase();
    
    final density = _macroDensities[index];
    if (density == null) return;

    // Base calculations
    double cal = weight * density['calories']!;
    double prot = weight * density['protein']!;
    double carb = weight * density['carbs']!;
    double fat = weight * density['fat']!;
    double fib = weight * density['fiber']!;

    // Cooking method modifiers
    if (method.contains("fried")) {
      fat *= 1.5;
      cal += (20 * (weight / 100.0));
    } else if (method.contains("roasted") || method.contains("grilled")) {
      fat *= 1.1;
      cal += (5 * (weight / 100.0));
    } else if (method.contains("boiled") || method.contains("steamed") || method.contains("raw")) {
      fat *= 0.95;
    }

    setState(() {
      _foods[index]['calories'] = cal.round();
      _foods[index]['protein'] = double.parse(prot.toStringAsFixed(1));
      _foods[index]['carbs'] = double.parse(carb.toStringAsFixed(1));
      _foods[index]['fat'] = double.parse(fat.toStringAsFixed(1));
      _foods[index]['fiber'] = double.parse(fib.toStringAsFixed(1));
    });
  }

  String _getServingLabel(Map<String, dynamic> food) {
    return food['serving_label'] as String? ?? 'custom';
  }

  void _updateItemServingUnit(int index, String unit) {
    double newWeight = 100.0;
    switch (unit) {
      case 'half_bowl':
        newWeight = 125.0;
        break;
      case 'one_bowl':
        newWeight = 250.0;
        break;
      case 'two_bowls':
        newWeight = 500.0;
        break;
      case 'one_cup':
        newWeight = 150.0;
        break;
      case 'half_cup':
        newWeight = 75.0;
        break;
      case 'one_chapati':
        newWeight = 40.0;
        break;
      case 'two_chapatis':
        newWeight = 80.0;
        break;
      case 'one_idli':
        newWeight = 50.0;
        break;
      case 'three_idlis':
        newWeight = 150.0;
        break;
      default:
        newWeight = (_foods[index]['weight_g'] as num?)?.toDouble() ?? 100.0;
    }
    setState(() {
      _foods[index]['serving_label'] = unit;
      _foods[index]['weight_g'] = newWeight;
      _foods[index]['serving'] = _getServingStringFromUnit(unit);
    });
    _updateItemMacros(index);
  }

  String _getServingStringFromUnit(String unit) {
    switch (unit) {
      case 'half_bowl': return 'Half Bowl';
      case 'one_bowl': return 'One Bowl';
      case 'two_bowls': return 'Two Bowls';
      case 'one_cup': return 'One Cup';
      case 'half_cup': return 'Half Cup';
      case 'one_chapati': return 'One Chapati';
      case 'two_chapatis': return 'Two Chapatis';
      case 'one_idli': return 'One Idli';
      case 'three_idlis': return 'Three Idlis';
      default: return 'Custom serving';
    }
  }

  // Aggregated totals
  int get _totalCalories => _foods.fold(0, (sum, f) => sum + ((f['calories'] as num?)?.toInt() ?? 0));
  double get _totalProtein => _foods.fold(0.0, (sum, f) => sum + ((f['protein'] as num?)?.toDouble() ?? 0.0));
  double get _totalCarbs => _foods.fold(0.0, (sum, f) => sum + ((f['carbs'] as num?)?.toDouble() ?? 0.0));
  double get _totalFat => _foods.fold(0.0, (sum, f) => sum + (((f['fat'] ?? f['fats']) as num?)?.toDouble() ?? 0.0));
  double get _totalFiber => _foods.fold(0.0, (sum, f) => sum + ((f['fiber'] as num?)?.toDouble() ?? 0.0));

  /// True if any food item still has 0 calories (nutrition data missing)
  bool get _hasMissingNutrition => _foods.any((f) => ((f['calories'] as num?)?.toInt() ?? 0) == 0);


  void _deleteFood(int index) {
    setState(() {
      _foods.removeAt(index);
      // Shift density dictionary indices
      final temp = Map<int, Map<String, double>>.from(_macroDensities);
      _macroDensities.clear();
      int newIdx = 0;
      for (var key in temp.keys) {
        if (key != index) {
          _macroDensities[newIdx] = temp[key]!;
          newIdx++;
        }
      }
    });
  }

  void _addCustomFood() {
    setState(() {
      final newIndex = _foods.length;
      final newFood = {
        "food_name": "Custom Food Item",
        "weight_g": 100.0,
        "calories": 120,
        "protein": 4.0,
        "carbs": 20.0,
        "fat": 2.5,
        "fiber": 1.0,
        "confidence": 100.0,
        "confidence_level": "high",
        "cooking_method": "cooked",
        "ingredients": []
      };
      _foods.add(newFood);
      
      _macroDensities[newIndex] = {
        'calories': 120 / 100.0,
        'protein': 4.0 / 100.0,
        'carbs': 20.0 / 100.0,
        'fat': 2.5 / 100.0,
        'fiber': 1.0 / 100.0,
      };
    });
  }

  Future<void> _saveMeal() async {
    // 7-day trial / Pro subscription gatekeeper
    final canAccess = ref.read(subscriptionProvider.notifier).guardPremiumFeature(
      context,
      featureName: 'AI Meal Scans',
    );
    if (!canAccess) return;

    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log at least one food item.')),
      );
      return;
    }

    if (_hasMissingNutrition) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Some food items are missing nutrition data. Please remove them or check your image.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    // Derive generic meal plate summary name
    String mealSummaryName = _foods.map((f) => f['food_name']).join(', ');
    if (mealSummaryName.length > 40) {
      mealSummaryName = "${_foods[0]['food_name']} plate";
    }

    final payload = {
      "name": mealSummaryName,
      "total_calories": _totalCalories,
      "protein": double.parse(_totalProtein.toStringAsFixed(1)),
      "carbs": double.parse(_totalCarbs.toStringAsFixed(1)),
      "fat": double.parse(_totalFat.toStringAsFixed(1)),
      "fiber": double.parse(_totalFiber.toStringAsFixed(1)),
      "image_url": _currentImagePath,
      "foods": _foods.map((f) => {
        "food_name": f['food_name'],
        "weight_g": (f['weight_g'] as num).toDouble(),
        "calories": (f['calories'] as num).toInt(),
        "protein": (f['protein'] as num).toDouble(),
        "carbs": (f['carbs'] as num).toDouble(),
        "fat": (f['fat'] as num).toDouble(),
        "fiber": (f['fiber'] as num).toDouble(),
        "confidence": (f['confidence'] as num).toDouble(),
        "cooking_method": f['cooking_method'] ?? "cooked",
        "ingredients": List<String>.from(f['ingredients'] ?? [])
      }).toList()
    };

    final res = await AiFoodLoggingService.saveMeal(payload);

    setState(() {
      _isSaving = false;
    });

    if (res['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Meal successfully saved! Daily nutrition updated.'),
          backgroundColor: const Color(0xFF007AFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Return to home dashboard screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMsg = res['error'] ?? "Failed to save the logged meal. Please try again.";
      });
    }
  }

  void _confirmDiscardScan() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Text(
              'Discard Food Scan?',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to undo and discard this meal scan? No nutrition data will be saved to your journal.',
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Editing',
              style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'Discard & Exit',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retakePhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        openAppSettings();
        return;
      }
      if (status.isDenied) return;
    }

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;
      _showPreScanModal(pickedFile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetaking = false;
        _errorMsg = "Failed to access photo. Please try again.";
      });
    }
  }

  void _showPreScanModal(XFile pickedFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 1.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.file(
                  File(pickedFile.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF38BDF8), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'AI VISION SCANNER READY',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF38BDF8),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Text(
              'Analyze New Meal Photo?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Our AI engine will scan your new photo to recalculate food items, portion weights, and macro breakdown.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _processRetakeMeal(pickedFile.path);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Scan with AI Now',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _retakePhoto(ImageSource.camera);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Retake Photo',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRetakeMeal(String imagePath) async {
    setState(() {
      _isRetaking = true;
      _retakeStatusText = "AI Recognizing New Photo...";
      _errorMsg = null;
    });

    final res = await AiFoodLoggingService.analyzeMeal(imagePath);

    if (res['success'] == true && res['data'] != null) {
      final rawData = res['data'];
      List<Map<String, dynamic>> newFoodsList = [];
      if (rawData is Map && rawData['foods'] is List) {
        newFoodsList = (rawData['foods'] as List).map((f) => Map<String, dynamic>.from(f as Map)).toList();
      } else if (rawData is Map && rawData.containsKey('name')) {
        newFoodsList = [Map<String, dynamic>.from(rawData)];
      }

      if (!mounted) return;
      setState(() {
        _currentImagePath = imagePath;
        _foods = newFoodsList;
        _macroDensities.clear();
        _calculateDensities();
        _isRetaking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New meal photo scanned successfully!'),
          backgroundColor: const Color(0xFF007AFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _isRetaking = false;
        _errorMsg = res['error'] as String? ?? "Failed to analyze new image.";
      });
    }
  }

  void _showRetakeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Retake or Replace Photo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a clearer picture or pick another photo from gallery',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF007AFF)),
              ),
              title: Text('Take New Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              subtitle: Text('Open camera to capture plate again', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _retakePhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
              ),
              title: Text('Upload from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              subtitle: Text('Choose a different photo from your photos', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _retakePhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF007AFF);

    return WillPopScope(
      onWillPop: () async {
        _confirmDiscardScan();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.primary),
            onPressed: _confirmDiscardScan,
          ),
          title: Text(
            'Review Meal',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _confirmDiscardScan,
              child: Text(
                'Discard',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _isSaving
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: accentBlue),
                        SizedBox(height: 16),
                        Text('Saving to Nutrition Journal...', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Preview & Total Calories Card
                        _buildHeaderSummaryCard(),
                        const SizedBox(height: 20),
                        
                        if (_errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Text(
                              _errorMsg!,
                              style: GoogleFonts.inter(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],

                        Text(
                          'Detected Food Items',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _foods.length,
                          itemBuilder: (context, index) {
                            return _buildFoodItemCard(index);
                          },
                        ),

                        const SizedBox(height: 12),
                        // Add Custom Item Button
                        GestureDetector(
                          onTap: _addCustomFood,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, color: accentBlue, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add Missing Food Item',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

            // High Contrast Retaking Overlay
            if (_isRetaking)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 3.5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _retakeStatusText,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              // Discard / Undo Button
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: _confirmDiscardScan,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.undo_rounded, color: Color(0xFF64748B), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Discard',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save Meal Button
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _saveMeal,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentBlue,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentBlue.withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save Meal',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _buildHeaderSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Image Preview with interactive Retake badge
          GestureDetector(
            onTap: _showRetakeModal,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Image.file(
                      File(_currentImagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          'Retake',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_totalCalories kcal',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  'Estimated Total calories',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                // Compact Linear macro indicators
                Row(
                  children: [
                    _buildCompactMacroDot('P', '${_totalProtein.toStringAsFixed(1)}g', AppTheme.proteinColor),
                    const SizedBox(width: 12),
                    _buildCompactMacroDot('C', '${_totalCarbs.toStringAsFixed(1)}g', AppTheme.carbsColor),
                    const SizedBox(width: 12),
                    _buildCompactMacroDot('F', '${_totalFat.toStringAsFixed(1)}g', AppTheme.fatsColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMacroDot(String initial, String val, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$initial: ',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
        ),
        Text(
          val,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildFoodItemCard(int index) {
    final food = _foods[index];
    final String name = food['food_name'] ?? 'Food Item';
    final double weight = (food['weight_g'] as num?)?.toDouble() ?? 100.0;
    final int cal = (food['calories'] as num?)?.toInt() ?? 0;
    final double prot = (food['protein'] as num?)?.toDouble() ?? 0.0;
    final double carb = (food['carbs'] as num?)?.toDouble() ?? 0.0;
    final double fat = (food['fat'] as num?)?.toDouble() ?? 0.0;
    final double confidence = (food['confidence'] as num?)?.toDouble() ?? 80.0;
    final String level = food['confidence_level'] ?? 'medium';
    final List<dynamic> ingredients = food['ingredients'] ?? [];

    const Color accentBlue = Color(0xFF007AFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Confidence Badge
              _buildConfidenceBadge(level, confidence),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteFood(index),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Food Name TextField
          TextFormField(
            initialValue: name,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              hintText: 'Enter food name',
            ),
            onChanged: (val) {
              _foods[index]['food_name'] = val;
            },
          ),
          const SizedBox(height: 8),
          // Portion Type & Cooking Method Dropdowns
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portion / Serving',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _getServingLabel(food),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 'custom', child: Text('Custom (Grams)')),
                            DropdownMenuItem(value: 'half_bowl', child: Text('Half Bowl')),
                            DropdownMenuItem(value: 'one_bowl', child: Text('One Bowl')),
                            DropdownMenuItem(value: 'two_bowls', child: Text('Two Bowls')),
                            DropdownMenuItem(value: 'one_cup', child: Text('One Cup')),
                            DropdownMenuItem(value: 'half_cup', child: Text('Half Cup')),
                            DropdownMenuItem(value: 'one_chapati', child: Text('One Chapati')),
                            DropdownMenuItem(value: 'two_chapatis', child: Text('Two Chapatis')),
                            DropdownMenuItem(value: 'one_idli', child: Text('One Idli')),
                            DropdownMenuItem(value: 'three_idlis', child: Text('Three Idlis')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _updateItemServingUnit(index, val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cooking Method',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: (food['cooking_method'] as String? ?? 'cooked').toLowerCase(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 'cooked', child: Text('Cooked')),
                            DropdownMenuItem(value: 'fried', child: Text('Fried')),
                            DropdownMenuItem(value: 'boiled', child: Text('Boiled')),
                            DropdownMenuItem(value: 'steamed', child: Text('Steamed')),
                            DropdownMenuItem(value: 'grilled', child: Text('Grilled')),
                            DropdownMenuItem(value: 'roasted', child: Text('Roasted')),
                            DropdownMenuItem(value: 'baked', child: Text('Baked')),
                            DropdownMenuItem(value: 'raw', child: Text('Raw')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _foods[index]['cooking_method'] = val;
                              });
                              _updateItemMacros(index);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weight Portion Adjuster (+ / - Buttons)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Weight',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _updateItemWeight(index, weight - 10.0),
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${weight.toInt()} g',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _updateItemWeight(index, weight + 10.0),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: accentBlue),
                  ),
                ],
              ),
            ],
          ),

          // Live Nutrient breakdowns
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNutritionLabel('Calories', '$cal kcal', AppTheme.neonIndigo),
              _buildNutritionLabel('Protein', '${prot.toStringAsFixed(1)}g', AppTheme.proteinColor),
              _buildNutritionLabel('Carbs', '${carb.toStringAsFixed(1)}g', AppTheme.carbsColor),
              _buildNutritionLabel('Fat', '${fat.toStringAsFixed(1)}g', AppTheme.fatsColor),
            ],
          ),

          // Confidence System prompts
          if (level == 'medium') ...[
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentBlue.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: accentBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Is this $name?',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _foods[index]['confidence_level'] = 'high';
                        _foods[index]['confidence'] = 98.0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        'Yes',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _foods[index]['confidence_level'] = 'low';
                        _foods[index]['confidence'] = 40.0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        'No',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Confidence under 70%: Show alternate choices chips
          if (level == 'low') ...[
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Text(
              'Select correct food alternative:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAlternateChip(index, "Chicken Biryani"),
                _buildAlternateChip(index, "Masala Dosa"),
                _buildAlternateChip(index, "Idli"),
                _buildAlternateChip(index, "Dal Khichdi"),
              ],
            ),
          ],

          if (ingredients.isNotEmpty) ...[
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Text(
              'Visible ingredients: ${ingredients.join(", ")}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlternateChip(int foodIndex, String altName) {
    return ActionChip(
      label: Text(
        altName,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onPressed: () {
        setState(() {
          _foods[foodIndex]['food_name'] = altName;
          _foods[foodIndex]['confidence_level'] = 'high';
          _foods[foodIndex]['confidence'] = 100.0;
          
          // Re-calculate macro densities for the new match instantly by dividing base values by 100
          // This keeps zero latency edits working for the new food choice.
          // In practice, we will use the standard default database values of the new match.
          // Let's configure them to match standard values of our new item
          final Map<String, double> standardCalDensities = {
            "Chicken Biryani": 1.63,
            "Masala Dosa": 1.95,
            "Idli": 0.98,
            "Dal Khichdi": 1.22
          };
          
          final Map<String, List<double>> standardMacroDensities = {
            "Chicken Biryani": [0.085, 0.192, 0.058, 0.012],
            "Masala Dosa": [0.038, 0.295, 0.068, 0.018],
            "Idli": [0.022, 0.218, 0.003, 0.009],
            "Dal Khichdi": [0.042, 0.210, 0.024, 0.025]
          };

          final String key = altName;
          final double currentWeight = (_foods[foodIndex]['weight_g'] as num).toDouble();
          
          final double calRatio = standardCalDensities[key] ?? 1.20;
          final List<double> macros = standardMacroDensities[key] ?? [0.04, 0.20, 0.02, 0.01];
          
          _macroDensities[foodIndex] = {
            'calories': calRatio,
            'protein': macros[0],
            'carbs': macros[1],
            'fat': macros[2],
            'fiber': macros[3],
          };

          // Re-trigger update weight to calculate the new calories instantly
          _updateItemWeight(foodIndex, currentWeight);
        });
      },
    );
  }

  Widget _buildConfidenceBadge(String level, double confidence) {
    Color bg = Colors.green[50]!;
    Color text = Colors.green[800]!;
    String label = "High Match (${confidence.toInt()}%)";

    if (level == 'medium') {
      bg = Colors.amber[50]!;
      text = Colors.amber[800]!;
      label = "Medium Match (${confidence.toInt()}%)";
    } else if (level == 'low') {
      bg = Colors.red[50]!;
      text = Colors.red[800]!;
      label = "Low Match (${confidence.toInt()}%)";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  Widget _buildNutritionLabel(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
