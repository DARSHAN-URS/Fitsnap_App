import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MacroTargetsScreen extends StatefulWidget {
  const MacroTargetsScreen({super.key});

  @override
  State<MacroTargetsScreen> createState() => _MacroTargetsScreenState();
}

class _MacroTargetsScreenState extends State<MacroTargetsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Calorie & Macro Targets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3ABEF9).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/2649/2649223.png', // Calculator/Report icon
                    height: 100,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Set Your Targets',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose how you\'d like to set your daily calorie and macro targets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey[400], fontSize: 16),
            ),
            const SizedBox(height: 48),
            _buildSectionTitle('RECOMMENDED'),
            const SizedBox(height: 12),
            _buildActionCard(
              context,
              'Guided Survey',
              '~2 minutes',
              'Answer a few questions about your age, weight, activity level, and goals. We\'ll calculate personalized targets for you automatically.',
              Icons.assignment_outlined,
              const Color(0xFFFF5252),
              'Start Survey',
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TargetSurveyScreen())),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('ADVANCED'),
            const SizedBox(height: 12),
            _buildActionCard(
              context,
              'Enter Manually',
              'For professionals & external tools',
              'Already have your targets from a dietitian or an external calculator? Enter them directly into your profile.',
              Icons.settings_input_component_outlined,
              const Color(0xFFFFAB40),
              'Set Values',
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualTargetsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, String description, IconData icon, Color iconColor, String buttonText, VoidCallback onTap) {
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
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(color: Colors.blueGrey[300], fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3ABEF9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class TargetSurveyScreen extends StatefulWidget {
  const TargetSurveyScreen({super.key});

  @override
  State<TargetSurveyScreen> createState() => _TargetSurveyScreenState();
}

class _TargetSurveyScreenState extends State<TargetSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Survey Data
  String? _sex;
  DateTime? _dob;
  double? _height;
  double? _weight;
  double? _targetWeight;
  String? _activityLevel;
  String? _pace;

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _showResult();
    }
  }

  void _showResult() {
    // Calculation Logic
    if (_dob == null || _weight == null || _height == null || _sex == null || _activityLevel == null) return;
    
    final age = DateTime.now().year - _dob!.year;
    double bmr;
    if (_sex == 'Male') {
      bmr = 10 * _weight! + 6.25 * _height! - 5 * age + 5;
    } else {
      bmr = 10 * _weight! + 6.25 * _height! - 5 * age - 161;
    }

    double multiplier = 1.2;
    switch (_activityLevel) {
      case 'Lightly Active': multiplier = 1.375; break;
      case 'Moderately Active': multiplier = 1.55; break;
      case 'Highly Active': multiplier = 1.725; break;
    }

    final amr = bmr * multiplier;
    
    double goalAdjustment = 0;
    bool isGaining = (_targetWeight ?? _weight!) > _weight!;
    
    if (_pace == 'Slowly') goalAdjustment = isGaining ? 250 : -250;
    else if (_pace == 'Steadily') goalAdjustment = isGaining ? 500 : -500;
    else if (_pace == 'Quickly') goalAdjustment = isGaining ? 750 : -750;

    final targetCalories = amr + goalAdjustment;

    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => NutritionPlanScreen(
          age: age,
          height: _height!,
          weight: _weight!,
          targetWeight: _targetWeight ?? _weight!,
          activityLevel: _activityLevel!,
          bmr: bmr.toInt(),
          amr: amr.toInt(),
          targetCalories: targetCalories.toInt(),
          pace: _pace!,
          isGaining: isGaining,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('${_currentPage + 1} of 7', style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildSexPage(),
          _buildDOBPage(),
          _buildHeightPage(),
          _buildWeightPage(),
          _buildTargetWeightPage(),
          _buildActivityPage(),
          _buildPacePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isCurrentPageValid() ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ABEF9),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white10,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_currentPage == 6 ? 'Show Results' : 'Next', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  bool _isCurrentPageValid() {
    switch (_currentPage) {
      case 0: return _sex != null;
      case 1: return _dob != null;
      case 2: return _height != null;
      case 3: return _weight != null;
      case 4: return _targetWeight != null;
      case 5: return _activityLevel != null;
      case 6: return _pace != null;
      default: return false;
    }
  }

  Widget _buildSexPage() {
    return _buildSurveyLayout(
      'What is your biological sex?',
      'This helps us calculate your metabolism more accurately.',
      Column(
        children: [
          _buildSelectionTile('Male', Icons.male_rounded, _sex == 'Male', () => setState(() => _sex = 'Male')),
          const SizedBox(height: 16),
          _buildSelectionTile('Female', Icons.female_rounded, _sex == 'Female', () => setState(() => _sex = 'Female')),
        ],
      ),
    );
  }

  Widget _buildDOBPage() {
    return _buildSurveyLayout(
      'When were you born?',
      'Age is a key factor in calorie burn.',
      Center(
        child: GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context, 
              initialDate: DateTime(2000), 
              firstDate: DateTime(1940), 
              lastDate: DateTime.now(),
            );
            if (date != null) setState(() => _dob = date);
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _dob != null ? const Color(0xFF3ABEF9) : Colors.white10),
            ),
            child: Text(
              _dob == null ? 'Select Date' : DateFormat('MMMM dd, yyyy').format(_dob!),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeightPage() {
    return _buildSurveyLayout(
      'How tall are you?',
      'Enter your height in cm.',
      _buildNumberInput('cm', (v) => _height = double.tryParse(v)),
    );
  }

  Widget _buildWeightPage() {
    return _buildSurveyLayout(
      'What is your current weight?',
      'Enter your current weight in kg.',
      _buildNumberInput('kg', (v) => _weight = double.tryParse(v)),
    );
  }

  Widget _buildTargetWeightPage() {
    return _buildSurveyLayout(
      'What is your target weight?',
      'Enter your desired weight in kg.',
      _buildNumberInput('kg', (v) => _targetWeight = double.tryParse(v)),
    );
  }

  Widget _buildActivityPage() {
    return _buildSurveyLayout(
      'Lifestyle Activity',
      'This step will adjust targets based on your daily caloric burn.',
      Column(
        children: [
          _buildActivityTile('Sedentary', 'Little or no exercise, desk job', Icons.chair_rounded),
          const SizedBox(height: 12),
          _buildActivityTile('Lightly Active', 'Light exercise 1-3 days/week', Icons.directions_run_rounded),
          const SizedBox(height: 12),
          _buildActivityTile('Moderately Active', 'Moderate exercise 3-5 days/week', Icons.fitness_center_rounded),
          const SizedBox(height: 12),
          _buildActivityTile('Highly Active', 'Hard exercise 6-7 days/week', Icons.bolt_rounded),
        ],
      ),
    );
  }

  Widget _buildPacePage() {
    return _buildSurveyLayout(
      'How quickly do you want to reach your goal?',
      'I\'ll adjust your daily calorie target based on your preferred pace.',
      Column(
        children: [
          _buildPaceTile('Slowly', 'Gradual progress (±0.5 lbs per week)', Icons.eco_rounded),
          const SizedBox(height: 12),
          _buildPaceTile('Steadily', 'Balanced approach (±1 lb per week)', Icons.directions_walk_rounded),
          const SizedBox(height: 12),
          _buildPaceTile('Quickly', 'Faster results (±1.5 lbs per week)', Icons.speed_rounded),
        ],
      ),
    );
  }

  Widget _buildSurveyLayout(String title, String subtitle, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
          const SizedBox(height: 48),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      ),
    );
  }

  Widget _buildSelectionTile(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3ABEF9).withOpacity(0.1) : const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF3ABEF9) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF3ABEF9) : Colors.blueGrey, size: 28),
            const SizedBox(width: 20),
            Text(label, style: TextStyle(fontSize: 18, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFF3ABEF9)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(String title, String subtitle, IconData icon) {
    final selected = _activityLevel == title;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = title),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3ABEF9).withOpacity(0.1) : const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF3ABEF9) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF3ABEF9) : Colors.blueGrey, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaceTile(String title, String subtitle, IconData icon) {
    final selected = _pace == title;
    return GestureDetector(
      onTap: () => setState(() => _pace = title),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3ABEF9).withOpacity(0.1) : const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF3ABEF9) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF3ABEF9) : Colors.blueGrey, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(String unit, Function(String) onChanged) {
    return Center(
      child: Container(
        width: 200,
        child: TextField(
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: const TextStyle(fontSize: 20, color: Colors.blueGrey),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3ABEF9))),
          ),
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      ),
    );
  }
}

class NutritionPlanScreen extends StatelessWidget {
  final int age;
  final double height;
  final double weight;
  final double targetWeight;
  final String activityLevel;
  final int bmr;
  final int amr;
  final int targetCalories;
  final String pace;
  final bool isGaining;

  const NutritionPlanScreen({
    super.key,
    required this.age,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.activityLevel,
    required this.bmr,
    required this.amr,
    required this.targetCalories,
    required this.pace,
    required this.isGaining,
  });

  int get _weeksToGoal {
    final diff = (targetWeight - weight).abs();
    double weeklyPace = 0.5;
    if (pace == 'Slowly') weeklyPace = 0.25;
    else if (pace == 'Quickly') weeklyPace = 0.75;
    return (diff / weeklyPace).ceil();
  }

  Map<String, int> get _macros {
    // 35% Protein, 25% Fat, 40% Carbs
    final pCals = targetCalories * 0.35;
    final fCals = targetCalories * 0.25;
    final cCals = targetCalories * 0.40;

    return {
      'protein': (pCals / 4).round(),
      'fat': (fCals / 9).round(),
      'carbs': (cCals / 4).round(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final macros = _macros;
    String goalTitle = isGaining ? 'Muscle Gain' : 'Weight Loss';
    String goalDesc = isGaining 
        ? 'Reach your target weight efficiently with an accelerated approach'
        : 'Shed body fat while maintaining lean muscle mass';

    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Your Nutrition Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF3ABEF9))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goalTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('$_weeksToGoal weeks to reach your goal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Progress speed: ${pace.toLowerCase()}', style: TextStyle(color: Colors.blueGrey[400], fontSize: 14)),
                  const SizedBox(height: 16),
                  Text(goalDesc, style: TextStyle(color: Colors.blueGrey[300], fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Daily Targets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your personalized nutrition plan. You can adjust these targets later.', style: TextStyle(color: Colors.blueGrey[400], fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$targetCalories', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Text('calories', style: TextStyle(fontSize: 18, color: Colors.blueGrey)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroStat('protein', '${macros['protein']}g', const Color(0xFFFF5252)),
                      _macroStat('fat', '${macros['fat']}g', const Color(0xFFFFD740)),
                      _macroStat('carbs', '${macros['carbs']}g', const Color(0xFF40C4FF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailsCard(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.blueGrey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dietary guidance is for informational purposes only. Consult your healthcare provider before making changes.',
                    style: TextStyle(color: Colors.blueGrey[400], fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ABEF9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Let\'s Get Started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _macroStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _row('Age', '$age years'),
          _row('Height', '${height.toInt()} cm'),
          _row('Weight', '${weight.toStringAsFixed(1)} kg'),
          _row('Target Weight', '${targetWeight.toStringAsFixed(1)} kg'),
          _row('Activity Level', activityLevel),
          const Divider(height: 32, color: Colors.white10),
          _row('BMR (Base Rate)', '$bmr cal'),
          _row('AMR (Active Rate)', '$amr cal'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ManualTargetsScreen extends StatefulWidget {
  const ManualTargetsScreen({super.key});

  @override
  State<ManualTargetsScreen> createState() => _ManualTargetsScreenState();
}

class _ManualTargetsScreenState extends State<ManualTargetsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _generateReport() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NutritionPlanScreen(
            age: int.parse(_ageController.text),
            height: double.parse(_heightController.text),
            weight: double.parse(_weightController.text),
            targetWeight: double.parse(_weightController.text), // Assume maintenance if manual
            activityLevel: 'Manual Entry',
            bmr: 0, // Not applicable for manual
            amr: 0, // Not applicable for manual
            targetCalories: int.parse(_calorieController.text),
            pace: 'Steadily',
            isGaining: false, // Default
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Manual Targets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('CALORIE TARGET'),
              _buildInputField(_calorieController, 'Calories', 'kcal', Icons.local_fire_department_rounded),
              const SizedBox(height: 32),
              _buildSectionHeader('MACRO TARGETS (GRAMS)'),
              Row(
                children: [
                  Expanded(child: _buildInputField(_proteinController, 'Protein', 'g', Icons.circle, iconColor: Colors.redAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInputField(_fatController, 'Fat', 'g', Icons.circle, iconColor: Colors.amber)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInputField(_carbController, 'Carbs', 'g', Icons.circle, iconColor: Colors.cyan)),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('BIOMETRICS (FOR REPORT)'),
              _buildInputField(_ageController, 'Age', 'years', Icons.cake_rounded),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInputField(_heightController, 'Height', 'cm', Icons.height_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInputField(_weightController, 'Weight', 'kg', Icons.monitor_weight_rounded)),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _generateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ABEF9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Generate Manual Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, String suffix, IconData icon, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          icon: Icon(icon, color: iconColor ?? Colors.blueGrey, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          border: InputBorder.none,
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }
}
