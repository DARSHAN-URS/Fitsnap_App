import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';
import '../services/notification_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _useMetric = true;
  bool _mealReminders = true;
  bool _fastingAlerts = true;
  bool _weeklyDigest = false;
  bool _waterReminders = true;
  String _selectedThemeAccent = 'Indigo';

  final List<Map<String, dynamic>> _accents = [
    {'name': 'Indigo', 'color': AppTheme.accent},
    {'name': 'Emerald', 'color': AppTheme.neonEmerald},
    {'name': 'Pink', 'color': AppTheme.neonPink},
    {'name': 'Cyan', 'color': AppTheme.neonCyan},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final metric = await PreferencesHelper.readBool('use_metric') ?? true;
    final meals = await PreferencesHelper.readBool('meal_reminders') ?? true;
    final fasting = await PreferencesHelper.readBool('fasting_alerts') ?? true;
    final weekly = await PreferencesHelper.readBool('weekly_digest') ?? false;
    final water = await PreferencesHelper.readBool('water_reminders') ?? true;
    final accent = await PreferencesHelper.readString('theme_accent') ?? 'Indigo';
    setState(() {
      _useMetric = metric;
      _mealReminders = meals;
      _fastingAlerts = fasting;
      _weeklyDigest = weekly;
      _waterReminders = water;
      _selectedThemeAccent = accent;
    });
  }

  void _savePreferences() async {
    await PreferencesHelper.saveBool('use_metric', _useMetric);
    await PreferencesHelper.saveBool('meal_reminders', _mealReminders);
    await PreferencesHelper.saveBool('fasting_alerts', _fastingAlerts);
    await PreferencesHelper.saveBool('weekly_digest', _weeklyDigest);
    await PreferencesHelper.saveBool('water_reminders', _waterReminders);
    await PreferencesHelper.saveString('theme_accent', _selectedThemeAccent);

    // Schedule or cancel water & meal reminders
    await NotificationService.scheduleWaterReminders(_waterReminders);
    await NotificationService.scheduleMealReminders(_mealReminders);


    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Preferences saved!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
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
          'Preferences',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Preferences',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Customize how SABTRACK AI displays calculations and notifies you.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Section: Units
            _buildSectionHeader('Measurement Units'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit System',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _useMetric ? 'Metric (kg, cm, kcal)' : 'Imperial (lbs, ft/in, kcal)',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _useMetric,
                    activeColor: AppTheme.accent,
                    onChanged: (val) => setState(() => _useMetric = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Notifications
            _buildSectionHeader('Push Notifications'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _buildSwitchRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Daily Meal Reminders',
                    subtitle: 'Remind me to log breakfast, lunch, and dinner',
                    value: _mealReminders,
                    onChanged: (val) => setState(() => _mealReminders = val),
                  ),
                  _buildDivider(),
                  _buildSwitchRow(
                    icon: Icons.timer_outlined,
                    title: 'Fasting Alerts',
                    subtitle: 'Notify me when fasting windows start & end',
                    value: _fastingAlerts,
                    onChanged: (val) => setState(() => _fastingAlerts = val),
                  ),
                  _buildDivider(),
                  _buildSwitchRow(
                    icon: Icons.water_drop_outlined,
                    title: 'Daily Water Reminders',
                    subtitle: 'Remind me to drink water and stay hydrated',
                    value: _waterReminders,
                    onChanged: (val) => setState(() => _waterReminders = val),
                  ),
                  _buildDivider(),
                  _buildSwitchRow(
                    icon: Icons.mail_outline_rounded,
                    title: 'Weekly Digest',
                    subtitle: 'Email summary of my tracking & weight stats',
                    value: _weeklyDigest,
                    onChanged: (val) => setState(() => _weeklyDigest = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Aesthetics Theme Accent
            _buildSectionHeader('Theme Accent Color'),
            const SizedBox(height: 8),
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
                    'Color theme choices',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _accents.map((accent) {
                      final isSelected = _selectedThemeAccent == accent['name'];
                      final color = accent['color'] as Color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedThemeAccent = accent['name']),
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? color : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              accent['name'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppTheme.primary : Colors.black45,
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Save Button
            Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppTheme.primaryGradient,
              ),
              child: ElevatedButton(
                onPressed: _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Save Preferences',
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
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

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 12,
      thickness: 1,
      color: Color(0xFFF1F5F9),
      indent: 48,
      endIndent: 12,
    );
  }
}
