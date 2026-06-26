import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/ai_food_logging_service.dart';
import '../theme/app_theme.dart';
import '../dashboard_screen.dart';

class MealReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialFoods;
  final String imagePath;

  const MealReviewScreen({
    super.key,
    required this.initialFoods,
    required this.imagePath,
  });

  @override
  State<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends State<MealReviewScreen> {
  late List<Map<String, dynamic>> _foods;
  bool _isSaving = false;
  String? _errorMsg;

  // Local helper to track macro densities per gram for live zero-latency weight edits
  final Map<int, Map<String, double>> _macroDensities = {};

  @override
  void initState() {
    super.initState();
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
      final double fat = (f['fat'] as num?)?.toDouble() ?? 0.0;
      final double fib = (f['fiber'] as num?)?.toDouble() ?? 0.0;

      // Density per gram
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
  double get _totalFat => _foods.fold(0.0, (sum, f) => sum + ((f['fat'] as num?)?.toDouble() ?? 0.0));
  double get _totalFiber => _foods.fold(0.0, (sum, f) => sum + ((f['fiber'] as num?)?.toDouble() ?? 0.0));

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
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log at least one food item.')),
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
      "image_url": widget.imagePath,
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

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Confirm Meal Logging',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSaving
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: GestureDetector(
          onTap: _saveMeal,
          child: Container(
            width: double.infinity,
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
              child: Text(
                'Save Meal & Sync Stats',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
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
          // Image Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 90,
              height: 90,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
              ),
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
