import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../dashboard_screen.dart';
import '../utils/preferences_helper.dart';
import '../theme/sabtrack_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0 to 5
  bool _isLoading = false;

  // State Variables gathered during onboarding
  String _gender = ''; // 'Male' or 'Female'
  final TextEditingController _ageController = TextEditingController(text: '');
  
  // Height & Weight units & controllers
  String _heightUnit = 'cm'; // 'cm' or 'ft'
  final TextEditingController _heightController = TextEditingController(text: '175');
  
  String _weightUnit = 'kg'; // 'kg' or 'lbs'
  final TextEditingController _weightController = TextEditingController(text: '75');
  final TextEditingController _targetWeightController = TextEditingController(text: '70');

  // Fitness Goal selection
  String _selectedGoal = ''; // 'Lose Weight', 'Build Muscle', 'Stay Fit', 'Improve Endurance'
  String _selectedActivity = 'Moderately Active';

  // Allergies & Restrictions
  final List<String> _selectedAllergies = [];
  final TextEditingController _customAllergyController = TextEditingController();

  // Referral Code Variables
  final TextEditingController _referralCodeController = TextEditingController();
  bool _referralApplied = false;
  String? _referralMessage;
  bool _claimingReferral = false;

  final List<Map<String, String>> _commonAllergies = [
    {'name': 'Dairy', 'emoji': '🥛'},
    {'name': 'Gluten', 'emoji': '🌾'},
    {'name': 'Nuts', 'emoji': '🥜'},
    {'name': 'Soy', 'emoji': '🫘'},
    {'name': 'Eggs', 'emoji': '🥚'},
    {'name': 'Shellfish', 'emoji': '🍤'},
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _customAllergyController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    if (_currentStep < 6) {
      setState(() {
        _currentStep++;
      });
    } else {
      setState(() => _isLoading = true);

      double heightCm = double.tryParse(_heightController.text) ?? 175.0;
      if (_heightUnit == 'ft') {
        heightCm = heightCm * 30.48;
      }
      double weightKg = double.tryParse(_weightController.text) ?? 75.0;
      if (_weightUnit == 'lbs') {
        weightKg = weightKg / 2.20462;
      }
      double targetWeightKg = double.tryParse(_targetWeightController.text) ?? 70.0;
      if (_weightUnit == 'lbs') {
        targetWeightKg = targetWeightKg / 2.20462;
      }

      final displayName = await PreferencesHelper.readString('profile_name') ?? 'Fitness Enthusiast';

      // Update backend profile and compute targets
      if (ApiService.isAuthenticated) {
        final res = await ApiService.updateProfile(
          name: displayName,
          age: int.tryParse(_ageController.text.trim()) ?? 0,
          weight: weightKg,
          height: heightCm,
          goals: _selectedGoal.isEmpty ? 'Build Muscle' : _selectedGoal,
          gender: _gender.isEmpty ? 'Male' : _gender,
          activityLevel: _selectedActivity,
          targetWeight: targetWeightKg,
          goal: _selectedGoal.isEmpty ? 'Build Muscle' : _selectedGoal,
        );
        if (res['success'] && res['data'] != null) {
          final data = res['data'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('profile_bmi', (data['bmi'] as num?)?.toDouble() ?? 0.0);
          await prefs.setString('profile_bmi_category', data['bmi_category'] ?? 'Healthy');
          await prefs.setDouble('profile_bmr', (data['bmr'] as num?)?.toDouble() ?? 0.0);
          await prefs.setDouble('profile_tdee', (data['tdee'] as num?)?.toDouble() ?? 0.0);
          
          await prefs.setDouble('profile_calorie_goal', (data['target_calories'] as num?)?.toDouble() ?? 2000.0);
          await prefs.setDouble('profile_protein_goal', (data['protein_target'] as num?)?.toDouble() ?? 130.0);
          await prefs.setDouble('profile_carbs_goal', (data['carb_target'] as num?)?.toDouble() ?? 250.0);
          await prefs.setDouble('profile_fats_goal', (data['fat_target'] as num?)?.toDouble() ?? 65.0);
          await prefs.setDouble('profile_fiber_goal', (data['fiber_target'] as num?)?.toDouble() ?? 28.0);
          await prefs.setDouble('profile_water_goal', (data['water_target'] as num?)?.toDouble() ?? 2500.0);
        } else {
          debugPrint('Failed to sync profile: ${res['error']}');
        }
      }

      // Cache profile details locally in secure storage
      await PreferencesHelper.saveString('profile_age', _ageController.text);
      await PreferencesHelper.saveString('profile_gender', _gender);
      await PreferencesHelper.saveDouble('profile_height', heightCm);
      await PreferencesHelper.saveDouble('profile_weight', weightKg);
      await PreferencesHelper.saveDouble('profile_target_weight', targetWeightKg);
      await PreferencesHelper.saveString('profile_activity_level', _selectedActivity);
      await PreferencesHelper.saveString('profile_goal', _selectedGoal.isEmpty ? 'Build Muscle' : _selectedGoal);
      await PreferencesHelper.saveString('profile_goals', _selectedGoal.isEmpty ? 'Build Muscle' : _selectedGoal);
      await PreferencesHelper.saveStringList('profile_allergies', _selectedAllergies);
      await PreferencesHelper.saveBool('onboarding_completed', true);

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile completed successfully! Welcome to SABTRACK AI 🚀'),
          backgroundColor: AppTheme.neonEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentStep + 1) / 7.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildMeshBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Top Progress indicator bar
                Center(child: _buildProgressBar(progress)),
                const SizedBox(height: 24),
                
                // Screen Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildCurrentStepContent(),
                  ),
                ),
                
                // Bottom Buttons Navigation Space
                _buildNavigationButtons(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.6),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      width: 140,
      height: 5,
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 140 * progress,
            height: 5,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
        ),
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.06),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEC4899).withOpacity(0.04),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepWelcome();
      case 1:
        return _buildStepBodyMeasurements();
      case 2:
        return _buildStepFitnessGoal();
      case 3:
        return _buildStepActivityLevel();
      case 4:
        return _buildStepAllergies();
      case 5:
        return _buildStepReferralCode();
      case 6:
        return _buildStepAllSet();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 5: Referral Code
  Widget _buildStepReferralCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Got a Referral Code?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter an invite code from a friend to earn 100 bonus points! (Optional)',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 36),
        _buildTranslucentInputCard(
          controller: _referralCodeController,
          hintText: 'e.g., FIT-A1B2C3',
          icon: Icons.card_giftcard_rounded,
        ),
        const SizedBox(height: 24),
        if (_referralMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _referralApplied
                  ? const Color(0xFF10B981).withOpacity(0.08)
                  : const Color(0xFFEF4444).withOpacity(0.08),
              border: Border.all(
                color: _referralApplied
                    ? const Color(0xFF10B981).withOpacity(0.2)
                    : const Color(0xFFEF4444).withOpacity(0.2),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _referralApplied ? Icons.check_circle_outline : Icons.error_outline,
                  color: _referralApplied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _referralMessage!,
                    style: GoogleFonts.inter(
                      color: _referralApplied ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_claimingReferral || _referralApplied) ? null : _claimReferral,
            style: ElevatedButton.styleFrom(
              backgroundColor: _referralApplied ? Colors.grey.shade400 : const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _claimingReferral
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _referralApplied ? 'Code Applied ✓' : 'Apply Code',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _claimReferral() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a referral code first.')),
      );
      return;
    }

    setState(() {
      _claimingReferral = true;
      _referralMessage = null;
    });

    final res = await ApiService.claimReferralCode(code);
    setState(() {
      _claimingReferral = false;
      if (res['success']) {
        _referralApplied = true;
        _referralMessage = res['message'] ?? 'Referral code claimed successfully!';
      } else {
        _referralMessage = res['error'] ?? 'Invalid or expired referral code';
      }
    });
  }

  // STEP 0: Welcome, Gender, Age
  Widget _buildStepWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // App Logo at the top of welcome onboarding
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: SabtrackLogo(size: 48),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Text(
            'Welcome To Achieving\nYour Dream',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 40),
        
        // Gender: Male option
        _buildGenderCard(
          genderLabel: 'Male',
          emoji: '🙋‍♂️',
          isSelected: _gender == 'Male',
          onTap: () => setState(() => _gender = 'Male'),
        ),
        const SizedBox(height: 16),

        // Gender: Female option
        _buildGenderCard(
          genderLabel: 'Female',
          emoji: '🙋‍♀️',
          isSelected: _gender == 'Female',
          onTap: () => setState(() => _gender = 'Female'),
        ),
        const SizedBox(height: 28),

        // Age input field
        Text(
          'Your Age',
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildTranslucentInputCard(
          controller: _ageController,
          hintText: 'Enter your age',
          icon: Icons.calendar_month_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildGenderCard({
    required String genderLabel,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF6366F1).withOpacity(0.08) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF6366F1) 
                : Colors.black.withOpacity(0.06),
            width: 1.5,
          ),
          boxShadow: isSelected ? AppTheme.glowShadow : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Your Gender ($genderLabel)',
                style: GoogleFonts.inter(
                  color: AppTheme.primary,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.black26,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Body Measurements
  Widget _buildStepBodyMeasurements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Body Measurements',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us personalize your experience',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 32),

        // Height Selection Card
        _buildMeasurementCard(
          label: 'Height',
          controller: _heightController,
          unitOptions: const ['cm', 'ft'],
          selectedUnit: _heightUnit,
          onUnitChange: (val) {
            setState(() {
              _heightUnit = val;
              if (val == 'ft') {
                double cm = double.tryParse(_heightController.text) ?? 175;
                double ft = cm / 30.48;
                _heightController.text = ft.toStringAsFixed(1);
              } else {
                double ft = double.tryParse(_heightController.text) ?? 5.7;
                double cm = ft * 30.48;
                _heightController.text = cm.toInt().toString();
              }
            });
          },
        ),
        const SizedBox(height: 20),

        // Weight Selection Card
        _buildMeasurementCard(
          label: 'Weight',
          controller: _weightController,
          unitOptions: const ['kg', 'lbs'],
          selectedUnit: _weightUnit,
          onUnitChange: _toggleWeightUnit,
        ),
        const SizedBox(height: 20),

        // Target Weight Selection Card
        _buildMeasurementCard(
          label: 'Target Weight',
          controller: _targetWeightController,
          unitOptions: const ['kg', 'lbs'],
          selectedUnit: _weightUnit,
          onUnitChange: _toggleWeightUnit,
        ),
        const SizedBox(height: 28),
        const SizedBox(height: 28),

        // Tip alert container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.06),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Your measurements help us calculate accurate active calories and macronutrient targets.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E3A8A),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementCard({
    required String label,
    required TextEditingController controller,
    required List<String> unitOptions,
    required String selectedUnit,
    required Function(String) onUnitChange,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.primary.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              // Segmented unit toggle selector
              Container(
                height: 32,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: unitOptions.map((unit) {
                    final isSelected = unit == selectedUnit;
                    return GestureDetector(
                      onTap: () => onUnitChange(unit),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            unit,
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : Colors.black45,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: Fitness Goal
  Widget _buildStepFitnessGoal() {
    final List<Map<String, String>> goals = [
      {'title': 'Lose Weight', 'desc': 'Burn fat and get lean', 'emoji': '🔥'},
      {'title': 'Build Muscle', 'desc': 'Gain strength and size', 'emoji': '💪'},
      {'title': 'Stay Fit', 'desc': 'Maintain overall health', 'emoji': '🧘'},
      {'title': 'Improve Endurance', 'desc': 'Boost stamina and energy', 'emoji': '⚡'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Your Fitness Goal',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'What would you like to achieve?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),
        ...goals.map((goal) {
          final isSelected = _selectedGoal == goal['title'];
          return GestureDetector(
            onTap: () => setState(() => _selectedGoal = goal['title']!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF6366F1).withOpacity(0.08) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF6366F1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: isSelected ? AppTheme.glowShadow : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal['title']!,
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal['desc']!,
                          style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    Text(
                      goal['emoji']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1) : Colors.black26,
                        width: 2,
                      ),
                      color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
  void _toggleWeightUnit(String val) {
    if (val == _weightUnit) return;
    setState(() {
      _weightUnit = val;
      if (val == 'lbs') {
        double kg = double.tryParse(_weightController.text) ?? 75;
        double lbs = kg * 2.20462;
        _weightController.text = lbs.toInt().toString();

        double tKg = double.tryParse(_targetWeightController.text) ?? 70;
        double tLbs = tKg * 2.20462;
        _targetWeightController.text = tLbs.toInt().toString();
      } else {
        double lbs = double.tryParse(_weightController.text) ?? 165;
        double kg = lbs / 2.20462;
        _weightController.text = kg.toInt().toString();

        double tLbs = double.tryParse(_targetWeightController.text) ?? 154;
        double tKg = tLbs / 2.20462;
        _targetWeightController.text = tKg.toInt().toString();
      }
    });
  }

  // STEP 3: Activity Level
  Widget _buildStepActivityLevel() {
    final List<Map<String, String>> activities = [
      {'title': 'Sedentary', 'desc': 'Little or no daily exercise', 'emoji': '🪑'},
      {'title': 'Lightly Active', 'desc': 'Light exercise 1-3 days/week', 'emoji': '🚶'},
      {'title': 'Moderately Active', 'desc': 'Moderate exercise 3-5 days/week', 'emoji': '🏃'},
      {'title': 'Very Active', 'desc': 'Hard exercise 6-7 days/week', 'emoji': '🚴'},
      {'title': 'Athlete', 'desc': 'Intense daily training / physical job', 'emoji': '🏋️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Your Activity Level',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How active are you on a regular basis?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),
        ...activities.map((activity) {
          final isSelected = _selectedActivity == activity['title'];
          return GestureDetector(
            onTap: () => setState(() => _selectedActivity = activity['title']!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF6366F1).withOpacity(0.08) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF6366F1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: isSelected ? AppTheme.glowShadow : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title']!,
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity['desc']!,
                          style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    Text(
                      activity['emoji']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1) : Colors.black26,
                        width: 2,
                      ),
                      color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
  // STEP 3: Allergies & Restrictions
  Widget _buildStepAllergies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Allergies & Restrictions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us create safe meal plans',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),

        // Warning orange notification box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select all that apply. You can skip this step if you don\'t have any allergies.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF78350F),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Common Allergies',
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),

        // Grid of common allergies (3 columns)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: _commonAllergies.length,
          itemBuilder: (context, index) {
            final allergy = _commonAllergies[index];
            final name = allergy['name']!;
            final emoji = allergy['emoji']!;
            final isSelected = _selectedAllergies.contains(name.toLowerCase());

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAllergies.remove(name.toLowerCase());
                  } else {
                    _selectedAllergies.add(name.toLowerCase());
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFF6366F1).withOpacity(0.08) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFF6366F1) 
                        : Colors.black.withOpacity(0.06),
                    width: 1.5,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Selected Chips list
        if (_selectedAllergies.isNotEmpty) ...[
          Text(
            'Selected (${_selectedAllergies.length})',
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAllergies.map((allergy) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allergy,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4F46E5),
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
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Custom Allergy Entry
        Text(
          'Add Custom Allergy',
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.5),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _customAllergyController,
                  style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g., Peanuts, Sesame',
                    hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    'Add',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  // STEP 4: All Set Page
  Widget _buildStepAllSet() {
    return Column(
      children: [
        const SizedBox(height: 36),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                ),
              ),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.star_rounded, color: Colors.cyan, size: 16),
              ),
              const Positioned(
                bottom: 12,
                left: 6,
                child: Icon(Icons.star_border_purple500_rounded, color: Colors.pink, size: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        Text(
          'All Set!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your personalized fitness profile is ready. Let\'s start your journey!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        _buildAllSetCard(
          title: 'Profile Complete',
          desc: 'All information saved locally and prepared',
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 14),

        _buildAllSetCard(
          title: 'Goals Set',
          desc: 'Personalized calorie and macro plan ready',
          icon: Icons.track_changes_rounded,
          iconColor: Colors.redAccent,
        ),
        const SizedBox(height: 14),

        _buildAllSetCard(
          title: 'Ready to Start',
          desc: 'Workouts and meal tracking spaces synchronized',
          icon: Icons.emoji_events_rounded,
          iconColor: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildAllSetCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: Colors.black45,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTranslucentInputCard({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black38, size: 20),
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (_currentStep > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.12), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              Expanded(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        // Form validations per step
                        if (_currentStep == 0) {
                          if (_gender.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select your gender.')),
                            );
                            return;
                          }
                          if (_ageController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your age.')),
                            );
                            return;
                          }
                          final parsedAge = int.tryParse(_ageController.text.trim());
                          if (parsedAge == null || parsedAge <= 0 || parsedAge > 120) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid age.')),
                            );
                            return;
                          }
                        } else if (_currentStep == 1) {
                          if (_heightController.text.trim().isEmpty || _weightController.text.trim().isEmpty || _targetWeightController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter height, weight, and target weight details.')),
                            );
                            return;
                          }
                        } else if (_currentStep == 2) {
                          if (_selectedGoal.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a fitness goal.')),
                            );
                            return;
                          }
                        } else if (_currentStep == 3) {
                          if (_selectedActivity.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select your activity level.')),
                            );
                            return;
                          }
                        }
                        
                        _nextStep();
                      },
                      child: Center(
                        child: Text(
                          _currentStep == 6 ? 'Start My Fitness Journey 🚀' : 'Continue',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_currentStep == 6) ...[
            const SizedBox(height: 12),
            Text(
              'You can always update your preferences in Settings',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
