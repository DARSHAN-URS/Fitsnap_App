import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  double _weight = 76.4; // kg
  double _height = 178.0; // cm
  String _selectedGoal = 'Build Muscle';

  final List<Map<String, dynamic>> _goalsList = [
    {'name': 'Lose Weight', 'icon': Icons.trending_down_rounded, 'color': AppTheme.caloriesColor},
    {'name': 'Maintain Weight', 'icon': Icons.remove_rounded, 'color': AppTheme.neonAmber},
    {'name': 'Build Muscle', 'icon': Icons.fitness_center_rounded, 'color': AppTheme.neonEmerald},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Darshan Urs');
    _ageController = TextEditingController(text: '25');
    _loadPersonalDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('profile_name') ?? 'Darshan Urs';
      _ageController.text = prefs.getString('profile_age') ?? '25';
      _weight = prefs.getDouble('profile_weight') ?? 76.4;
      _height = prefs.getDouble('profile_height') ?? 178.0;
      _selectedGoal = prefs.getString('profile_goal') ?? 'Build Muscle';
    });
  }

  Future<void> _savePersonalDetails() async {
    final name = _nameController.text.trim();
    final ageStr = _ageController.text.trim();
    final age = int.tryParse(ageStr) ?? 25;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_age', ageStr);
    await prefs.setDouble('profile_weight', _weight);
    await prefs.setDouble('profile_height', _height);
    await prefs.setString('profile_goal', _selectedGoal);

    if (ApiService.isAuthenticated) {
      final res = await ApiService.updateProfile(
        name: name,
        age: age,
        weight: _weight,
        height: _height,
        goals: _selectedGoal,
      );
      if (!res['success']) {
        debugPrint('Failed to sync profile: ${res['error']}');
      }
    }
  }

  void _saveDetails() async {
    if (_formKey.currentState!.validate()) {
      await _savePersonalDetails();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Personal details updated successfully!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.neonEmerald,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Personal Details',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Keep your health metrics updated to ensure highly accurate calorie target budgets.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Inputs Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.cardRadius,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name input
                    Text(
                      'Display Name',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.black38, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Age input
                    Text(
                      'Age (Years)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: Icon(Icons.calendar_today_rounded, color: Colors.black38, size: 18),
                        ),
                        validator: (value) {
                          if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                            return 'Enter a valid age';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metrics Card (Weight & Height Slider)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.cardRadius,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weight slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weight',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                        ),
                        Text(
                          '${_weight.toStringAsFixed(1)} kg',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.accent),
                        ),
                      ],
                    ),
                    Slider(
                      value: _weight,
                      min: 40.0,
                      max: 150.0,
                      activeColor: AppTheme.accent,
                      inactiveColor: const Color(0xFFF1F5F9),
                      onChanged: (val) => setState(() => _weight = val),
                    ),
                    const SizedBox(height: 12),

                    // Height slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Height',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                        ),
                        Text(
                          '${_height.toInt()} cm',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.neonPink),
                        ),
                      ],
                    ),
                    Slider(
                      value: _height,
                      min: 120.0,
                      max: 220.0,
                      activeColor: AppTheme.neonPink,
                      inactiveColor: const Color(0xFFF1F5F9),
                      onChanged: (val) => setState(() => _height = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fitness Goal Grid Selector
              Text(
                'Weekly Goal Target',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: _goalsList.map((goal) {
                  final isSelected = _selectedGoal == goal['name'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(
                        color: isSelected ? (goal['color'] as Color).withOpacity(0.4) : const Color(0xFFF1F5F9),
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (goal['color'] as Color).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(goal['icon'], color: goal['color'], size: 20),
                      ),
                      title: Text(
                        goal['name'],
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: goal['color'] as Color)
                          : const Icon(Icons.circle_outlined, color: Colors.black26),
                      onTap: () => setState(() => _selectedGoal = goal['name']),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppTheme.primaryGradient,
                ),
                child: ElevatedButton(
                  onPressed: _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Save Details',
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
      ),
    );
  }
}
