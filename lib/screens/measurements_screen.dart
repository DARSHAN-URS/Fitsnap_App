import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/measurement_provider.dart';
import '../models/measurement.dart';

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  String _selectedPart = 'Waist';
  final Map<String, String> _bodyParts = {
    'Waist': 'waist',
    'Chest': 'chest',
    'Hips': 'hips',
    'Neck': 'neck',
    'Shoulders': 'shoulders',
    'Left Bicep': 'leftBicep',
    'Right Bicep': 'rightBicep',
    'Left Thigh': 'leftThigh',
    'Right Thigh': 'rightThigh',
    'Left Calf': 'leftCalf',
    'Right Calf': 'rightCalf',
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MeasurementProvider>(context);
    final measurements = provider.measurements;

    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Body Measurements', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartSection(measurements),
            const SizedBox(height: 30),
            _buildLatestMeasurements(measurements),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMeasurementModal(context),
        backgroundColor: const Color(0xFF3ABEF9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChartSection(List<Measurement> measurements) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trend: $_selectedPart', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedPart,
                dropdownColor: const Color(0xFF161F2C),
                style: const TextStyle(color: Color(0xFF3ABEF9), fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                items: _bodyParts.keys.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedPart = newValue!);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: measurements.isEmpty
                ? const Center(child: Text('No data for chart'))
                : _buildLineChart(measurements),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Measurement> measurements) {
    final spots = measurements.asMap().entries.map((entry) {
      final m = entry.value;
      double val = 0;
      switch (_selectedPart) {
        case 'Waist': val = m.waist ?? 0; break;
        case 'Chest': val = m.chest ?? 0; break;
        case 'Hips': val = m.hips ?? 0; break;
        case 'Neck': val = m.neck ?? 0; break;
        case 'Shoulders': val = m.shoulders ?? 0; break;
        case 'Left Bicep': val = m.leftBicep ?? 0; break;
        case 'Right Bicep': val = m.rightBicep ?? 0; break;
        case 'Left Thigh': val = m.leftThigh ?? 0; break;
        case 'Right Thigh': val = m.rightThigh ?? 0; break;
        case 'Left Calf': val = m.leftCalf ?? 0; break;
        case 'Right Calf': val = m.rightCalf ?? 0; break;
      }
      return FlSpot(entry.key.toDouble(), val);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3ABEF9),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF3ABEF9).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestMeasurements(List<Measurement> measurements) {
    if (measurements.isEmpty) return const SizedBox();
    final latest = measurements.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Current Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildStatItem('Chest', latest.chest),
            _buildStatItem('Waist', latest.waist),
            _buildStatItem('Hips', latest.hips),
            _buildStatItem('Shoulders', latest.shoulders),
            _buildStatItem('Neck', latest.neck),
            _buildStatItem('Biceps (L/R)', null, customVal: '${latest.leftBicep ?? 0} / ${latest.rightBicep ?? 0}'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, double? value, {String? customVal}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(customVal ?? '${value ?? 0} cm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  void _showAddMeasurementModal(BuildContext context) {
    final Map<String, TextEditingController> controllers = {};
    _bodyParts.forEach((key, value) {
      controllers[value] = TextEditingController();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161F2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Log Measurements', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Enter values in cm', style: TextStyle(color: Colors.blueGrey[400])),
              const SizedBox(height: 24),
              ..._bodyParts.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controllers[e.value],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: e.key,
                    labelStyle: const TextStyle(color: Colors.blueGrey),
                    filled: true,
                    fillColor: const Color(0xFF0B121E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              )).toList(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    final measurement = Measurement(
                      chest: double.tryParse(controllers['chest']!.text),
                      waist: double.tryParse(controllers['waist']!.text),
                      hips: double.tryParse(controllers['hips']!.text),
                      neck: double.tryParse(controllers['neck']!.text),
                      shoulders: double.tryParse(controllers['shoulders']!.text),
                      leftBicep: double.tryParse(controllers['leftBicep']!.text),
                      rightBicep: double.tryParse(controllers['rightBicep']!.text),
                      leftThigh: double.tryParse(controllers['leftThigh']!.text),
                      rightThigh: double.tryParse(controllers['rightThigh']!.text),
                      leftCalf: double.tryParse(controllers['leftCalf']!.text),
                      rightCalf: double.tryParse(controllers['rightCalf']!.text),
                      createdAt: DateTime.now(),
                    );
                    final success = await Provider.of<MeasurementProvider>(context, listen: false).addMeasurement(measurement);
                    if (success && mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ABEF9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Save Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
