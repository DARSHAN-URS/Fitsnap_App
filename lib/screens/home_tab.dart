import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io';
import '../services/api_service.dart';
import 'activity_tracker_screen.dart';
import 'challenge_screen.dart';
import 'profile_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../widgets/staggered_animation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeTab extends ConsumerStatefulWidget {
  final int consumed;
  final int protein;
  final int carbs;
  final int fats;
  final List<Map<String, dynamic>> meals;
  final DateTime selectedDate;
  final int steps;
  final int water;
  final ValueChanged<int> onStepsChanged;
  final ValueChanged<int> onWaterChanged;
  final ValueChanged<DateTime> onDateChanged;
  final RefreshCallback onRefresh;

  const HomeTab({
    super.key,
    required this.consumed,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.meals,
    required this.selectedDate,
    required this.steps,
    required this.water,
    required this.onStepsChanged,
    required this.onWaterChanged,
    required this.onDateChanged,
    required this.onRefresh,
  });

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with TickerProviderStateMixin {
  final int _stepGoal = 10000;
  final int _waterGoal = 2500; // ml
  String? _aiInsight;
  double _height = 175.0;
  double _weight = 75.0;
  int _age = 25;
  String _gender = 'Male';
  String _goal = 'Build Muscle';
  double? _customCalorieGoal;
  double? _customProteinGoal;
  double? _customCarbsGoal;
  double? _customFatsGoal;

  // Carousel Controller
  late PageController _pageController;
  int _carouselIndex = 0;

  // Entry animation controller
  late AnimationController _entryAnimController;

  String _profileName = 'Guest User';
  String? _profilePicUrl;

  // Colors based on spec
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color cardColor = const Color(0xFFFFFFFF);
  final Color textPrimary = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color purpleAccent = const Color(0xFF8B5CF6);

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF00FFA3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  int get _burnedCalories => (widget.steps * 0.04).toInt();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimController.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String nameTemp = prefs.getString('profile_name') ?? 'Guest User';
    final String? picTemp = prefs.getString('profile_pic_url');
    final double heightTemp = prefs.getDouble('profile_height') ?? 175.0;
    final double weightTemp = prefs.getDouble('profile_weight') ?? 75.0;
    final String ageStr = prefs.getString('profile_age') ?? '25';
    final int ageTemp = int.tryParse(ageStr) ?? 25;
    final String genderTemp = prefs.getString('profile_gender') ?? 'Male';
    final String goalTemp = prefs.getString('profile_goal') ?? 'Build Muscle';
    final double? customCalTemp = prefs.getDouble('profile_calorie_goal');
    final double? customProtTemp = prefs.getDouble('profile_protein_goal');
    final double? customCarbTemp = prefs.getDouble('profile_carbs_goal');
    final double? customFatTemp = prefs.getDouble('profile_fats_goal');

    setState(() {
      _profileName = nameTemp;
      _profilePicUrl = picTemp;
      _height = heightTemp;
      _weight = weightTemp;
      _age = ageTemp;
      _gender = genderTemp;
      _goal = goalTemp;
      _customCalorieGoal = customCalTemp;
      _customProteinGoal = customProtTemp;
      _customCarbsGoal = customCarbTemp;
      _customFatsGoal = customFatTemp;
    });
    
    if (ApiService.isAuthenticated) {
      final res = await ApiService.getWorkoutInsight();
      if (res['success'] && res['data'] != null) {
        if (mounted) {
          setState(() {
            _aiInsight = res['data']['insight'];
          });
        }
      }
    }
  }

  Future<void> _saveStats(int steps, int water) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = widget.selectedDate.toIso8601String().split('T')[0];
    await prefs.setInt('home_steps_$dateStr', steps);
    await prefs.setInt('home_water_$dateStr', water);

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (dateStr == todayStr) {
      await prefs.setInt('home_steps', steps);
      await prefs.setInt('home_water', water);
    }

    if (ApiService.isAuthenticated) {
      final res = await ApiService.updateDailyStats(date: dateStr, steps: steps, waterMl: water);
      if (!res['success']) {
        debugPrint('Failed to sync daily stats: ${res['error']}');
      }
    }
  }

  void _addSteps() {
    final newSteps = widget.steps + 1000;
    widget.onStepsChanged(newSteps);
    _saveStats(newSteps, widget.water);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logged 1,000 steps!'),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: purpleAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _addWater() {
    final newWater = (widget.water + 250).clamp(0, 5000);
    widget.onWaterChanged(newWater);
    _saveStats(widget.steps, newWater);
  }

  void _removeWater() {
    final newWater = (widget.water - 250).clamp(0, 5000);
    widget.onWaterChanged(newWater);
    _saveStats(widget.steps, newWater);
  }

  String _getFormattedMonthYear(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getFormattedDayText(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _getFormattedFullDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildCalendarStrip() {
    final days = List.generate(7, (index) {
      return DateTime.now().subtract(Duration(days: 6 - index));
    });

    final DateFormat = (DateTime dt) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    };

    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == widget.selectedDate.year &&
              day.month == widget.selectedDate.month &&
              day.day == widget.selectedDate.day;

          return GestureDetector(
            onTap: () {
              widget.onDateChanged(day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : borderColor,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: purpleAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat(day),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white.withOpacity(0.8) : textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAllMealsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Logged Food Diary',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.meals.length} items',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: purpleAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: widget.meals.isEmpty
                        ? Center(
                            child: Text(
                              'No meals logged today yet.',
                              style: GoogleFonts.inter(color: textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: widget.meals.length,
                            itemBuilder: (context, index) {
                              final meal = widget.meals.reversed.toList()[index];
                              return _buildMealItem(
                                title: meal['name'] ?? 'Analyzed Food',
                                calories: '${meal['calories']}',
                                time: meal['time'] ?? 'Just now',
                                protein: meal['protein'] ?? 0,
                                carbs: meal['carbs'] ?? 0,
                                fats: meal['fats'] ?? 0,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddMealTextDialog() {
    final TextEditingController descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
         return AlertDialog(
           backgroundColor: Colors.white,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
           title: Text(
             'Describe Your Meal',
             style: GoogleFonts.inter(
               fontWeight: FontWeight.w800,
               color: textPrimary,
             ),
           ),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 'Enter whatever you ate, including portions, to calculate macros instantly.',
                 style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
               ),
               const SizedBox(height: 18),
               Container(
                 decoration: BoxDecoration(
                   color: const Color(0xFFF1F5F9),
                   borderRadius: BorderRadius.circular(16),
                 ),
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: TextField(
                   controller: descController,
                   maxLines: 3,
                   style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                   decoration: InputDecoration(
                     hintText: 'e.g., Two eggs, two slices of sourdough toast, and a small cup of black coffee',
                     hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                     border: InputBorder.none,
                     contentPadding: const EdgeInsets.symmetric(vertical: 12),
                   ),
                 ),
               ),
             ],
           ),
           actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: Text(
                 'Cancel',
                 style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w600),
               ),
             ),
             ElevatedButton(
               onPressed: () async {
                 final String text = descController.text.trim();
                 Navigator.pop(context);
                 if (text.isNotEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: const Text('Analyzing food details...'),
                       backgroundColor: purpleAccent,
                     ),
                   );
                   final result = await ApiService.analyzeNutritionText(text);
                   if (result['success']) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(
                         content: Text('Meal logged successfully!'),
                         backgroundColor: Colors.green,
                       ),
                     );
                     _loadStats();
                   }
                 }
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: textPrimary,
                 foregroundColor: Colors.white,
                 elevation: 0,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
               child: Text(
                 'Analyze',
                 style: GoogleFonts.inter(fontWeight: FontWeight.w700),
               ),
             ),
           ],
         );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    
    // Nutrition metrics calculations

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: purpleAccent,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          StaggeredListItem(
            index: 0,
            animationController: _entryAnimController,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome,',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profileState.name} 👋',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [

                  // Notification Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(Icons.notifications_none_rounded, color: textPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            backgroundColor: bgColor,
                            appBar: AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            body: const ProfileTab(),
                          ),
                        ),
                      ).then((_) => _loadStats());
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profileState.profilePictureUrl == null ? primaryGradient : null,
                        image: profileState.profilePictureUrl != null
                            ? DecorationImage(
                                 image: profileState.profilePictureUrl!.startsWith('http')
                                     ? CachedNetworkImageProvider(profileState.profilePictureUrl!)
                                     : FileImage(File(profileState.profilePictureUrl!)) as ImageProvider,
                                 fit: BoxFit.cover,
                              )
                            : null,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: profileState.profilePictureUrl == null
                          ? Center(
                              child: Text(
                                profileState.name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
          const SizedBox(height: 20),

          StaggeredListItem(
            index: 1,
            animationController: _entryAnimController,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getFormattedMonthYear(widget.selectedDate),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            _getFormattedDayText(widget.selectedDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: purpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCalendarStrip(),
                      const Divider(height: 12, thickness: 1, color: Color(0xFFE2E8F0)),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: purpleAccent, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _isToday(widget.selectedDate)
                                  ? 'Your health track overview for today'
                                  : 'Your health track overview for ${_getFormattedFullDate(widget.selectedDate)}',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Hero Carousel of Dashboard Cards (Calories, Steps, Water, Burned)
          StaggeredListItem(
            index: 2,
            animationController: _entryAnimController,
            child: _buildHeroCarousel(),
          ),
          const SizedBox(height: 24),

          // BMI Section
          StaggeredListItem(
            index: 3,
            animationController: _entryAnimController,
            child: _buildBmiSection(),
          ),
          const SizedBox(height: 24),

          // Quick Actions Title
          StaggeredListItem(
            index: 4,
            animationController: _entryAnimController,
            child: Text(
            'Quick Actions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          ),
          const SizedBox(height: 12),

          // Quick Actions horizontal list
          StaggeredListItem(
            index: 5,
            animationController: _entryAnimController,
            child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildActionButton(
                  label: 'Start Workout',
                  icon: Icons.play_arrow_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityTrackerScreen()),
                    ).then((_) => _loadStats());
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Scan Food',
                  icon: Icons.camera_alt_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening food camera scanner...')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Add Meal',
                  icon: Icons.add_rounded,
                  onTap: _showAddMealTextDialog,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Water Intake',
                  icon: Icons.local_drink_rounded,
                  onTap: () {
                    _addWater();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged 250ml of water!')),
                    );
                  },
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Challenge Section
          StaggeredListItem(
            index: 6,
            animationController: _entryAnimController,
            child: Text(
            'Challenges',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          ),
          const SizedBox(height: 12),
          StaggeredListItem(
            index: 7,
            animationController: _entryAnimController,
            child: _buildChallengeCard(),
          ),
          const SizedBox(height: 24),



          // Recently Uploaded Food Feed
          StaggeredListItem(
            index: 8,
            animationController: _entryAnimController,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently Uploaded',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _showAllMealsBottomSheet,
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: purpleAccent,
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 12),
          
          if (widget.meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No meals logged today yet.',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ...widget.meals.reversed.map((meal) {
              return _buildMealItem(
                title: meal['name'] ?? 'Analyzed Food',
                calories: '${meal['calories']}',
                time: meal['time'] ?? 'Just now',
                protein: meal['protein'] ?? 0,
                carbs: meal['carbs'] ?? 0,
                fats: meal['fats'] ?? 0,
              );
            }),
        ],
      ),
    ),
   );
  }

  int get _dailyCalorieGoal {
    if (_customCalorieGoal != null) {
      return _customCalorieGoal!.round();
    }
    
    // Mifflin-St Jeor recommendation
    double bmr = 0;
    if (_gender.toLowerCase() == 'male') {
      bmr = 10 * _weight + 6.25 * _height - 5 * _age + 5;
    } else {
      bmr = 10 * _weight + 6.25 * _height - 5 * _age - 161;
    }
    
    double tdee = bmr * 1.375;
    double target = tdee;
    if (_goal.toLowerCase().contains('lose')) {
      target = tdee - 500;
    } else if (_goal.toLowerCase().contains('build') || _goal.toLowerCase().contains('gain')) {
      target = tdee + 300;
    }
    
    return target.round().clamp(1200, 5000);
  }

  int get _dailyProteinGoal {
    if (_customProteinGoal != null) {
      return _customProteinGoal!.round();
    }
    return (_dailyCalorieGoal * 0.30 ~/ 4);
  }

  int get _dailyCarbsGoal {
    if (_customCarbsGoal != null) {
      return _customCarbsGoal!.round();
    }
    return (_dailyCalorieGoal * 0.45 ~/ 4);
  }

  int get _dailyFatsGoal {
    if (_customFatsGoal != null) {
      return _customFatsGoal!.round();
    }
    return (_dailyCalorieGoal * 0.25 ~/ 9);
  }

  Widget _buildHeroCarousel() {
    final int targetCal = _dailyCalorieGoal;
    final int leftCal = targetCal - widget.consumed + _burnedCalories;
    final double completionPercent = (widget.consumed - _burnedCalories) / targetCal;

    final int targetProtein = _dailyProteinGoal;
    final int targetCarbs = _dailyCarbsGoal;
    final int targetFats = _dailyFatsGoal;

    final int proteinLeft = (targetProtein - widget.protein).clamp(0, targetProtein);
    final int carbsLeft = (targetCarbs - widget.carbs).clamp(0, targetCarbs);
    final int fatsLeft = (targetFats - widget.fats).clamp(0, targetFats);

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _carouselIndex = index;
              });
            },
            children: [
              _buildCaloriesLeftCard(leftCal, completionPercent),
              _buildMacrosLeftCard(proteinLeft, carbsLeft, fatsLeft),
              _buildActivityAndWaterCard(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _carouselIndex == index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _carouselIndex == index ? purpleAccent : borderColor,
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildCaloriesLeftCard(int leftCal, double completionPercent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$leftCal',
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calories left',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _RadialPainter(percentage: completionPercent.clamp(0.0, 1.0)),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: purpleAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: purpleAccent,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacrosLeftCard(int proteinLeft, int carbsLeft, int fatsLeft) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _buildMacroSubColumn('${proteinLeft}g', 'Protein left', Icons.restaurant_rounded, Colors.red.shade700)),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroSubColumn('${carbsLeft}g', 'Carbs left', Icons.bakery_dining_rounded, Colors.orange.shade800)),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroSubColumn('${fatsLeft}g', 'Fats left', Icons.opacity_rounded, const Color(0xFF0284C7))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroSubColumn(String amount, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityAndWaterCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top row
              Expanded(
                child: Row(
                  children: [
                    // Steps card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${widget.steps}',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  '/$_stepGoal',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Steps Today',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            // Connect box
                            GestureDetector(
                              onTap: _addSteps,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite_rounded, color: Colors.red.shade700, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Connect Fit',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Burned card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: Colors.orange.shade800, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '$_burnedCalories',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Calories burned',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Steps indicator
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade800.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.directions_walk_rounded, color: Colors.orange.shade800, size: 12),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Steps',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '+${widget.steps}',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bottom water card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_drink_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Water',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                '${(widget.water * 0.033814).toStringAsFixed(1)} fl oz ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                '(${(widget.water / 250).toInt()} cups)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _removeWater,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Icon(Icons.remove_rounded, color: textPrimary, size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addWater,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: textPrimary,
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildBmiSection() {
    final double heightM = _height / 100.0;
    final double bmi = heightM > 0 ? _weight / (heightM * heightM) : 0.0;
    
    String status = 'Normal';
    Color statusColor = Colors.green.shade700;
    if (bmi < 18.5) {
      status = 'Underweight';
      statusColor = Colors.orange.shade800;
    } else if (bmi < 25) {
      status = 'Normal';
      statusColor = Colors.green.shade700;
    } else if (bmi < 30) {
      status = 'Overweight';
      statusColor = Colors.orange.shade800;
    } else {
      status = 'Obese';
      statusColor = Colors.red.shade700;
    }

    final double gaugeProgress = ((bmi - 15) / (35 - 15)).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Body Mass Index (BMI)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    bmi.toStringAsFixed(1),
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'kg/m²',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Weight: ${_weight.toStringAsFixed(1)} kg',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Height: ${_height.toStringAsFixed(0)} cm',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(2.0 * gaugeProgress - 1.0, 0.0),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: textPrimary, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '15.0',
                    style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '18.5',
                    style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '25.0',
                    style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '30.0',
                    style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '35.0',
                    style: GoogleFonts.inter(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '7-Day Core Crusher',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '2 out of 5 workouts completed',
                          style: GoogleFonts.inter(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 0.4,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: purpleAccent,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events_outlined, color: Colors.amber.shade700, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Golden Abs Badge',
                        style: GoogleFonts.inter(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChallengeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMealItem({
    required String title,
    required String calories,
    required String time,
    required int protein,
    required int carbs,
    required int fats,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.restaurant_rounded, color: textSecondary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'P: ${protein}g • C: ${carbs}g • F: ${fats}g',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories kcal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CalorieRadialGauge extends StatelessWidget {
  final int consumed;
  final int goal;
  final int burned;

  const CalorieRadialGauge({
    super.key,
    required this.consumed,
    required this.goal,
    required this.burned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(); // Built inside the main Hero Widget to avoid duplicates
  }
}

class _RadialPainter extends CustomPainter {
  final double percentage;

  _RadialPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    
    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Active arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF00D4FF), Color(0xFF00FFA3), Color(0xFF00D4FF)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Draw arc from top (-pi/2)
    canvas.drawArc(rect, -pi / 2, 2 * pi * percentage, false, activePaint);

    // Inner glow dot at current position
    final double angle = -pi / 2 + 2 * pi * percentage;
    final double dotX = center.dx + radius * cos(angle);
    final double dotY = center.dy + radius * sin(angle);
    
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final shadowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(Offset(dotX, dotY), 4, shadowPaint);
    canvas.drawCircle(Offset(dotX, dotY), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
