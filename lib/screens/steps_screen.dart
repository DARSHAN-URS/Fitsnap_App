import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/step_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/water_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/measurement_provider.dart';
import '../widgets/app_logo.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  String _selectedChart = 'Steps Trend';

  final List<Map<String, dynamic>> _chartOptions = [
    {'label': 'Steps Trend', 'icon': Icons.directions_walk_rounded, 'color': Color(0xFF3ABEF9)},
    {'label': 'Weight Trend', 'icon': Icons.monitor_weight_rounded, 'color': Color(0xFF69F0AE)},
    {'label': 'Calories Trend', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFFFAB40)},
    {'label': 'Protein Intake', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFFF5252)},
    {'label': 'Carbs Intake', 'icon': Icons.bakery_dining_rounded, 'color': Color(0xFF40C4FF)},
    {'label': 'Fat Intake', 'icon': Icons.opacity_rounded, 'color': Color(0xFFFFD740)},
    {'label': 'Water Intake', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF40C4FF)},
    {'label': 'Waist Measurement', 'icon': Icons.straighten_rounded, 'color': Color(0xFF3ABEF9)},
    {'label': 'Chest Measurement', 'icon': Icons.straighten_rounded, 'color': Colors.orangeAccent},
    {'label': 'Hips Measurement', 'icon': Icons.straighten_rounded, 'color': Colors.purpleAccent},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      appBar: AppBar(
        title: const AppLogo(fontSize: 22),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildChartDropdown(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildSelectedChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartDropdown() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedChart,
          dropdownColor: const Color(0xFF1A2636),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3ABEF9)),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          items: _chartOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['label'],
              child: Row(
                children: [
                  Icon(option['icon'], color: option['color'], size: 20),
                  const SizedBox(width: 12),
                  Text(option['label']),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedChart = newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectedChart() {
    final stepProvider = Provider.of<StepProvider>(context);
    final mealProvider = Provider.of<MealProvider>(context);
    final waterProvider = Provider.of<WaterProvider>(context);
    final progressProvider = Provider.of<ProgressProvider>(context);
    final measurementProvider = Provider.of<MeasurementProvider>(context);

    Widget chart;
    String title = _selectedChart;
    Color color = Colors.white;

    switch (_selectedChart) {
      case 'Steps Trend':
        color = const Color(0xFF3ABEF9);
        chart = _buildLineChart(List<double>.from(stepProvider.weeklySteps.map((s) => s.stepCount.toDouble())), color);
        break;
      case 'Weight Trend':
        color = const Color(0xFF69F0AE);
        chart = _buildLineChart(List<double>.from(progressProvider.weeklyWeight.map((w) => (w['weight'] as num).toDouble())), color, showDots: true);
        break;
      case 'Calories Trend':
        color = const Color(0xFFFFAB40);
        chart = _buildLineChart(List<double>.from(mealProvider.weeklyMacros.map((m) => (m['calories'] as num).toDouble())), color);
        break;
      case 'Protein Intake':
        color = const Color(0xFFFF5252);
        chart = _buildBarChart(List<double>.from(mealProvider.weeklyMacros.map((m) => (m['protein'] as num).toDouble())), color);
        break;
      case 'Carbs Intake':
        color = const Color(0xFF40C4FF);
        chart = _buildBarChart(List<double>.from(mealProvider.weeklyMacros.map((m) => (m['carbs'] as num).toDouble())), color);
        break;
      case 'Fat Intake':
        color = const Color(0xFFFFD740);
        chart = _buildBarChart(List<double>.from(mealProvider.weeklyMacros.map((m) => (m['fat'] as num).toDouble())), color);
        break;
      case 'Water Intake':
        color = const Color(0xFF40C4FF);
        chart = _buildBarChart(List<double>.from(waterProvider.weeklyWater.map((w) => (w['amount_ml'] as num).toDouble())), color);
        break;
      case 'Waist Measurement':
        color = const Color(0xFF3ABEF9);
        chart = _buildLineChart(List<double>.from(measurementProvider.measurements.map((m) => m.waist ?? 0)), color, showDots: true);
        break;
      case 'Chest Measurement':
        color = Colors.orangeAccent;
        chart = _buildLineChart(List<double>.from(measurementProvider.measurements.map((m) => m.chest ?? 0)), color, showDots: true);
        break;
      case 'Hips Measurement':
        color = Colors.purpleAccent;
        chart = _buildLineChart(List<double>.from(measurementProvider.measurements.map((m) => m.hips ?? 0)), color, showDots: true);
        break;
      default:
        chart = const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChartCard(title, chart, color),
        const SizedBox(height: 30),
        _buildSummaryInfo(title, color),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('WEEKLY', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(height: 250, child: chart),
        ],
      ),
    );
  }

  Widget _buildSummaryInfo(String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Showing your $title progress for the last 7 days. Consistency is key to reaching your targets!',
              style: TextStyle(color: Colors.blueGrey[300], fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<double> data, Color color, {bool showDots = false}) {
    if (data.isEmpty) return _buildEmptyState();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text('${index + 1}d', style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: showDots),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<double> data, Color color) {
    if (data.isEmpty) return _buildEmptyState();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text('${index + 1}d', style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: color,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarRodData(
                show: true,
                toY: data.reduce((a, b) => a > b ? a : b) * 1.2,
                color: Colors.white.withOpacity(0.03),
              ),
            )
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, color: Colors.white12, size: 48),
          SizedBox(height: 16),
          Text('No data recorded for this period', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
