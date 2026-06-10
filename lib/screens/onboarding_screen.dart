import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'registration_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0 to 4

  // State Variables gathered during onboarding
  String _gender = ''; // 'Male' or 'Female'
  final TextEditingController _ageController = TextEditingController(text: '24');
  
  // Height & Weight units & controllers
  String _heightUnit = 'cm'; // 'cm' or 'ft'
  final TextEditingController _heightController = TextEditingController(text: '175');
  
  String _weightUnit = 'kg'; // 'kg' or 'lbs'
  final TextEditingController _weightController = TextEditingController(text: '75');

  // Fitness Goal selection
  String _selectedGoal = ''; // 'Lose Weight', 'Build Muscle', 'Stay Fit', 'Improve Endurance'

  // Allergies & Restrictions
  final List<String> _selectedAllergies = [];
  final TextEditingController _customAllergyController = TextEditingController();

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
    _customAllergyController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Navigate to Registration Screen, passing collected parameters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationScreen(
            gender: _gender,
            age: int.tryParse(_ageController.text) ?? 24,
            height: double.tryParse(_heightController.text) ?? 175.0,
            heightUnit: _heightUnit,
            weight: double.tryParse(_weightController.text) ?? 75.0,
            weightUnit: _weightUnit,
            goal: _selectedGoal.isEmpty ? 'Build Muscle' : _selectedGoal,
            allergies: _selectedAllergies,
          ),
        ),
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
    final double progress = (_currentStep + 1) / 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
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
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      width: 140,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 140 * progress,
            height: 5,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
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
        Container(color: const Color(0xFF030712)),
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.15),
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
              color: const Color(0xFFEC4899).withOpacity(0.1),
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
        return _buildStepAllergies();
      case 4:
        return _buildStepAllSet();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 0: Welcome, Gender, Age
  Widget _buildStepWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // App Logo at the top of welcome onboarding
        Center(
          child: Image.asset(
            'assets/images/logo.png',
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.fitness_center_rounded, color: AppTheme.accent, size: 48);
            },
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
              color: Colors.white,
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
            color: Colors.white70,
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
              ? const Color(0xFF6366F1).withOpacity(0.15) 
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF6366F1) 
                : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                    blurRadius: 16,
                  )
                ] 
              : null,
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
                  color: isSelected ? Colors.white : Colors.white70,
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
                  color: isSelected ? const Color(0xFF6366F1) : Colors.white24,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us personalize your experience',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white38,
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
              // Simple converter for demonstration
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
          onUnitChange: (val) {
            setState(() {
              _weightUnit = val;
              if (val == 'lbs') {
                double kg = double.tryParse(_weightController.text) ?? 75;
                double lbs = kg * 2.20462;
                _weightController.text = lbs.toInt().toString();
              } else {
                double lbs = double.tryParse(_weightController.text) ?? 165;
                double kg = lbs / 2.20462;
                _weightController.text = kg.toInt().toString();
              }
            });
          },
        ),
        const SizedBox(height: 28),

        // Tip alert container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.05),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
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
                    color: const Color(0xFF93C5FD),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
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
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              // Segmented unit toggle selector
              Container(
                height: 32,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
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
                              color: isSelected ? Colors.white : Colors.white38,
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
              color: Colors.white,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'What would you like to achieve?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white38,
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
                    ? const Color(0xFF6366F1).withOpacity(0.15) 
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF6366F1) 
                      : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: isSelected 
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.25),
                          blurRadius: 16,
                        )
                      ]
                    : null,
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal['desc']!,
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Render flexing arm or other goal emojis when active
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
                        color: isSelected ? const Color(0xFF6366F1) : Colors.white24,
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us create safe meal plans',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 20),

        // Warning orange notification box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.05),
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
                    color: const Color(0xFFFDE047),
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
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),

        // Grid of common allergies (2 columns)
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
                      ? const Color(0xFF6366F1).withOpacity(0.15) 
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFF6366F1) 
                        : Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
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
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAllergies.map((allergy) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allergy,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF818CF8),
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
                          color: Color(0xFF818CF8),
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
            color: Colors.white70,
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
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _customAllergyController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g., Peanuts, Sesame',
                    hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
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
                      color: const Color(0xFF6366F1).withOpacity(0.3),
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
        // Pulsing Checkmark graphic as requested
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.12),
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
                      color: const Color(0xFF6366F1).withOpacity(0.4),
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
              // Little sparkles floating overlays
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.star_rounded, color: Colors.cyanAccent, size: 16),
              ),
              const Positioned(
                bottom: 12,
                left: 6,
                child: Icon(Icons.star_border_purple500_rounded, color: Colors.pinkAccent, size: 14),
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
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your personalized fitness profile is ready. Let\'s start your journey!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Progress List Cards matching PDF
        _buildAllSetCard(
          title: 'Profile Complete',
          desc: 'All information saved locally and prepared',
          icon: Icons.check_circle_rounded,
          iconColor: Colors.greenAccent,
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
          iconColor: Colors.amberAccent,
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
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
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
          // Step progress action
          Row(
            children: [
              // Show Back or Log-in
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (_currentStep == 0) {
                      // Navigate to Log-In screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    } else {
                      _prevStep();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  child: Text(
                    _currentStep == 0 ? 'Log in' : 'Back',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Continue button
              Expanded(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
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
                        } else if (_currentStep == 1) {
                          if (_heightController.text.trim().isEmpty || _weightController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter height and weight details.')),
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
                        }
                        
                        _nextStep();
                      },
                      child: Center(
                        child: Text(
                          _currentStep == 4 ? 'Start My Fitness Journey 🚀' : 'Continue',
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
          
          if (_currentStep == 4) ...[
            const SizedBox(height: 12),
            Text(
              'You can always update your preferences in Settings',
              style: GoogleFonts.inter(
                color: Colors.white30,
                fontSize: 10,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
