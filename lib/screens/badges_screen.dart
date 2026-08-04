import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

import '../providers/badge_provider.dart';

class BadgeInfo {
  final String id;
  final String title;
  final String description;
  final String requirement;
  final IconData icon;
  final Color color;

  const BadgeInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.requirement,
    required this.icon,
    required this.color,
  });
}

const List<BadgeInfo> allBadges = [
  BadgeInfo(
    id: 'First Log',
    title: 'First Log',
    description: 'Welcome to SABTRACK AI! Opened the app and logged your first session.',
    requirement: 'Open the app for the first time.',
    icon: Icons.verified_rounded,
    color: AppTheme.accent,
  ),
  BadgeInfo(
    id: '3 Day Streak',
    title: '3 Day Streak',
    description: 'Consistency is key. You logged your progress 3 days in a row!',
    requirement: 'Maintain a 3-day active streak.',
    icon: Icons.offline_bolt_rounded,
    color: AppTheme.neonCyan,
  ),
  BadgeInfo(
    id: '7 Day Streak',
    title: '7 Day Streak',
    description: 'Unstoppable! A full week of consecutive healthy habits.',
    requirement: 'Maintain a 7-day active streak.',
    icon: Icons.local_fire_department_rounded,
    color: AppTheme.neonPink,
  ),
  BadgeInfo(
    id: 'Hydration Hero',
    title: 'Hydration Hero',
    description: 'Perfect hydration today. You reached your daily water target!',
    requirement: 'Log at least 2500ml of water in a single day.',
    icon: Icons.local_drink_rounded,
    color: AppTheme.neonCyan,
  ),
  BadgeInfo(
    id: 'Step Master',
    title: 'Step Master',
    description: 'Walking machine! You smashed the 10,000 steps goal.',
    requirement: 'Log at least 10,000 steps in a single day.',
    icon: Icons.directions_walk_rounded,
    color: AppTheme.neonAmber,
  ),
  BadgeInfo(
    id: 'Macro Maestro',
    title: 'Macro Maestro',
    description: 'Nutrition tracked! Logged a meal into your food diary.',
    requirement: 'Add any meal/food entry.',
    icon: Icons.restaurant_rounded,
    color: AppTheme.neonEmerald,
  ),
];

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeState = ref.watch(badgeProvider);
    final earnedList = badgeState.earnedBadges;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Achievements',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header Card
                  ClipRRect(
                    borderRadius: AppTheme.cardRadius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: AppTheme.cardRadius,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Unlocked Badges',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    '${earnedList.length} / ${allBadges.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keep crushing your daily fitness goals to unlock more awards!',
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: allBadges.isEmpty ? 0 : earnedList.length / allBadges.length,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: AppTheme.accent,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All Badges',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Badges Grid
                  Expanded(
                    child: GridView.builder(
                      itemCount: allBadges.length,
                      padding: const EdgeInsets.only(bottom: 32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, index) {
                        final badge = allBadges[index];
                        final isEarned = earnedList.contains(badge.id);

                        return _buildBadgeCard(context, badge, isEarned);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeInfo badge, bool isEarned) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(context, badge, isEarned),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(
            color: isEarned ? badge.color.withOpacity(0.3) : Colors.black12,
            width: 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isEarned ? badge.color.withOpacity(0.12) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge.icon,
                    color: isEarned ? badge.color : const Color(0xFF94A3B8),
                    size: 32,
                  ),
                ),
                if (!isEarned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF64748B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isEarned ? AppTheme.primary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isEarned ? 'UNLOCKED' : 'LOCKED',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isEarned ? AppTheme.neonEmerald : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeInfo badge, bool isEarned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isEarned ? badge.color.withOpacity(0.15) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isEarned ? badge.color : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: Icon(
                      badge.icon,
                      color: isEarned ? badge.color : const Color(0xFF94A3B8),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    badge.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEarned ? 'Earned Achievement' : 'Locked Achievement',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isEarned ? AppTheme.neonEmerald : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black12, height: 1),
                  const SizedBox(height: 20),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEarned ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                          color: isEarned ? AppTheme.neonEmerald : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEarned
                                ? 'You have successfully unlocked this badge!'
                                : 'Requirement: ${badge.requirement}',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
