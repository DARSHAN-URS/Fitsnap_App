import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for the leaderboard
    final List<Map<String, dynamic>> leaderboardData = [
      {'name': 'Alex Johnson', 'points': 4500, 'avatar': 'AJ'},
      {'name': 'Darshan Urs', 'points': 4200, 'avatar': 'DU', 'isMe': true},
      {'name': 'Sarah Smith', 'points': 3900, 'avatar': 'SS'},
      {'name': 'Mike Brown', 'points': 3500, 'avatar': 'MB'},
      {'name': 'Emma Davis', 'points': 3100, 'avatar': 'ED'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Weekly Leaderboard',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: leaderboardData.length,
        itemBuilder: (context, index) {
          final user = leaderboardData[index];
          final isMe = user['isMe'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.accent.withOpacity(0.1) : Colors.white,
              borderRadius: AppTheme.cardRadius,
              boxShadow: isMe ? [] : AppTheme.cardShadow,
              border: isMe ? Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5) : null,
            ),
            child: ClipRRect(
              borderRadius: AppTheme.cardRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showUserDetailDialog(context, user),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '#${index + 1}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: index < 3 ? AppTheme.neonPink : Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 16),
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            user['avatar'],
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            user['name'] + (isMe ? ' (You)' : ''),
                            style: GoogleFonts.inter(
                              fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          '${user['points']} pts',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserDetailDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  user['avatar'],
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user['name'],
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly Score: ${user['points']} pts',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.black12),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat('Workouts', '14'),
                  _buildProfileStat('Calories', '1.8k/d'),
                  _buildProfileStat('Streak', '12 days'),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Close Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.black38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
