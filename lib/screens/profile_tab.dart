import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../auth_screen.dart';
import '../services/api_service.dart';
import '../services/health_sync_service.dart';
import '../services/step_tracking_service.dart';
import '../utils/preferences_helper.dart';
import '../widgets/staggered_animation.dart';
import 'personal_details_screen.dart';
import 'preferences_screen.dart';
import 'language_screen.dart';
import 'nutrition_goals_screen.dart';
import 'fasting_screen.dart';
import 'measurement_logs_screen.dart';
import 'help_support_screen.dart';
import 'terms_privacy_screen.dart';
import 'referral_screen.dart';
import 'workout_library_screen.dart';
import 'supplements_screen.dart';
import '../services/notification_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> with TickerProviderStateMixin {
  TimeOfDay? _reminderTime;
  String _language = 'English';
  
  late AnimationController _entryAnimController;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
    _loadReminderTime();
    _loadLanguage();
  }

  @override
  void dispose() {
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final langTemp = await PreferencesHelper.readString('selected_language_name') ?? 'English';
    setState(() {
      _language = langTemp;
    });
  }

  Future<void> _loadReminderTime() async {
    final timeStr = await PreferencesHelper.readString('reminder_time');
    if (timeStr != null && timeStr.contains(':')) {
      final parts = timeStr.split(':');
      setState(() {
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      });
    }
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
      await PreferencesHelper.saveString('reminder_time', '${picked.hour}:${picked.minute}');
      await NotificationService.scheduleDailyReminder(picked.hour, picked.minute);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily reminder set for ${picked.format(context)}'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      await ref.read(profileProvider.notifier).updateProfilePicture(image.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated successfully!'),
          backgroundColor: AppTheme.neonEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of SABTRACK AI?',
            style: GoogleFonts.inter(color: Colors.black54),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.black45, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Clear active token
                ApiService.setToken('');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.caloriesColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Logout',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          StaggeredListItem(
            index: 0,
            animationController: _entryAnimController,
            child: Text(
            'Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            ),
          ),
          ),
          const SizedBox(height: 24),
          
          // User Card
          StaggeredListItem(
            index: 1,
            animationController: _entryAnimController,
            child: _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: profileState.profilePictureUrl == null ? AppTheme.primaryGradient : null,
                            shape: BoxShape.circle,
                            image: profileState.profilePictureUrl != null
                                ? DecorationImage(
                                    image: profileState.profilePictureUrl!.startsWith('http')
                                        ? CachedNetworkImageProvider(profileState.profilePictureUrl!)
                                        : FileImage(File(profileState.profilePictureUrl!)) as ImageProvider,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: profileState.profilePictureUrl == null
                              ? Center(
                                  child: Text(
                                    profileState.name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (profileState.isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              profileState.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: AppTheme.accent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profileState.username}',
                          style: GoogleFonts.inter(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Premium Member • ${profileState.age} years old',
                          style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 20),

          // Stats Grid Widget
          StaggeredListItem(
            index: 2,
            animationController: _entryAnimController,
            child: Row(
            children: [
              Expanded(child: _buildStatWidget('Active Days', '${profileState.activeDays}', Icons.calendar_today_rounded, AppTheme.accent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatWidget('Meals Scanned', '${profileState.mealsScanned}', Icons.center_focus_strong_rounded, AppTheme.neonPink)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatWidget('Avg. Target', profileState.avgTarget, Icons.check_circle_outline_rounded, AppTheme.neonEmerald)),
            ],
          ),
          ),
          const SizedBox(height: 28),

          // Invite Friends Banner (marketing style)
          StaggeredListItem(
            index: 3,
            animationController: _entryAnimController,
            child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.08),
                    AppTheme.accent.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.accent.withOpacity(0.12), width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refer Friends, Earn \$10',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Get \$10 credit for every friend who signs up with your code.',
                          style: GoogleFonts.inter(
                            color: Colors.black54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 28),

          // Account Settings Section
          StaggeredListItem(
            index: 4,
            animationController: _entryAnimController,
            child: _buildSectionHeader('Account Settings'),
          ),
          const SizedBox(height: 8),
          StaggeredListItem(
            index: 5,
            animationController: _entryAnimController,
            child: _buildCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: const Icon(Icons.alarm_rounded, color: AppTheme.accent),
                  title: Text(
                    'Workout Reminder',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primary),
                  ),
                  subtitle: Text(
                    _reminderTime != null ? 'Daily at ${_reminderTime!.format(context)}' : 'Set daily reminder',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.black45),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  onTap: () => _selectReminderTime(context),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.person_outline_rounded,
                  'Personal details',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
                  ).then((_) => ref.read(profileProvider.notifier).loadProfile()),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.settings_outlined,
                  'Preferences',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PreferencesScreen()),
                  ),
                ),
                _buildDivider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: const Icon(Icons.language_rounded, color: AppTheme.accent),
                  title: Text(
                    'Language',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.primary),
                  ),
                  subtitle: Text(
                    _language,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.black45),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                  ).then((_) => ref.read(profileProvider.notifier).loadProfile()),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Goals & Tracking Section
          StaggeredListItem(
            index: 6,
            animationController: _entryAnimController,
            child: _buildSectionHeader('Goals & Tracking'),
          ),
          const SizedBox(height: 8),
          StaggeredListItem(
            index: 7,
            animationController: _entryAnimController,
            child: _buildCard(
            child: Column(
              children: [
                _buildListTile(
                  Icons.medication_rounded,
                  'Supplements Reminders',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupplementsScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.track_changes_rounded,
                  'Edit Nutrition Goals',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NutritionGoalsScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.play_circle_outline_rounded,
                  'Workout Library',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkoutLibraryScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.timer_outlined,
                  'Intermittent Fasting',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FastingScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.monitor_weight_outlined,
                  'Body & Weight Logs',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MeasurementLogsScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.health_and_safety_outlined,
                  'Sync Health Data',
                  () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing with Health/Google Fit...')),
                    );
                    
                    int steps = 0;
                    final stepSyncRes = await StepTrackingService.syncSteps();
                    if (stepSyncRes['success'] == true && stepSyncRes['data'] != null) {
                      steps = stepSyncRes['data']['final_steps'] ?? 0;
                    }

                    final result = await HealthSyncService.fetchTodayData();
                    if (!mounted) return;
                    
                    if (result['success'] == true) {
                      final healthData = result['data'] as Map<String, dynamic>;
                      final double water = healthData['water'] ?? 0.0;
                      
                      // Save to preferences so HomeTab can reload them
                      await PreferencesHelper.saveInt('home_steps', steps);
                      await PreferencesHelper.saveInt('home_water', water.toInt());
                      
                      // Sync to backend if authenticated
                      if (ApiService.isAuthenticated) {
                        await ApiService.updateDailyStats(steps: steps, waterMl: water.toInt());
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Synced: $steps steps and ${water.toInt()}ml water!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      ref.read(profileProvider.notifier).loadProfile();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync failed: ${result['error'] ?? 'Unknown error'}'),
                          backgroundColor: Colors.red.shade600,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Support & Legal Section
          StaggeredListItem(
            index: 8,
            animationController: _entryAnimController,
            child: _buildSectionHeader('Support & Legal'),
          ),
          const SizedBox(height: 8),
          StaggeredListItem(
            index: 9,
            animationController: _entryAnimController,
            child: _buildCard(
            child: Column(
              children: [
                _buildListTile(
                  Icons.help_outline_rounded,
                  'Help & Support',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  ),
                ),
                _buildDivider(),
                _buildListTile(
                  Icons.description_outlined,
                  'Terms & Privacy',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
                  ),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Log Out Section
          StaggeredListItem(
            index: 10,
            animationController: _entryAnimController,
            child: _buildCard(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.caloriesColor),
              title: Text(
                'Log Out',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.caloriesColor,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.caloriesColor),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              onTap: () => _showLogoutDialog(context),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.black38,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStatWidget(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: AppTheme.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: AppTheme.cardRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary.withOpacity(0.7)),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
          fontSize: 14.5,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38, size: 22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
      indent: 56,
      endIndent: 20,
    );
  }

  Widget _buildCard({required Widget child}) {
    return ClipRRect(
      borderRadius: AppTheme.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: AppTheme.cardRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
