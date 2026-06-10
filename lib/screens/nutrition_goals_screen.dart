import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({super.key});

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  double _calorieGoal = 2000; // kcal
  double _proteinGoal = 130;  // grams (520 kcal)
  double _carbsGoal = 220;    // grams (880 kcal)
  double _fatsGoal = 65;      // grams (585 kcal)

  // Calorie calculations from macros:
  // Protein: 4 kcal/g
  // Carbs: 4 kcal/g
  // Fats: 9 kcal/g
  int get _calculatedMacroCalories =>
      (_proteinGoal * 4 + _carbsGoal * 4 + _fatsGoal * 9).toInt();

  void _saveGoals() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Nutrition targets updated!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.neonEmerald,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int macroDiff = (_calorieGoal - _calculatedMacroCalories).abs().toInt();
    final bool showWarning = macroDiff > 150;

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
          'Nutrition Goals',
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
              'Set Daily Targets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Adjust your target calories and macronutrient ratios below.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Calorie Budget Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.caloriesColor.withOpacity(0.08), AppTheme.caloriesColor.withOpacity(0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.caloriesColor.withOpacity(0.15), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calorie Budget',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Recommended for your plan',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '${_calorieGoal.toInt()} kcal',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: AppTheme.caloriesColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _calorieGoal,
                    min: 1200,
                    max: 4500,
                    divisions: 66,
                    activeColor: AppTheme.caloriesColor,
                    inactiveColor: AppTheme.caloriesColor.withOpacity(0.12),
                    onChanged: (val) => setState(() => _calorieGoal = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Macro Budgets Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Macro Targets',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Protein Slider
                  _buildMacroSlider(
                    label: 'Protein',
                    value: _proteinGoal,
                    max: 250,
                    unitKcal: 4,
                    color: AppTheme.proteinColor,
                    onChanged: (val) => setState(() => _proteinGoal = val),
                  ),
                  const SizedBox(height: 20),

                  // Carbs Slider
                  _buildMacroSlider(
                    label: 'Carbs',
                    value: _carbsGoal,
                    max: 500,
                    unitKcal: 4,
                    color: AppTheme.carbsColor,
                    onChanged: (val) => setState(() => _carbsGoal = val),
                  ),
                  const SizedBox(height: 20),

                  // Fats Slider
                  _buildMacroSlider(
                    label: 'Fats',
                    value: _fatsGoal,
                    max: 150,
                    unitKcal: 9,
                    color: AppTheme.fatsColor,
                    onChanged: (val) => setState(() => _fatsGoal = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Macro summary calculation details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculated Macro Calories',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P: ${(_proteinGoal * 4).toInt()} + C: ${(_carbsGoal * 4).toInt()} + F: ${(_fatsGoal * 9).toInt()} = $_calculatedMacroCalories kcal',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Friendly warning alert
            if (showWarning) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade100, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your macro goals calculate to $_calculatedMacroCalories kcal, which differs from your main budget of ${_calorieGoal.toInt()} kcal by $macroDiff kcal.',
                        style: GoogleFonts.inter(color: Colors.amber.shade900, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 36),

            // Save Button
            Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppTheme.primaryGradient,
              ),
              child: ElevatedButton(
                onPressed: _saveGoals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Save Target Goals',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

  Widget _buildMacroSlider({
    required String label,
    required double value,
    required double max,
    required int unitKcal,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final int kcalVal = (value * unitKcal).toInt();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                ),
              ],
            ),
            Text(
              '${value.toInt()}g ($kcalVal kcal)',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: color),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 10,
          max: max,
          activeColor: color,
          inactiveColor: color.withOpacity(0.12),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
