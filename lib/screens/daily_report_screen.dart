import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/staggered_animation.dart';
import '../widgets/transparent_report_widget.dart';
import '../utils/share_helper.dart';
import 'export_studio_screen.dart';


class DailyReportScreen extends StatefulWidget {
  final DateTime date;

  const DailyReportScreen({super.key, required this.date});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isLoading = true;
  String? _errorMessage;

  // Export state
  bool _transparentOverlay = false;
  final GlobalKey _repaintKey = GlobalKey();

  // Goals
  double _calorieGoal = 2000.0;
  double _proteinGoal = 130.0;
  double _carbsGoal = 220.0;
  double _fatsGoal = 65.0;
  final int _stepGoal = 10000;
  final int _waterGoal = 2500;

  // API Data
  int _calorieIntake = 0;
  int _proteinIntake = 0;
  int _carbsIntake = 0;
  int _fatsIntake = 0;
  int _calorieBurned = 0;
  int _stepsCalorieBurn = 0;
  int _workoutsCalorieBurn = 0;
  int _steps = 0;
  int _waterMl = 0;
  List<dynamic> _meals = [];
  List<dynamic> _workouts = [];

  // AI Insights
  String _aiSummary = "";
  List<String> _aiDidBetter = [];
  List<String> _aiToImprove = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadGoalsAndReport();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadGoalsAndReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load user custom goals
      final prefs = await SharedPreferences.getInstance();
      final double? customCal = prefs.getDouble('profile_calorie_goal');
      final double? customProt = prefs.getDouble('profile_protein_goal');
      final double? customCarb = prefs.getDouble('profile_carbs_goal');
      final double? customFat = prefs.getDouble('profile_fats_goal');

      if (customCal != null) _calorieGoal = customCal;
      if (customProt != null) _proteinGoal = customProt;
      if (customCarb != null) _carbsGoal = customCarb;
      if (customFat != null) _fatsGoal = customFat;

      // 2. Fetch daily report from backend
      final dateStr = widget.date.toIso8601String().split('T')[0];
      final res = await ApiService.getDailyReport(dateStr);

      if (res['success'] && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _calorieIntake = data['calorieIntake'] ?? 0;
          _proteinIntake = data['proteinIntake'] ?? 0;
          _carbsIntake = data['carbsIntake'] ?? 0;
          _fatsIntake = data['fatsIntake'] ?? 0;
          _calorieBurned = data['calorieBurned'] ?? 0;
          _stepsCalorieBurn = data['stepsCalorieBurn'] ?? 0;
          _workoutsCalorieBurn = data['workoutsCalorieBurn'] ?? 0;
          _steps = data['steps'] ?? 0;
          _waterMl = data['waterMl'] ?? 0;
          _meals = data['meals'] ?? [];
          _workouts = data['workouts'] ?? [];

          // AI insights parsing
          final aiReport = data['aiReport'];
          if (aiReport != null) {
            _aiSummary = aiReport['summary'] ?? "No summary analysis available.";
            _aiDidBetter = _parseBulletPoints(aiReport['didBetter']);
            _aiToImprove = _parseBulletPoints(aiReport['toImprove']);
          } else {
            _aiSummary = "No AI insights generated for this day yet.";
            _aiDidBetter = [];
            _aiToImprove = [];
          }
          _isLoading = false;
        });
        _animController.forward(from: 0.0);
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Could not retrieve daily report logs.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  List<String> _parseBulletPoints(dynamic content) {
    if (content == null) return [];
    if (content is List) {
      return content.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (content is String) {
      return content
          .split(RegExp(r'(?:\n|\. |; )'))
          .map((s) => s.trim().replaceAll(RegExp(r'^[-*•\d\.\s]+'), ''))
          .where((s) => s.isNotEmpty && s != '.')
          .toList();
    }
    return [];
  }

  String _getFormattedDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateStr = _getFormattedDate(widget.date);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.save),
        label: const Text('Export'),
        backgroundColor: AppTheme.accent,
        onPressed: _showExportDialog,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGoalsAndReport,
          color: AppTheme.accent,
          backgroundColor: Colors.white,
          child: RepaintBoundary(
            key: _repaintKey,
            child: _transparentOverlay
                ? TransparentReportWidget(child: _buildReportContent())
                : _buildReportContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final formattedDateStr = _getFormattedDate(widget.date);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
              // Custom Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shadowColor: Colors.black.withOpacity(0.04),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Report',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              formattedDateStr,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Oops, something went wrong',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadGoalsAndReport,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Calorie Summary Widget
                      StaggeredListItem(
                        index: 0,
                        animationController: _animController,
                        child: _buildCalorieSummaryCard(),
                      ),
                      const SizedBox(height: 16),

                      // 2. Macronutrient Cards
                      StaggeredListItem(
                        index: 1,
                        animationController: _animController,
                        child: _buildMacrosCard(),
                      ),
                      const SizedBox(height: 16),

                      // 3. Hydration and Steps
                      StaggeredListItem(
                        index: 2,
                        animationController: _animController,
                        child: _buildStepsAndWaterRow(),
                      ),
                      const SizedBox(height: 16),

                      // 4. AI Coach insights
                      StaggeredListItem(
                        index: 3,
                        animationController: _animController,
                        child: _buildAICoachInsightsCard(),
                      ),
                      const SizedBox(height: 24),

                      // 5. Meals Logged
                      StaggeredListItem(
                        index: 4,
                        animationController: _animController,
                        child: _buildLoggedMealsSection(),
                      ),
                      const SizedBox(height: 24),

                      // 6. Workouts Completed
                      StaggeredListItem(
                        index: 5,
                        animationController: _animController,
                        child: _buildLoggedWorkoutsSection(),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                )
            ],
          );
  }

  // Show export options dialog
  void _showExportDialog() {
    final dataMap = {
      'date': _getFormattedDate(widget.date),
      'steps': _steps,
      'calorieBurned': _calorieBurned,
      'waterMl': _waterMl,
      'calorieIntake': _calorieIntake,
      'recoveryScore': 84, // optimal defaults
      'strainScore': 14.2,
      'aiSummary': _aiSummary.isNotEmpty ? _aiSummary : "Great workout volume! Steps and nutrition are on track.",
    };
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportStudioScreen(
          type: ExportType.daily,
          data: dataMap,
        ),
      ),
    );
  }

  // Export the report as PNG (or JPEG placeholder) and save to device storage
  Future<void> _exportReport(bool transparent) async {
    setState(() => _transparentOverlay = transparent);
    // Give the UI a moment to rebuild with the selected overlay
    await Future.delayed(const Duration(milliseconds: 150));
    final fileName = 'DailyReport_${widget.date.toIso8601String().split('T')[0]}';
    final savedPath = await ShareHelper.saveWidgetCapture(
      _repaintKey,
      fileName: fileName,
      asJpeg: false,
    );
    setState(() => _transparentOverlay = false);
    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report saved to $savedPath')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save report')),
      );
    }
  }

  // --- UI Card Builders ---

  Widget _buildCalorieSummaryCard() {
    final calorieRatio = (_calorieIntake / _calorieGoal).clamp(0.0, 1.0);
    final netCalories = _calorieIntake - _calorieBurned;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorie Summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Radial Progress Circle
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: calorieRatio,
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: AppTheme.neonIndigo,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_calorieIntake',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            'of ${_calorieGoal.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'kcal',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.neonIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Calories details
              Expanded(
                child: Column(
                  children: [
                    _buildCalDetailRow('Calories Consumed', '$_calorieIntake kcal', AppTheme.neonIndigo, Icons.restaurant_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildCalDetailRow('Steps Calorie Burn', '$_stepsCalorieBurn kcal', AppTheme.neonEmerald, Icons.directions_walk_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildCalDetailRow('Workout Calorie Burn', '$_workoutsCalorieBurn kcal', AppTheme.neonPink, Icons.fitness_center_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildCalDetailRow(
                      'Net Balance',
                      '${netCalories > 0 ? '+' : ''}$netCalories kcal',
                      netCalories > 0 ? AppTheme.neonAmber : AppTheme.neonEmerald,
                      Icons.balance_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalDetailRow(String label, String value, Color markerColor, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: markerColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macronutrients Logged',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          _buildMacroProgressBar('Protein', _proteinIntake, _proteinGoal.toInt(), 'g', AppTheme.proteinColor),
          const SizedBox(height: 16),
          _buildMacroProgressBar('Carbs', _carbsIntake, _carbsGoal.toInt(), 'g', AppTheme.carbsColor),
          const SizedBox(height: 16),
          _buildMacroProgressBar('Fats', _fatsIntake, _fatsGoal.toInt(), 'g', AppTheme.fatsColor),
        ],
      ),
    );
  }

  Widget _buildMacroProgressBar(String label, int current, int goal, String unit, Color barColor) {
    final ratio = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            Text(
              '$current / $goal $unit ($percent%)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsAndWaterRow() {
    final stepsRatio = (_steps / _stepGoal).clamp(0.0, 1.0);
    final waterRatio = (_waterMl / _waterGoal).clamp(0.0, 1.0);

    return Row(
      children: [
        // Steps Card
        Expanded(
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: AppTheme.accent, size: 24),
                    Text(
                      'Steps',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '$_steps',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
                Text(
                  'Goal: $_stepGoal',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: stepsRatio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Hydration Card
        Expanded(
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.water_drop_rounded, color: Colors.blueAccent, size: 24),
                    Text(
                      'Hydration',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '$_waterMl ml',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
                Text(
                  'Goal: $_waterGoal ml',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: waterRatio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAICoachInsightsCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.neonIndigo.withOpacity(0.08),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.neonIndigo.withOpacity(0.2), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonIndigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, color: AppTheme.neonIndigo, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Coach Progress Insights',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AI summary paragraph
          Text(
            _aiSummary,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          // Did Better (Success points)
          if (_aiDidBetter.isNotEmpty) ...[
            Text(
              'WHAT WENT WELL',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.neonEmerald,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ..._aiDidBetter.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppTheme.neonEmerald, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // Areas of focus
          if (_aiToImprove.isNotEmpty) ...[
            Text(
              'RECOMMENDED IMPROVEMENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.neonAmber,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ..._aiToImprove.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.neonAmber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLoggedMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Logged Food Journal',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_meals.length} items',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_meals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No meals logged on this date.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              final meal = _meals[index];
              return _buildMealItemCard(meal);
            },
          ),
      ],
    );
  }

  Widget _buildMealItemCard(dynamic meal) {
    final calories = meal['calories'] ?? 0;
    final protein = meal['protein'] ?? 0;
    final carbs = meal['carbs'] ?? 0;
    final fats = meal['fats'] ?? 0;
    final name = meal['name'] ?? 'Logged Meal';
    final desc = meal['description'];
    final timeStr = meal['logged_at'] != null ? _formatIsoTime(meal['logged_at']) : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.neonIndigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.neonIndigo, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$calories kcal',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (desc != null && desc.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc.toString(),
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
            ),
          ],
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          // Macros breakdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMacro('Protein', '${protein}g', AppTheme.proteinColor),
              _buildMiniMacro('Carbs', '${carbs}g', AppTheme.carbsColor),
              _buildMiniMacro('Fats', '${fats}g', AppTheme.fatsColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildLoggedWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Completed Workouts',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_workouts.length} items',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_workouts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No workouts completed on this date.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _workouts.length,
            itemBuilder: (context, index) {
              final workout = _workouts[index];
              return _buildWorkoutItemCard(workout);
            },
          ),
      ],
    );
  }

  Widget _buildWorkoutItemCard(dynamic workout) {
    final calories = workout['calories'] ?? 0;
    final name = workout['workout_name'] ?? 'Workout Session';
    final type = workout['workout_type'] ?? 'cardio';
    final distance = workout['distance'] ?? 0.0;
    final durationSeconds = workout['duration_seconds'] ?? 0;
    final category = workout['category'];
    final timeStr = workout['completed_at'] != null ? _formatIsoTime(workout['completed_at']) : 'Completed';

    final durationMins = (durationSeconds / 60).round();
    final isStrength = type.toString().toLowerCase() == 'strength';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.neonPink.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isStrength ? Icons.fitness_center_rounded : Icons.directions_run_rounded,
                  color: AppTheme.neonPink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      '${category ?? (isStrength ? "Strength Training" : "Cardio Activity")} • $timeStr',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$calories',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'kcal burned',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWorkoutMetric(Icons.timer_outlined, '$durationMins mins'),
              if (!isStrength && distance > 0.0)
                _buildWorkoutMetric(Icons.map_outlined, '${distance.toStringAsFixed(1)} km'),
              _buildWorkoutMetric(
                Icons.emoji_events_outlined,
                isStrength ? 'Strength' : 'Cardio',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutMetric(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _formatIsoTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final minStr = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minStr $amPm';
    } catch (_) {
      return 'Logged';
    }
  }
}
