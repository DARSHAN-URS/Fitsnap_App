import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MyCoachTab extends StatefulWidget {
  const MyCoachTab({super.key});

  @override
  State<MyCoachTab> createState() => _MyCoachTabState();
}

class _MyCoachTabState extends State<MyCoachTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasCoach = false;
  Map<String, dynamic>? _coach;
  Map<String, dynamic>? _client;
  Map<String, dynamic>? _todayPlan;
  Map<String, dynamic>? _adherence;
  List<dynamic> _feedbacks = [];
  List<dynamic> _availableCoaches = [];
  Map<String, dynamic>? _pendingInvitation;

  final Set<String> _loggedMealNames = {};
  late AnimationController _animController;
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadCoachData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getMyCoach();
      if (res['success'] == true) {
        setState(() {
          _hasCoach = res['has_coach'] == true;
          _coach = res['coach'] != null ? Map<String, dynamic>.from(res['coach']) : null;
          _client = res['client'] != null ? Map<String, dynamic>.from(res['client']) : null;
          _todayPlan = res['today_plan'] != null ? Map<String, dynamic>.from(res['today_plan']) : null;
          _adherence = res['adherence'] != null ? Map<String, dynamic>.from(res['adherence']) : null;
          _feedbacks = res['feedbacks'] is List ? List.from(res['feedbacks']) : [];
          _availableCoaches = res['available_coaches'] is List ? List.from(res['available_coaches']) : [];
          _pendingInvitation = res['pending_invitation'] != null ? Map<String, dynamic>.from(res['pending_invitation']) : null;
          _isLoading = false;
        });
        _animController.forward(from: 0.0);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading coach data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logPrescribedMeal(Map<String, dynamic> meal) async {
    final String mealName = (meal['name'] ?? 'Prescribed Meal').toString();
    final int calories = ((meal['calories'] ?? 0) as num).toInt();
    final int protein = ((meal['protein'] ?? 0) as num).toInt();
    final int carbs = ((meal['carbs'] ?? 0) as num).toInt();
    final int fats = ((meal['fats'] ?? 0) as num).toInt();

    HapticFeedback.mediumImpact();

    // 1. Log to backend API
    await ApiService.logMeal(
      name: mealName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      description: 'Prescribed by Coach: ${meal['slot'] ?? 'Protocol'}',
    );

    // 2. Also save to user-scoped local SharedPreferences so HomeTab immediately reflects it
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    final String? userId = await ApiService.getCurrentUserId();
    final String up = userId != null ? '${userId}_' : '';

    final int currConsumed = prefs.getInt('${up}dashboard_consumed') ?? 0;
    final int currProtein = prefs.getInt('${up}dashboard_protein') ?? 0;
    final int currCarbs = prefs.getInt('${up}dashboard_carbs') ?? 0;
    final int currFats = prefs.getInt('${up}dashboard_fats') ?? 0;

    await prefs.setInt('${up}dashboard_consumed', currConsumed + calories);
    await prefs.setInt('${up}dashboard_protein', currProtein + protein);
    await prefs.setInt('${up}dashboard_carbs', currCarbs + carbs);
    await prefs.setInt('${up}dashboard_fats', currFats + fats);

    await prefs.setInt('${up}dashboard_consumed_$todayStr', currConsumed + calories);
    await prefs.setInt('${up}dashboard_protein_$todayStr', currProtein + protein);
    await prefs.setInt('${up}dashboard_carbs_$todayStr', currCarbs + carbs);
    await prefs.setInt('${up}dashboard_fats_$todayStr', currFats + fats);

    // Append to local meals list
    final String? existingMealsJson = prefs.getString('${up}dashboard_meals');
    List<dynamic> mealsList = [];
    if (existingMealsJson != null) {
      try {
        mealsList = jsonDecode(existingMealsJson);
      } catch (_) {}
    }

    final newMealObj = {
      'name': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'time': meal['time'] ?? 'Today',
      'slot': meal['slot'] ?? 'Meal',
      'tagColor': AppTheme.accent.value,
      'is_coach_prescribed': true,
      'food_items': [
        {
          'food_name': mealName,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fats,
        }
      ]
    };
    mealsList.add(newMealObj);

    await prefs.setString('${up}dashboard_meals', jsonEncode(mealsList));
    await prefs.setString('${up}dashboard_meals_$todayStr', jsonEncode(mealsList));

    setState(() {
      _loggedMealNames.add(mealName);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Logged "$mealName" to your daily diary! (+$calories kcal)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.neonEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      // Reload adherence live
      _loadCoachData();
    }
  }

  Future<void> _connectWithCode(String code, {String? coachId}) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invite code or select a coach')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    final res = await ApiService.connectCoach(
      inviteCode: cleanCode,
      coachId: coachId,
    );
    setState(() => _isConnecting = false);

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Successfully connected to coach!'),
          backgroundColor: AppTheme.neonEmerald,
        ),
      );
      _inviteCodeController.clear();
      _loadCoachData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Connection failed'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _respondToPendingInvite(bool accept) async {
    if (_pendingInvitation == null) return;
    final clientId = _pendingInvitation!['id'] ?? '';
    if (clientId.isEmpty) return;

    setState(() => _isLoading = true);
    final res = await ApiService.respondCoachingRequest(
      clientId: clientId,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Coaching request accepted! Connected.' : 'Coaching request declined.'),
          backgroundColor: accept ? AppTheme.neonEmerald : Colors.grey.shade800,
        ),
      );
      _loadCoachData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Action failed')),
      );
    }
  }

  void _openChatModal() {
    final TextEditingController msgCtrl = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Handle & Header
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(
                              _coach?['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _coach?['name'] ?? 'My Coach',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.neonEmerald,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Direct SabCoach Channel',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Chat messages list
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: ApiService.getCoachMessages(
                          coachId: _coach?['id'],
                          clientId: _client?['id'],
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                          }
                          final list = (snapshot.data?['data'] as List?) ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.forum_outlined, size: 48, color: AppTheme.accent.withOpacity(0.4)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Start a Conversation',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ask questions about your prescribed diet plan, form execution, or workout intensity.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final item = list[i];
                              final isClient = item['sender'] == 'client';
                              return Align(
                                alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    color: isClient ? AppTheme.accent : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isClient ? 16 : 4),
                                      bottomRight: Radius.circular(isClient ? 4 : 16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['text'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: isClient ? Colors.white : AppTheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isClient ? 'You' : (_coach?['name'] ?? 'Coach'),
                                        style: GoogleFonts.inter(
                                          color: isClient ? Colors.white70 : Colors.black45,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -3)),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: msgCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Message coach...',
                                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            isSending
                                ? const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                                      onPressed: () async {
                                        final txt = msgCtrl.text.trim();
                                        if (txt.isEmpty) return;
                                        setModalState(() => isSending = true);
                                        await ApiService.sendCoachMessage(
                                          text: txt,
                                          coachId: _coach?['id'],
                                          clientId: _client?['id'],
                                        );
                                        msgCtrl.clear();
                                        setModalState(() => isSending = false);
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    return RefreshIndicator(
      onRefresh: _loadCoachData,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (_pendingInvitation != null) ...[
              _buildPendingInvitationCard(),
              const SizedBox(height: 20),
            ],
            if (_hasCoach) ...[
              _buildCoachProfileCard(),
              const SizedBox(height: 20),
              if (_hasAssignedProgram) ...[
                _buildAssignedProgramCard(),
                const SizedBox(height: 20),
              ],
              _buildAdherenceTelemetryCard(),
              const SizedBox(height: 20),
              if (_todayPlan != null) ...[
                _buildTodayPrescribedPlanCard(),
                const SizedBox(height: 20),
              ],
              _buildCoachFeedbackCard(),
            ] else ...[
              _buildNotConnectedState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Coach',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hasCoach ? AppTheme.neonEmerald : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _hasCoach ? 'SabCoach Live Telemetry Synced' : 'Ready to Connect',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _hasCoach ? AppTheme.neonEmerald : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_hasCoach)
          GestureDetector(
            onTap: _openChatModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Chat',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingInvitationCard() {
    final inv = _pendingInvitation!;
    final coachName = inv['coach_name'] ?? 'Your Coach';
    final program = inv['program_name'] ?? 'Coaching Protocol';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coaching Invitation Received!',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'From $coachName • $program',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Accept this invitation to stream live meals, workouts, and biometrics to SabCoach and receive custom daily nutrition protocols.',
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToPendingInvite(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToPendingInvite(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Accept & Link', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasAssignedProgram {
    final progName = _client?['program_name']?.toString();
    return progName != null &&
        progName.isNotEmpty &&
        progName != 'Not Assigned' &&
        progName != 'Standard Protocol' &&
        progName != 'null';
  }

  Widget _buildAssignedProgramCard() {
    final progName = _client?['program_name'] ?? 'Training Protocol';
    final progDetail = (_client?['program_detail'] as Map?) ?? {};
    final weekCurrent = progDetail['weekCurrent'] ?? 1;
    final weekTotal = progDetail['weekTotal'] ?? 12;
    final workoutsThisWeek = progDetail['workoutsThisWeek'] ?? '4 sessions/week';
    final targetSummary = progDetail['targetSummary'] ?? 'Periodized progressive overload program.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, color: AppTheme.neonEmerald, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Training Program',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        progName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.neonEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonEmerald.withOpacity(0.3)),
                ),
                child: Text(
                  'Week $weekCurrent of $weekTotal',
                  style: GoogleFonts.inter(
                    color: AppTheme.neonEmerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppTheme.neonCyan, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$workoutsThisWeek • $targetSummary',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachProfileCard() {
    final name = _coach?['name'] ?? 'Coach';
    final title = _coach?['title'] ?? 'Performance & Nutrition Coach';
    final specialty = _coach?['specialty'] ?? 'Hypertrophy & Metabolic Health';
    final avatar = _coach?['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';
    final rating = (_coach?['rating'] ?? 4.95).toString();
    final certs = (_coach?['certifications'] as List?) ?? ['ISSA Master Trainer', 'Nutrition Specialist'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(avatar),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.neonEmerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                rating,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: certs.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  c.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceTelemetryCard() {
    final adh = _adherence ?? {};
    final double adherenceScore = ((adh['adherence_percentage'] ?? 92.0) as num).toDouble();
    final String status = adh['status'] ?? 'Optimal Adherence';
    final prescribed = adh['prescribed'] as Map? ?? {};
    final actual = adh['actual'] as Map? ?? {};

    final int targetCal = (prescribed['calories'] ?? _todayPlan?['total_calories'] ?? 2250) as int;
    final int actualCal = (actual['calories'] ?? 0) as int;
    final double targetProt = ((prescribed['protein'] ?? _todayPlan?['protein_g'] ?? 165.0) as num).toDouble();
    final double actualProt = ((actual['protein'] ?? 0.0) as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.neonCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Coach Telemetry Stream',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.neonEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonEmerald.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.neonEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: GoogleFonts.inter(
                        color: AppTheme.neonEmerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (adherenceScore / 100).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                    ),
                    Center(
                      child: Text(
                        '${adherenceScore.toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Compliance Tracking',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$actualCal / $targetCal kcal logged',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Protein: ${actualProt.toInt()}g of ${targetProt.toInt()}g target',
                      style: GoogleFonts.inter(
                        color: AppTheme.neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your coach sees each logged plate in real time to adjust your macro targets and recovery pacing.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPrescribedPlanCard() {
    final plan = _todayPlan ?? {};
    final title = plan['title'] ?? 'Prescribed Daily Protocol';
    final desc = plan['description'] ?? 'Target nutrition designed for optimal recomposition.';
    final meals = (plan['meals'] as List?) ?? [];
    final supps = (plan['supplements'] as List?) ?? [];
    final instructions = plan['instructions'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                'Today\'s Prescribed Protocol',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plan['total_calories'] ?? 2250} kcal',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 16),
          // Macro goals row
          _buildMacroSummaryRow(plan),
          const SizedBox(height: 20),
          // Prescribed Meals
          Text(
            'Prescribed Meals & Timing',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (meals.isEmpty)
            Text(
              'No specific meal slots prescribed for today yet.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            )
          else
            ...meals.map((m) => _buildMealSlotItem(Map<String, dynamic>.from(m as Map))),
          
          if (supps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Prescribed Supplements',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: supps.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.neonEmerald, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coach Instructions',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instructions,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF78350F),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroSummaryRow(Map<String, dynamic> plan) {
    final protein = plan['protein_g'] ?? 165;
    final carbs = plan['carbs_g'] ?? 240;
    final fats = plan['fats_g'] ?? 65;
    final water = plan['water_liters'] ?? 3.5;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroPill('Protein', '${protein}g', const Color(0xFF6366F1)),
          _buildMacroPill('Carbs', '${carbs}g', const Color(0xFF06B6D4)),
          _buildMacroPill('Fats', '${fats}g', const Color(0xFFEC4899)),
          _buildMacroPill('Water', '${water}L', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildMacroPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSlotItem(Map<String, dynamic> meal) {
    final name = meal['name'] ?? 'Prescribed Meal';
    final slot = meal['slot'] ?? 'Meal';
    final time = meal['time'] ?? '';
    final cals = meal['calories'] ?? 0;
    final prot = meal['protein'] ?? 0;
    final ingredients = meal['ingredients'] ?? '';
    final notes = meal['notes'] ?? '';
    final isLogged = _loggedMealNames.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLogged ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLogged ? AppTheme.neonEmerald.withOpacity(0.5) : const Color(0xFFE2E8F0),
          width: isLogged ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      slot.toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
              Text(
                '$cals kcal • ${prot}g P',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppTheme.primary,
            ),
          ),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ingredients,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Coach note: $notes',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF0369A1),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: isLogged
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.neonEmerald, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        'Logged to Diary',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonEmerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : OutlinedButton.icon(
                    onPressed: () => _logPrescribedMeal(meal),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      'Log to Diary',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                'Coach Daily Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const Icon(Icons.rate_review_outlined, color: AppTheme.accent, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          if (_feedbacks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coach has not submitted feedback for today yet. Keep logging your plates!',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._feedbacks.map((fb) {
              final text = fb['feedback_text'] ?? fb['text'] ?? '';
              final rating = fb['rating'] ?? 'great';
              final date = fb['date'] ?? 'Today';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: rating == 'great' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rating.toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: rating == 'great' ? const Color(0xFF047857) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        Text(
                          date.toString(),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), height: 1.35),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marketing Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'SABCOACH ECOSYSTEM',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Personalized Protocols & Real-Time Accountability',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Link directly with your coach. Every meal, workout, and metric logged on SabTrack streams live to their telemetry dashboard.',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Connect with Invite Code Box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Coach Pairing Code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Got a code from your personal trainer? Enter it here to link your profiles.',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inviteCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'e.g. SAB-424124',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isConnecting
                        ? null
                        : () => _connectWithCode(_inviteCodeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Connect', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_availableCoaches.isNotEmpty) ...[
          Text(
            'Featured Certified SabCoaches',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ..._availableCoaches.map((c) => _buildAvailableCoachCard(Map<String, dynamic>.from(c as Map))),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Have a Coach Invite Code?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ask your coach for their code (e.g. SAB-...) and enter it above to link your continuous telemetry.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailableCoachCard(Map<String, dynamic> coach) {
    final name = coach['name'] ?? 'Coach';
    final title = coach['title'] ?? 'Performance Coach';
    final specialty = coach['specialty'] ?? 'Nutrition & Strength';
    final bio = coach['bio'] ?? '';
    final avatar = coach['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';
    final code = coach['invite_code'] ?? 'SAB-DEFAULT';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(avatar),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    Text(
                      specialty,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.35),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code: $code',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _connectWithCode(code, coachId: coach['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Connect Coach', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
