import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import '../services/api_service.dart';
import 'personal_details_screen.dart';
import 'preferences_screen.dart';
import 'language_screen.dart';
import 'nutrition_goals_screen.dart';
import 'fasting_screen.dart';
import 'weight_logs_screen.dart';
import 'help_support_screen.dart';
import 'terms_privacy_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _name = 'Darshan Urs';
  int _age = 25;
  String? _profilePictureUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    String nameTemp = prefs.getString('profile_name') ?? 'Darshan Urs';
    int ageTemp = int.tryParse(prefs.getString('profile_age') ?? '25') ?? 25;
    String? picTemp = prefs.getString('profile_pic_url');

    if (ApiService.isAuthenticated) {
      final res = await ApiService.getProfile();
      if (res['success']) {
        final data = res['data'];
        nameTemp = data['name'] ?? nameTemp;
        ageTemp = data['age'] ?? ageTemp;
        picTemp = data['profile_picture_url'] ?? picTemp;

        await prefs.setString('profile_name', nameTemp);
        await prefs.setString('profile_age', ageTemp.toString());
        if (picTemp != null) {
          await prefs.setString('profile_pic_url', picTemp);
        }
      }
    }

    if (mounted) {
      setState(() {
        _name = nameTemp;
        _age = ageTemp;
        _profilePictureUrl = picTemp;
        _isLoading = false;
      });
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

      setState(() => _isLoading = true);

      if (ApiService.isAuthenticated) {
        final res = await ApiService.updateProfilePicture(image.path);
        if (res['success']) {
          setState(() {
            _profilePictureUrl = res['url'];
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_pic_url', res['url']);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile picture updated successfully!'),
              backgroundColor: AppTheme.neonEmerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        } else {
          throw Exception(res['error'] ?? 'Upload failed');
        }
      } else {
        setState(() {
          _profilePictureUrl = image.path;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_pic_url', image.path);
      }
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                Navigator.of(context).pop();
                // Clear active token
                ApiService.setToken('');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Text(
            'Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          
          // User Card
          _buildCard(
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
                            gradient: _profilePictureUrl == null ? AppTheme.primaryGradient : null,
                            shape: BoxShape.circle,
                            image: _profilePictureUrl != null
                                ? DecorationImage(
                                    image: _profilePictureUrl!.startsWith('http')
                                        ? NetworkImage(_profilePictureUrl!)
                                        : FileImage(File(_profilePictureUrl!)) as ImageProvider,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profilePictureUrl == null
                              ? Center(
                                  child: Text(
                                    _name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
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
                        if (_isLoading)
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
                              _name,
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
                        const SizedBox(height: 4),
                        Text(
                          'Premium Member • $_age years old',
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
          const SizedBox(height: 20),

          // Stats Grid Widget
          Row(
            children: [
              Expanded(child: _buildStatWidget('Active Days', '45', Icons.calendar_today_rounded, AppTheme.accent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatWidget('Meals Scanned', '112', Icons.center_focus_strong_rounded, AppTheme.neonPink)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatWidget('Avg. Target', '94%', Icons.check_circle_outline_rounded, AppTheme.neonEmerald)),
            ],
          ),
          const SizedBox(height: 28),

          // Invite Friends Banner (marketing style)
          Container(
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
          const SizedBox(height: 28),

          // Account Settings Section
          _buildSectionHeader('Account Settings'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                _buildListTile(
                  Icons.person_outline_rounded,
                  'Personal details',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
                  ).then((_) => _loadProfile()),
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
                _buildListTile(
                  Icons.language_rounded,
                  'Language',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Goals & Tracking Section
          _buildSectionHeader('Goals & Tracking'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
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
                  'Weight & Goal logs',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WeightLogsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Support & Legal Section
          _buildSectionHeader('Support & Legal'),
          const SizedBox(height: 8),
          _buildCard(
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
          const SizedBox(height: 24),

          // Log Out Section
          _buildCard(
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}
