import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medical_history_provider.dart';
import '../models/medical_history.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  bool _isDiabetic = false;
  bool _hasHypertension = false;
  bool _hasAllergies = false;
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _medsController = TextEditingController();
  String? _selectedBloodGroup;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = Provider.of<MedicalHistoryProvider>(context, listen: false).history;
      if (history != null) {
        setState(() {
          _isDiabetic = history.isDiabetic;
          _hasHypertension = history.hasHypertension;
          _hasAllergies = history.hasAllergies;
          _allergiesController.text = history.allergiesList?.join(', ') ?? '';
          _conditionsController.text = history.otherConditions ?? '';
          _medsController.text = history.medications ?? '';
          _selectedBloodGroup = history.bloodGroup;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Medical History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Primary Conditions'),
            _buildSwitchTile('Diabetic', _isDiabetic, (val) => setState(() => _isDiabetic = val)),
            _buildSwitchTile('Hypertension', _hasHypertension, (val) => setState(() => _hasHypertension = val)),
            _buildSwitchTile('Allergies', _hasAllergies, (val) => setState(() => _hasAllergies = val)),
            
            if (_hasAllergies) ...[
              const SizedBox(height: 16),
              _buildTextField('List Allergies', _allergiesController, 'e.g. Peanuts, Penicillin'),
            ],

            const SizedBox(height: 32),
            _buildSectionHeader('Blood Information'),
            _buildBloodGroupSelector(),

            const SizedBox(height: 32),
            _buildSectionHeader('Additional Information'),
            _buildTextField('Other Medical Conditions', _conditionsController, 'e.g. Asthma, Thyroid', maxLines: 3),
            const SizedBox(height: 16),
            _buildTextField('Current Medications', _medsController, 'e.g. Metformin 500mg', maxLines: 3),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3ABEF9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Medical History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF3ABEF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF161F2C),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodGroupSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBloodGroup,
          hint: const Text('Select Blood Group', style: TextStyle(color: Colors.blueGrey)),
          isExpanded: true,
          dropdownColor: const Color(0xFF161F2C),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey),
          items: _bloodGroups.map((group) {
            return DropdownMenuItem(
              value: group,
              child: Text(group, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedBloodGroup = val),
        ),
      ),
    );
  }

  void _saveHistory() async {
    final history = MedicalHistory(
      isDiabetic: _isDiabetic,
      hasHypertension: _hasHypertension,
      hasAllergies: _hasAllergies,
      allergiesList: _allergiesController.text.isNotEmpty ? _allergiesController.text.split(',').map((e) => e.trim()).toList() : null,
      otherConditions: _conditionsController.text.trim(),
      medications: _medsController.text.trim(),
      bloodGroup: _selectedBloodGroup,
    );

    final success = await Provider.of<MedicalHistoryProvider>(context, listen: false).updateMedicalHistory(history);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medical history updated successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }
}
