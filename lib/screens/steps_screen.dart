import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/step_provider.dart';
import '../providers/meal_provider.dart';
import 'package:intl/intl.dart';

class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stepProvider = Provider.of<StepProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitSnap AI',
          style: TextStyle(
            color: Color(0xFFFF5E3A),
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeHeader(),
            const SizedBox(height: 20),
            _buildMetricChartCard(stepProvider),
            const SizedBox(height: 20),
            _buildSummaryStats(stepProvider),
            const SizedBox(height: 24),
            const Text("Macronutrients", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMacroHistoryChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chevron_left_rounded, color: Colors.blueGrey[400]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${fmt.format(weekStart)} - ${fmt.format(weekEnd)}, ${now.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Colors.blueGrey[400]),
      ],
    );
  }

  Widget _buildMetricChartCard(StepProvider stepProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Steps History'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 250,
            child: stepProvider.weeklySteps.isEmpty 
              ? const Center(child: Text('Logging your first week...', style: TextStyle(color: Colors.blueGrey)))
              : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < stepProvider.weeklySteps.length) {
                             final date = DateTime.parse(stepProvider.weeklySteps[value.toInt()].date);
                             return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('d/M').format(date), style: TextStyle(color: Colors.blueGrey[400], fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: stepProvider.weeklySteps.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.stepCount.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.greenAccent,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.greenAccent.withOpacity(0.1),
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

  Widget _buildSummaryStats(StepProvider stepProvider) {
    final avg = stepProvider.weeklySteps.isEmpty ? 0 : 
                stepProvider.weeklySteps.map((e) => e.stepCount).reduce((a, b) => a + b) ~/ stepProvider.weeklySteps.length;
                
    return Column(
      children: [
        _buildStatRow('Days Logged:', '${stepProvider.weeklySteps.length}'),
        _buildStatRow('Weekly Average:', '$avg steps'),
        _buildStatRow('Daily Goal:', '${stepProvider.stepGoal} steps'),
        const Divider(color: Colors.blueGrey, height: 32),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.blueGrey[300])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMacroHistoryChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _macroBar('Fat', 0.25, Colors.purple),
              _macroBar('Carbs', 0.45, Colors.teal),
              _macroBar('Protein', 0.30, Colors.yellow),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _macroLegend('Fat', Colors.purple),
              const SizedBox(width: 16),
              _macroLegend('Carbs', Colors.teal),
              const SizedBox(width: 16),
              _macroLegend('Protein', Colors.yellow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double flex, Color color) {
    return Expanded(
      flex: (flex * 100).toInt(),
      child: Container(
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _macroLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
