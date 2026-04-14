import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_provider.dart';
import '../providers/step_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/water_provider.dart';
import '../services/health_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeTab = 0; // 0 for BMI/Stats, 1 for Goals

  late TextEditingController _nameController;
  late TextEditingController _stepController;
  late TextEditingController _calorieController;
  late TextEditingController _waterController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final stepProvider = Provider.of<StepProvider>(context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final user = authProvider.user;
    
    _nameController = TextEditingController(text: (user?['full_name'] ?? '').toString());
    _stepController = TextEditingController(text: stepProvider.stepGoal.toString());
    _calorieController = TextEditingController(text: mealProvider.calorieGoal.toInt().toString());
    _waterController = TextEditingController(text: waterProvider.targetAmount.toString());
    _weightController = TextEditingController(text: (user?['weight'] ?? '75').toString());
    _heightController = TextEditingController(text: (user?['height'] ?? '175').toString());
    _ageController = TextEditingController(text: (user?['age'] ?? '25').toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stepController.dispose();
    _calorieController.dispose();
    _waterController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final stepProvider = Provider.of<StepProvider>(context, listen: false);
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final newStepGoal = int.tryParse(_stepController.text);
    final newCalorieGoal = double.tryParse(_calorieController.text);
    final newWaterGoal = int.tryParse(_waterController.text);
    
    if (newStepGoal != null) stepProvider.updateStepGoal(newStepGoal);
    if (newCalorieGoal != null) mealProvider.setCalorieGoal(newCalorieGoal);
    if (newWaterGoal != null) waterProvider.updateTargetAmount(newWaterGoal);

    await authProvider.updateProfile({
      'full_name': _nameController.text,
      'weight': double.tryParse(_weightController.text),
      'height': double.tryParse(_heightController.text),
      'age': int.tryParse(_ageController.text),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  double _calculateBMI() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = (double.tryParse(_heightController.text) ?? 0) / 100;
    if (height == 0) return 0;
    return weight / (height * height);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(user),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  _buildTabToggle(),
                  const SizedBox(height: 32),
                  _activeTab == 0 ? _buildBodyStatsView() : _buildGoalsView(),
                  const SizedBox(height: 32),
                  _buildSettingsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton(0, 'Body Stats')),
          Expanded(child: _tabButton(1, 'Daily Goals')),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    bool isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5E3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blueGrey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyStatsView() {
    final bmi = _calculateBMI();
    return Column(
      children: [
        _buildStatsSummary(bmi),
        const SizedBox(height: 24),
        _buildInputGroup([
          _buildGoalField(controller: _nameController, label: 'Display Name', icon: Icons.person_outline_rounded, iconColor: Colors.tealAccent),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(controller: _weightController, label: 'Weight (kg)', icon: Icons.monitor_weight_rounded, iconColor: Colors.blueAccent),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(controller: _heightController, label: 'Height (cm)', icon: Icons.height_rounded, iconColor: Colors.purpleAccent),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(controller: _ageController, label: 'Age', icon: Icons.cake_rounded, iconColor: Colors.orangeAccent),
        ]),
        const SizedBox(height: 32),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildGoalsView() {
    return Column(
      children: [
        _buildInputGroup([
          _buildGoalField(controller: _stepController, label: 'Daily Steps Goal', icon: Icons.directions_walk_rounded, iconColor: Colors.greenAccent),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(controller: _calorieController, label: 'Daily Calorie Goal', icon: Icons.local_fire_department_rounded, iconColor: const Color(0xFFFF5E3A)),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(controller: _waterController, label: 'Hydration Goal (ml)', icon: Icons.water_drop_rounded, iconColor: Colors.blueAccent),
        ]),
        const SizedBox(height: 32),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildStatsSummary(double bmi) {
    String bmiStatus = 'Normal';
    if (bmi < 18.5) bmiStatus = 'Underweight';
    else if (bmi >= 25 && bmi < 30) bmiStatus = 'Overweight';
    else if (bmi >= 30) bmiStatus = 'Obese';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat('Current BMI', bmi.toStringAsFixed(1), const Color(0xFFFF5E3A)),
          Container(width: 1, height: 40, color: Colors.blueGrey.withOpacity(0.2)),
          _summaryStat('Status', bmiStatus, Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildInputGroup(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5E3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              _settingsTile(Icons.sync_rounded, 'Sync Health Data', () async {
                final health = HealthService();
                if (await health.authorize()) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synced!'), backgroundColor: Colors.green));
                }
              }),
              const Divider(height: 1, color: Colors.white10),
              _settingsTile(Icons.logout_rounded, 'Log Out', () => Provider.of<AuthProvider>(context, listen: false).logout(), isDestructive: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user) {
    final displayName = user?['full_name'] != null && user!['full_name'].toString().trim().isNotEmpty 
        ? user['full_name'].toString()
        : user?['email']?.toString().split('@')[0] ?? 'User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 32, left: 24, right: 24),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(bottom: Radius.circular(40))),
      child: Column(
        children: [
          Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white))]),
          const CircleAvatar(radius: 45, backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person_rounded, size: 50, color: Colors.white)),
          const SizedBox(height: 16),
          Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(user?['email']?.toString() ?? '', style: TextStyle(color: Colors.blueGrey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGoalField({required TextEditingController controller, required String label, required IconData icon, required Color iconColor}) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 22)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 11)),
              TextField(controller: controller, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
        ),
      ],
    );
  }
}
