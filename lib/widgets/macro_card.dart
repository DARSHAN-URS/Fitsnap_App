import 'package:flutter/material.dart';

class MacroCard extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;

  const MacroCard({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.proteinGoal = 150,
    this.carbsGoal = 250,
    this.fatGoal = 70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macronutrients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          _buildMacroRow('Protein', protein, proteinGoal, Colors.orangeAccent),
          const SizedBox(height: 16),
          _buildMacroRow('Carbs', carbs, carbsGoal, Colors.blueAccent),
          const SizedBox(height: 16),
          _buildMacroRow('Fat', fat, fatGoal, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, double current, double goal, Color color) {
    final progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${current.toInt()}g / ${goal.toInt()}g',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
