import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dm_screen.dart';

class FriendProfileScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendUsername;
  final String friendEmail;
  final String? friendPicUrl;
  final String avatarInitials;
  final Color avatarColor;

  const FriendProfileScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendUsername = '',
    this.friendEmail = '',
    this.friendPicUrl,
    this.avatarInitials = 'FR',
    this.avatarColor = AppTheme.accent,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final DateTime _selectedDate = DateTime.now();

  // Metrics
  int _calorieIntake = 0;
  double _proteinIntake = 0.0;
  double _carbsIntake = 0.0;
  double _fatsIntake = 0.0;
  int _calorieBurned = 0;
  int _stepsCalorieBurn = 0;
  int _workoutsCalorieBurn = 0;
  int _steps = 0;
  int _waterMl = 0;
  List<dynamic> _meals = [];
  List<dynamic> _workouts = [];

  // Default targets for display
  final double _calorieGoal = 2000.0;
  final double _proteinGoal = 130.0;
  final double _carbsGoal = 220.0;
  final double _fatsGoal = 65.0;
  final int _stepGoal = 10000;
  final int _waterGoal = 2500;

  @override
  void initState() {
    super.initState();
    _loadFriendActivity();
  }

  Future<void> _loadFriendActivity() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final res = await ApiService.getFriendActivity(widget.friendId, dateStr);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _calorieIntake = (data['calorieIntake'] ?? 0).toInt();
          _proteinIntake = (data['proteinIntake'] ?? 0.0).toDouble();
          _carbsIntake = (data['carbsIntake'] ?? 0.0).toDouble();
          _fatsIntake = (data['fatsIntake'] ?? 0.0).toDouble();
          _calorieBurned = (data['calorieBurned'] ?? 0).toInt();
          _stepsCalorieBurn = (data['stepsCalorieBurn'] ?? 0).toInt();
          _workoutsCalorieBurn = (data['workoutsCalorieBurn'] ?? 0).toInt();
          _steps = (data['steps'] ?? 0).toInt();
          _waterMl = (data['waterMl'] ?? 0).toInt();
          _meals = data['meals'] ?? [];
          _workouts = data['workouts'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Could not load friend activity.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load activity: $e';
        _isLoading = false;
      });
    }
  }

  String _getFormattedDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _getFormattedDate(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFriendActivity,
          color: AppTheme.accent,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. App Bar Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shadowColor: Colors.black.withOpacity(0.04),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Friend Activity',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 13,
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

              // 2. Profile Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildProfileHeaderCard(),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadFriendActivity,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 3. Calorie Summary Card
                      _buildCalorieSummaryCard(),
                      const SizedBox(height: 16),

                      // 4. Macronutrients Card
                      _buildMacrosCard(),
                      const SizedBox(height: 16),

                      // 5. Steps & Hydration Row
                      _buildStepsAndWaterRow(),
                      const SizedBox(height: 20),

                      // 6. Logged Meals
                      _buildMealsSection(),
                      const SizedBox(height: 20),

                      // 7. Workouts
                      _buildWorkoutsSection(),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final picUrl = widget.friendPicUrl;
    final displayName = widget.friendName;
    final username = widget.friendUsername;
    final email = widget.friendEmail;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.avatarColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.avatarColor.withOpacity(0.3), width: 2),
                  image: picUrl != null && picUrl.isNotEmpty
                      ? DecorationImage(
                          image: picUrl.startsWith('http')
                              ? CachedNetworkImageProvider(picUrl)
                              : FileImage(File(picUrl)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: picUrl == null || picUrl.isEmpty
                    ? Center(
                        child: Text(
                          widget.avatarInitials,
                          style: GoogleFonts.inter(
                            color: widget.avatarColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      )
                    else if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Action Buttons: Chat & Challenge
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DmScreen(
                          friendId: widget.friendId,
                          friendName: widget.friendName,
                          friendAvatar: widget.avatarInitials,
                          friendPicUrl: widget.friendPicUrl,
                          avatarColor: widget.avatarColor,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Send Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await ApiService.inviteFriendToChallenge(widget.friendId);
                    if (mounted) {
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fitness challenge sent to ${widget.friendName}! 👟'),
                            backgroundColor: AppTheme.accent,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['error'] ?? 'Failed to send challenge invite'),
                            backgroundColor: Colors.red.shade600,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Challenge'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                width: 105,
                height: 105,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: calorieRatio,
                      strokeWidth: 9,
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
                            'kcal logged',
                            style: GoogleFonts.inter(
                              fontSize: 10,
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
              const SizedBox(width: 20),
              // Details
              Expanded(
                child: Column(
                  children: [
                    _buildDetailRow('Consumed', '$_calorieIntake kcal', AppTheme.neonIndigo, Icons.restaurant_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Steps Burn', '$_stepsCalorieBurn kcal', AppTheme.neonEmerald, Icons.directions_walk_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Workout Burn', '$_workoutsCalorieBurn kcal', AppTheme.neonPink, Icons.fitness_center_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildDetailRow(
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

  Widget _buildDetailRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
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
            'Macronutrients',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          _buildMacroBar('Protein', _proteinIntake, _proteinGoal, 'g', AppTheme.proteinColor),
          const SizedBox(height: 14),
          _buildMacroBar('Carbs', _carbsIntake, _carbsGoal, 'g', AppTheme.carbsColor),
          const SizedBox(height: 14),
          _buildMacroBar('Fats', _fatsIntake, _fatsGoal, 'g', AppTheme.fatsColor),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, double current, double goal, String unit, Color barColor) {
    final ratio = (current / goal).clamp(0.0, 1.0);
    final percent = (ratio * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            Text(
              '${current.toStringAsFixed(1)} / ${goal.toInt()} $unit ($percent%)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
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
        Expanded(
          child: Container(
            height: 130,
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
                    const Icon(Icons.directions_walk_rounded, color: AppTheme.accent, size: 22),
                    Text('Steps', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  ],
                ),
                const Spacer(),
                Text('$_steps', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                Text('Goal: $_stepGoal', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
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
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 130,
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
                    const Icon(Icons.water_drop_rounded, color: Colors.blueAccent, size: 22),
                    Text('Hydration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  ],
                ),
                const Spacer(),
                Text('$_waterMl ml', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                Text('Goal: $_waterGoal ml', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
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

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Logged Meals (${_meals.length})',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_meals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Center(
              child: Text(
                'No meals logged yet today.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          ..._meals.map((meal) {
            final mealName = meal['name'] ?? meal['meal_type'] ?? 'Logged Meal';
            final cal = meal['total_calories'] ?? meal['calories'] ?? 0;
            final prot = (meal['protein'] ?? 0.0).toString();
            final carbs = (meal['carbs'] ?? 0.0).toString();
            final fat = (meal['fat'] ?? meal['fats'] ?? 0.0).toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealName,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P: ${prot}g  •  C: ${carbs}g  •  F: ${fat}g',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$cal kcal',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workouts Completed (${_workouts.length})',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
        ),
        const SizedBox(height: 12),
        if (_workouts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: Center(
              child: Text(
                'No workouts logged today.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          ..._workouts.map((w) {
            final wName = w['name'] ?? w['workout_type'] ?? 'Workout';
            final calBurn = w['calories'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.neonPink.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fitness_center_rounded, color: AppTheme.neonPink, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      wName,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                  Text(
                    '$calBurn kcal',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.neonPink),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
