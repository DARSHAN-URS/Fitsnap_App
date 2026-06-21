import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../utils/preferences_helper.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboardData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedAndFetch();
  }

  Future<void> _loadCachedAndFetch() async {
    final cached = await PreferencesHelper.readString('cache_weekly_leaderboard');
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        setState(() {
          _leaderboardData = data;
          _isLoading = false;
        });
      } catch (_) {}
    }
    await _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    if (!mounted) return;
    if (_leaderboardData.isEmpty) {
      setState(() => _isLoading = true);
    }
    final res = await ApiService.getLeaderboard();
    if (res['success'] == true) {
      final List<dynamic> data = res['data'] ?? [];
      await PreferencesHelper.saveString('cache_weekly_leaderboard', jsonEncode(data));
      if (mounted) {
        setState(() {
          _leaderboardData = data;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_leaderboardData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Failed to load leaderboard')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              color: AppTheme.accent,
              child: _leaderboardData.isEmpty
                  ? Center(
                      child: Text(
                        'No leaderboard rankings yet.',
                        style: GoogleFonts.inter(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _leaderboardData.length,
                      itemBuilder: (context, index) {
                        final user = _leaderboardData[index];
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
                                          user['avatar'] ?? 'US',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppTheme.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          (user['name'] ?? 'User') + (isMe ? ' (You)' : ''),
                                          style: GoogleFonts.inter(
                                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 16,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${user['points'] ?? 0} pts',
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
            ),
    );
  }

  void _showUserDetailDialog(BuildContext context, Map<String, dynamic> user) {
    final int pts = (user['points'] ?? 0) as int;
    final int workouts = pts ~/ 100 + 1;
    final int streak = (pts ~/ 200).clamp(1, 15);
    final String calories = "${(pts * 0.45).toStringAsFixed(0)} kcal";

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
                  user['avatar'] ?? 'US',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user['name'] ?? 'User',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly Score: ${user['points'] ?? 0} pts',
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
                  _buildProfileStat('Workouts', '$workouts'),
                  _buildProfileStat('Calories', calories),
                  _buildProfileStat('Streak', '$streak days'),
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
