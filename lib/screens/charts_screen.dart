import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/progress_provider.dart';
import '../providers/step_provider.dart';
import '../providers/water_provider.dart';
import '../providers/meal_provider.dart';

enum ChartType { weight, activity, calories, water }

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({Key? key}) : super(key: key);

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  ChartType _selectedChart = ChartType.weight;

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final stepProvider = Provider.of<StepProvider>(context);
    final waterProvider = Provider.of<WaterProvider>(context);
    final mealProvider = Provider.of<MealProvider>(context);

    final weightData = progressProvider.weeklyWeight;
    final stepData = stepProvider.weeklySteps;
    final waterData = waterProvider.weeklyWater;
    final macroData = mealProvider.weeklyMacros;

    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Analytics', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.blueGrey),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              const Color(0xFF3ABEF9).withOpacity(0.05),
              const Color(0xFF05080E),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Quick Overview'),
              const SizedBox(height: 16),
              _buildProfessionalOverview(
                stepProvider.currentSteps,
                weightData.isNotEmpty ? weightData.last['weight'] : 0.0,
                mealProvider.todayCalories,
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('Detailed Analysis'),
              const SizedBox(height: 16),
              _buildChartSelector(),
              
              const SizedBox(height: 24),
              
              _buildSelectedChartContainer(weightData, stepData, macroData, waterData),
              
              const SizedBox(height: 32),
              _buildInsightsSection(),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.blueGrey[600],
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildProfessionalOverview(int steps, double weight, double calories) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactStatCard(
            'Steps', 
            steps.toString(), 
            Icons.directions_run_rounded, 
            const Color(0xFFFF5E3A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStatCard(
            'Weight', 
            '${weight.toStringAsFixed(1)}kg', 
            Icons.monitor_weight_outlined, 
            const Color(0xFF3ABEF9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactStatCard(
            'Calories', 
            '${calories.toInt()}', 
            Icons.local_fire_department_rounded, 
            const Color(0xFF4ADE80),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 18),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.blueGrey[400], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChartSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ChartType>(
          value: _selectedChart,
          dropdownColor: const Color(0xFF1A2636),
          icon: const Icon(Icons.expand_more_rounded, color: Colors.blueGrey),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          items: [
            _dropdownItem(ChartType.weight, 'Weight Evolution', Icons.show_chart_rounded, const Color(0xFF3ABEF9)),
            _dropdownItem(ChartType.activity, 'Step Progress', Icons.bar_chart_rounded, const Color(0xFFFF5E3A)),
            _dropdownItem(ChartType.calories, 'Energy Intake', Icons.bolt_rounded, const Color(0xFF4ADE80)),
            _dropdownItem(ChartType.water, 'Hydration Levels', Icons.water_drop_rounded, Colors.cyanAccent),
          ],
          onChanged: (ChartType? newValue) {
            if (newValue != null) {
              setState(() => _selectedChart = newValue);
            }
          },
        ),
      ),
    );
  }

  DropdownMenuItem<ChartType> _dropdownItem(ChartType value, String label, IconData icon, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSelectedChartContainer(
    List<Map<String, dynamic>> weightData,
    List<dynamic> stepData,
    List<Map<String, dynamic>> macroData,
    List<Map<String, dynamic>> waterData,
  ) {
    String title = '';
    String subtitle = '';
    Widget chart = const SizedBox.shrink();
    Color color = Colors.white;

    switch (_selectedChart) {
      case ChartType.weight:
        title = 'Weight Trend';
        subtitle = 'Tracking your progress over the last 7 days';
        chart = _buildWeightLineChart(weightData);
        color = const Color(0xFF3ABEF9);
        break;
      case ChartType.activity:
        title = 'Activity History';
        subtitle = 'Daily step count and movement patterns';
        chart = _buildActivityBarChart(stepData);
        color = const Color(0xFFFF5E3A);
        break;
      case ChartType.calories:
        title = 'Calorie Intake';
        subtitle = 'Fueling your body with consistent energy';
        chart = _buildCalorieLineChart(macroData);
        color = const Color(0xFF4ADE80);
        break;
      case ChartType.water:
        title = 'Water Intake';
        subtitle = 'Monitoring your hydration efficiency';
        chart = _buildWaterBarChart(waterData);
        color = Colors.cyanAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.blueGrey[400], fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('WEEKLY', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(height: 240, child: chart),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3ABEF9).withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3ABEF9).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3ABEF9).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3ABEF9), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Insight', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  'Your activity is up 12% from last week. Keep this momentum to reach your goal faster!',
                  style: TextStyle(color: Colors.blueGrey[300], fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightLineChart(List<Map<String, dynamic>> data) {
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
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(DateFormat('E').format(data[index]['date'])[0], 
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF1A2636),
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.y.toStringAsFixed(1)} kg',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]['weight'])),
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF3ABEF9),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFF3ABEF9),
                strokeWidth: 2,
                strokeColor: const Color(0xFF161F2C),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF3ABEF9).withOpacity(0.2), const Color(0xFF3ABEF9).withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBarChart(List<dynamic> stepData) {
    if (stepData.isEmpty) return _buildEmptyState();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 12000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF1A2636),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${rod.toY.toInt()} steps',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= stepData.length) return const SizedBox.shrink();
                final date = DateTime.parse(stepData[index].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(DateFormat('E').format(date)[0], 
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(stepData.length, (i) => 
          _makeGroupData(i, stepData[i].stepCount.toDouble(), const Color(0xFFFF5E3A), 12000)
        ),
      ),
    );
  }

  Widget _buildCalorieLineChart(List<Map<String, dynamic>> data) {
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
                  child: Text(DateFormat('E').format(data[index]['date'])[0], 
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
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
            spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]['calories'].toDouble())),
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF4ADE80),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF4ADE80).withOpacity(0.2), const Color(0xFF4ADE80).withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return _buildEmptyState();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 4000,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                final date = DateTime.parse(data[index]['date']);
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(DateFormat('E').format(date)[0], 
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) => 
          _makeGroupData(i, data[i]['amount_ml'].toDouble(), Colors.cyanAccent, 4000)
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color, double max) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarRodData(
            show: true,
            toY: max,
            color: Colors.white.withOpacity(0.03),
          ),
        ),
      ],
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
