import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Groups',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -1,
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 24),
              )
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
            ),
            child: TextField(
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primary),
              decoration: InputDecoration(
                hintText: 'Search communities, challenges...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discover Communities',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'Create Private',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildGroupCard(
            title: 'Fitness & Workouts',
            members: '114 members',
            desc: 'Share daily workouts that match your calorie goals, keep each other accountable.',
            icon: Icons.fitness_center_rounded,
            color: AppTheme.carbsColor,
            avatars: ['JD', 'RS', 'A'],
            memberCount: '+11',
            tag: 'Trending',
          ),
          _buildGroupCard(
            title: 'New to Calorie Tracking',
            members: '162 members',
            desc: 'Beginner questions, quick meal tips, tracking shortcuts, and celebrating first wins.',
            icon: Icons.track_changes_rounded,
            color: AppTheme.accent,
            avatars: ['M', 'TL', 'BK'],
            memberCount: '+34',
            tag: 'Popular',
          ),
          _buildGroupCard(
            title: 'Muscle Gain & Bulking',
            members: '199 members',
            desc: 'Strategies for eating in a clean surplus, protein recipes, and heavy weight lifting.',
            icon: Icons.accessibility_new_rounded,
            color: AppTheme.neonEmerald,
            avatars: ['P', 'SO', 'D'],
            memberCount: '+18',
            tag: 'Highly Active',
          ),
          _buildGroupCard(
            title: 'Clean Fasting Habits',
            members: '89 members',
            desc: 'Share your intermittent fasting protocols, water fasting tips, and support.',
            icon: Icons.timer_outlined,
            color: AppTheme.neonPink,
            avatars: ['E', 'W', 'CH'],
            memberCount: '+4',
            tag: 'New',
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard({
    required String title,
    required String members,
    required String desc,
    required IconData icon,
    required Color color,
    required List<String> avatars,
    required String memberCount,
    required String tag,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      members,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            desc,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Overlapping Avatar Stack
              _buildAvatarStack(avatars, memberCount),
              
              // Join Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Text(
                  'Join Group',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(List<String> initials, String extraCount) {
    List<Widget> items = [];
    
    for (int i = 0; i < initials.length; i++) {
      items.add(
        Positioned(
          left: i * 18.0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _getAvatarColor(i),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                initials[i],
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Extra count circle
    items.add(
      Positioned(
        left: initials.length * 18.0,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              extraCount,
              style: GoogleFonts.inter(
                color: Colors.black54,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: (initials.length + 1) * 18.0 + 8.0,
      height: 26,
      child: Stack(
        children: items,
      ),
    );
  }

  Color _getAvatarColor(int index) {
    List<Color> colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
    ];
    return colors[index % colors.length];
  }
}
