import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/preferences_helper.dart';
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
  final TextEditingController _customAllergyController = TextEditingController();
  
  double _weight = 76.4; // kg
  double _height = 178.0; // cm
  String _selectedGoal = 'Build Muscle';
  String _gender = 'Male';
  List<String> _selectedAllergies = [];

  final List<Map<String, dynamic>> _goalsList = [
    {'name': 'Lose Weight', 'icon': Icons.trending_down_rounded, 'color': AppTheme.caloriesColor},
    {'name': 'Maintain Weight', 'icon': Icons.remove_rounded, 'color': AppTheme.neonAmber},
    {'name': 'Build Muscle', 'icon': Icons.fitness_center_rounded, 'color': AppTheme.neonEmerald},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Guest User');
    _ageController = TextEditingController(text: '25');
    _loadPersonalDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _customAllergyController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalDetails() async {
    final name = await PreferencesHelper.readString('profile_name') ?? 'Guest User';
    final age = await PreferencesHelper.readString('profile_age') ?? '25';
    final weight = await PreferencesHelper.readDouble('profile_weight') ?? 76.4;
    final height = await PreferencesHelper.readDouble('profile_height') ?? 178.0;
    final goal = await PreferencesHelper.readString('profile_goal') ?? 'Build Muscle';
    final gender = await PreferencesHelper.readString('profile_gender') ?? 'Male';
    final allergies = await PreferencesHelper.readStringList('profile_allergies') ?? [];
 
    setState(() {
      _nameController.text = name;
      _ageController.text = age;
      _weight = weight;
      _height = height;
      _selectedGoal = goal;
      _gender = gender;
      _selectedAllergies = allergies;
    });
  }

  Future<void> _savePersonalDetails() async {
    final name = _nameController.text.trim();
    final ageStr = _ageController.text.trim();
    final age = int.tryParse(ageStr) ?? 25;
    
    await PreferencesHelper.saveString('profile_name', name);
    await PreferencesHelper.saveString('profile_age', ageStr);
    await PreferencesHelper.saveDouble('profile_weight', _weight);
    await PreferencesHelper.saveDouble('profile_height', _height);
    await PreferencesHelper.saveString('profile_goal', _selectedGoal);
    await PreferencesHelper.saveString('profile_goals', _selectedGoal);
    await PreferencesHelper.saveString('profile_gender', _gender);
    await PreferencesHelper.saveStringList('profile_allergies', _selectedAllergies);

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
                    const SizedBox(height: 18),

                    // Gender selection
                    Text(
                      'Gender',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _gender = 'Male'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _gender == 'Male' ? AppTheme.accent.withOpacity(0.08) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _gender == 'Male' ? AppTheme.accent : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🙋‍♂️', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Male',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _gender == 'Male' ? AppTheme.accent : AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _gender = 'Female'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _gender == 'Female' ? AppTheme.accent.withOpacity(0.08) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _gender == 'Female' ? AppTheme.accent : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🙋‍♀️', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Female',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _gender == 'Female' ? AppTheme.accent : AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

              // Allergies & Restrictions Card
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
                    Text(
                      'Allergies & Restrictions',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 12),
                    
                    // Chips Wrap
                    if (_selectedAllergies.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedAllergies.map((allergy) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  allergy,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedAllergies.remove(allergy);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Input Form
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: _customAllergyController,
                              style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Add custom allergy...',
                                hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final String text = _customAllergyController.text.trim().toLowerCase();
                            if (text.isNotEmpty && !_selectedAllergies.contains(text)) {
                              setState(() {
                                _selectedAllergies.add(text);
                                _customAllergyController.clear();
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Add',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Common allergies list
                    Text(
                      'Common: Dairy, Gluten, Nuts, Soy, Eggs, Shellfish',
                      style: GoogleFonts.inter(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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
