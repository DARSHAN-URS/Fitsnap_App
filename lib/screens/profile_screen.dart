import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_provider.dart';
import '../providers/step_provider.dart';
import '../providers/auth_provider.dart';
import '../services/health_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _stepController;
  late TextEditingController _calorieController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final stepProvider = Provider.of<StepProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final user = authProvider.user;
    
    _stepController = TextEditingController(text: stepProvider.stepGoal.toString());
    _calorieController = TextEditingController(text: mealProvider.calorieGoal.toInt().toString());
    _weightController = TextEditingController(text: (user?['weight'] ?? '75').toString());
    _heightController = TextEditingController(text: (user?['height'] ?? '175').toString());
    _ageController = TextEditingController(text: (user?['age'] ?? '25').toString());
  }

  @override
  void dispose() {
    _stepController.dispose();
    _calorieController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final stepProvider = Provider.of<StepProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final newStepGoal = int.tryParse(_stepController.text);
    final newCalorieGoal = double.tryParse(_calorieController.text);
    
    if (newStepGoal != null) stepProvider.updateStepGoal(newStepGoal);
    if (newCalorieGoal != null) mealProvider.setCalorieGoal(newCalorieGoal);

    await authProvider.updateProfile({
      'weight': double.tryParse(_weightController.text),
      'height': double.tryParse(_heightController.text),
      'age': int.tryParse(_ageController.text),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile and goals updated!'),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  if (authProvider.user?['is_pro'] != true) _buildProCard(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Preferences & Goals'),
                  const SizedBox(height: 16),
                  _buildGoalInputs(),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Account Settings'),
                  const SizedBox(height: 16),
                  _buildSettingsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 80, bottom: 40, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5E3A),
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF0F172A),
                  child: Icon(Icons.person_rounded, size: 60, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5E3A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?['email']?.split('@')[0].toUpperCase() ?? 'USER',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (user?['is_pro'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB053),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.black)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            user?['email'] ?? 'user@fitsnap.ai',
            style: TextStyle(color: Colors.blueGrey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildProCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB053), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Pro Features',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Get AI meal plans, unlimited gallery logs, and expert advice.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF5E3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Go Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final bmi = _calculateBMI();
    String bmiStatus = 'Normal';
    if (bmi < 18.5) bmiStatus = 'Underweight';
    else if (bmi >= 25 && bmi < 30) bmiStatus = 'Overweight';
    else if (bmi >= 30) bmiStatus = 'Obese';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard('Weight', _weightController.text, 'kg'),
        _buildStatCard('Height', _heightController.text, 'cm'),
        _buildStatCard('BMI', bmi.toStringAsFixed(1), bmiStatus),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 3,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildGoalInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildGoalField(
            controller: _stepController,
            label: 'Daily Steps Goal',
            icon: Icons.directions_walk_rounded,
            iconColor: Colors.greenAccent,
          ),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(
            controller: _calorieController,
            label: 'Daily Calorie Goal',
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF5E3A),
          ),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(
            controller: _weightController,
            label: 'Current Weight (kg)',
            icon: Icons.monitor_weight_rounded,
            iconColor: Colors.blueAccent,
          ),
          const Divider(height: 32, color: Color(0xFF334155)),
          _buildGoalField(
            controller: _heightController,
            label: 'Height (cm)',
            icon: Icons.height_rounded,
            iconColor: Colors.purpleAccent,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E3A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Update Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            Icons.sync_rounded, 
            'Sync Health Apps', 
            () async {
              final health = HealthService();
              bool authorized = await health.authorize();
              if (authorized) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Health Data Synchronized!'), 
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Health Sync Permission Denied'), 
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          _buildSettingsTile(Icons.notifications_outlined, 'Notifications', null),
          const Divider(height: 1, color: Color(0xFF334155)),
          _buildSettingsTile(Icons.lock_outline_rounded, 'Privacy & Security', null),
          const Divider(height: 1, color: Color(0xFF334155)),
          _buildSettingsTile(Icons.help_outline_rounded, 'Help Center', null),
          const Divider(height: 1, color: Color(0xFF334155)),
          _buildSettingsTile(
            Icons.logout_rounded, 
            'Log Out', 
            () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
            }, 
            isDestructive: true
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback? onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70),
      title: Text(
        title, 
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        )
      ),
      trailing: isDestructive ? null : const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }
}
