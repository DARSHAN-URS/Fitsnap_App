import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../utils/preferences_helper.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';
import '../services/api_service.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  bool _isLoading = true;
  String? _challengeId;
  String _title = '7-Day Core Crusher';
  String _description = 'Complete 5 core workouts this week to earn the exclusive Golden Abs badge.';
  int _targetWorkouts = 5;
  int _completedWorkouts = 0;
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    _loadCachedChallengeData();
  }

  Future<void> _loadCachedChallengeData() async {
    final cachedDetails = await PreferencesHelper.readString('cache_challenge_details');
    final cachedEnrollment = await PreferencesHelper.readString('cache_challenge_enrollment');
    
    bool hasCached = false;
    if (cachedDetails != null) {
      try {
        final ch = jsonDecode(cachedDetails);
        _challengeId = ch['id'].toString();
        _title = ch['title'] ?? _title;
        _description = ch['description'] ?? _description;
        _targetWorkouts = ch['target_workouts'] ?? _targetWorkouts;
        _isLoading = false;
        hasCached = true;
      } catch (_) {}
    }
    
    if (cachedEnrollment != null) {
      try {
        final enrollment = jsonDecode(cachedEnrollment);
        _isJoined = true;
        _completedWorkouts = enrollment['completed_workouts'] ?? 0;
        _isLoading = false;
        hasCached = true;
      } catch (_) {}
    }
    
    if (hasCached && mounted) {
      setState(() {});
    }
    
    await _fetchChallengeData();
  }


  Future<void> _fetchChallengeData() async {
    if (!mounted) return;
    if (_challengeId == null) {
      setState(() => _isLoading = true);
    }
    
    final challengesRes = await ApiService.getChallenges();
    final userChallengesRes = await ApiService.getUserChallenges();
    
    String? newChallengeId = _challengeId;
    String newTitle = _title;
    String newDescription = _description;
    int newTargetWorkouts = _targetWorkouts;
    
    if (challengesRes['success'] == true) {
      final List<dynamic> list = challengesRes['data'] ?? [];
      if (list.isNotEmpty) {
        final ch = list.first;
        newChallengeId = ch['id'].toString();
        newTitle = ch['title'] ?? _title;
        newDescription = ch['description'] ?? _description;
        newTargetWorkouts = ch['target_workouts'] ?? _targetWorkouts;
        await PreferencesHelper.saveString('cache_challenge_details', jsonEncode(ch));
      }
    }
    
    bool newIsJoined = _isJoined;
    int newCompletedWorkouts = _completedWorkouts;
    
    if (userChallengesRes['success'] == true && newChallengeId != null) {
      final List<dynamic> userList = userChallengesRes['data'] ?? [];
      final enrollment = userList.firstWhere(
        (uc) {
          final cid = uc['challenge_id']?.toString() ?? uc['challenges']?['id']?.toString();
          return cid == newChallengeId;
        },
        orElse: () => null,
      );
      
      if (enrollment != null) {
        newIsJoined = true;
        newCompletedWorkouts = enrollment['completed_workouts'] ?? 0;
        await PreferencesHelper.saveString('cache_challenge_enrollment', jsonEncode(enrollment));
      } else {
        newIsJoined = false;
        newCompletedWorkouts = 0;
        await PreferencesHelper.delete('cache_challenge_enrollment');
      }
    }
    
    if (mounted) {
      setState(() {
        _challengeId = newChallengeId;
        _title = newTitle;
        _description = newDescription;
        _targetWorkouts = newTargetWorkouts;
        _isJoined = newIsJoined;
        _completedWorkouts = newCompletedWorkouts;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChallengeData() async {
    await _fetchChallengeData();
  }

  Future<void> _joinChallenge() async {
    if (_challengeId == null) return;
    if (mounted) setState(() => _isLoading = true);
    final res = await ApiService.joinChallenge(_challengeId!);
    if (res['success'] == true) {
      await _loadChallengeData();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to join challenge')),
        );
      }
    }
  }

  Future<void> _startTask(String taskTitle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(
          activityType: taskTitle,
          icon: Icons.star_rounded,
          color: AppTheme.accent,
          avgPaceSeconds: 300,
          kcalPerKm: 120,
        ),
      ),
    );
    if (_challengeId != null) {
      if (mounted) setState(() => _isLoading = true);
      final res = await ApiService.updateChallengeProgress(_challengeId!);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Completed task: $taskTitle! Progress updated.')),
          );
        }
      }
      await _loadChallengeData();
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
          'Weekly Challenge',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.neonCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppTheme.cardRadius,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isJoined) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _targetWorkouts > 0 ? (_completedWorkouts / _targetWorkouts) : 0.0,
                              backgroundColor: Colors.black26,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_completedWorkouts/$_targetWorkouts Workouts Completed',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _joinChallenge,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            ),
                            child: Text(
                              'Join Challenge Now',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isJoined) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Challenge Tasks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTaskTile(context, '15-Min Core Blast', _completedWorkouts >= 1),
                    _buildTaskTile(context, 'HIIT Cardio Burn (Core focus)', _completedWorkouts >= 2),
                    _buildTaskTile(context, 'Plank Challenge', _completedWorkouts >= 3),
                    _buildTaskTile(context, 'Russian Twists', _completedWorkouts >= 4),
                    _buildTaskTile(context, 'Leg Raises', _completedWorkouts >= 5),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTaskTile(BuildContext context, String title, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCompleted ? null : () => _startTask(title),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppTheme.accent : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                      color: isCompleted ? Colors.white : Colors.grey.shade400,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? Colors.black45 : AppTheme.primary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (!isCompleted)
                    const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
