import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';

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

  // SabCoach Inbox
  List<Map<String, dynamic>> _sabcoachUpdates = [];
  int _unreadCoachingCount = 0;

  // Quick-stat toggles
  bool _showDisconnectConfirm = false;
  Timer? _pollTimer;

  String _coachSearchQuery = '';
  String _selectedCoachSpecialty = 'All';
  final Map<String, String> _feedbackReactions = {};

  final Set<String> _loggedMealNames = {};
  late AnimationController _animController;
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _refreshAll();
    // Light background poll every 5 min so inbox badge stays fresh
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _loadSabcoachUpdates();
    });
  }

  Future<void> _refreshAll() async {
    await _loadCoachData();
    if (mounted) {
      await _loadSabcoachUpdates();
    }
  }

  Future<void> _loadSabcoachUpdates() async {
    try {
      final res = await ApiService.getNotifications();
      if (res['success'] == true && res['data'] != null) {
        final List<dynamic> all = res['data'];
        // Filter to coaching-related notification types only
        const coachingTypes = {
          'coaching_request',
          'coaching_accepted',
          'coaching_declined',
          'program_assigned',
          'program_shared',
          'coach_feedback',
        };
        final filtered = all
            .whereType<Map>()
            .where((n) {
              final type = n['type'] ?? n['notif_type'];
              if (!coachingTypes.contains(type)) return false;
              final extraData = (n['extra_data'] ?? n['data']) as Map? ?? {};
              final status = extraData['status']?.toString().toLowerCase();
              final bool responded = extraData['responded'] == true || status == 'accepted' || status == 'declined';
              // If it's a coaching_request that is already responded or read or if the user is already connected to coach, don't show pending invitation
              if (type == 'coaching_request' && (responded || n['is_read'] == true || _hasCoach)) {
                return false;
              }
              return true;
            })
            .map((n) => Map<String, dynamic>.from(n))
            .toList();
        if (mounted) {
          setState(() {
            _sabcoachUpdates = filtered;
            _unreadCoachingCount = filtered.where((n) => n['is_read'] != true).length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading SabCoach updates: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
          if (_hasCoach) {
            _pendingInvitation = null;
          } else {
            _pendingInvitation = res['pending_invitation'] != null ? Map<String, dynamic>.from(res['pending_invitation']) : null;
          }
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

    setState(() {
      _isLoading = true;
      _pendingInvitation = null;
    });
    final res = await ApiService.respondCoachingRequest(
      clientId: clientId,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (accept && res['client'] != null && mounted) {
        setState(() {
          _hasCoach = true;
          _client = Map<String, dynamic>.from(res['client']);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Coaching request accepted! Connected.' : 'Coaching request declined.'),
          backgroundColor: accept ? AppTheme.neonEmerald : Colors.grey.shade800,
        ),
      );
      await _refreshAll();
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
      return _buildLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            // SabCoach Inbox — coaching invitations + updates
            if (_pendingInvitation != null || _sabcoachUpdates.isNotEmpty) ...[
              _buildSabcoachInbox(),
              const SizedBox(height: 20),
            ],
            if (_hasCoach) ...[
              _buildCoachProfileCard(),
              const SizedBox(height: 16),
              _buildQuickStatsStrip(),
              const SizedBox(height: 16),
              if (_hasAssignedProgram) ...[
                _buildAssignedProgramCard(),
                const SizedBox(height: 16),
              ],
              _buildAdherenceTelemetryCard(),
              const SizedBox(height: 16),
              if (_todayPlan != null) ...[
                _buildTodayPrescribedPlanCard(),
                const SizedBox(height: 16),
              ],
              _buildCoachFeedbackCard(),
              const SizedBox(height: 16),
              _buildDisconnectSection(),
            ] else ...[
              _buildNotConnectedState(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Loading Skeleton ────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmer(width: 130, height: 32, radius: 10),
                  const SizedBox(height: 8),
                  _shimmer(width: 200, height: 14, radius: 7),
                ],
              ),
              _shimmer(width: 44, height: 44, radius: 14),
            ],
          ),
          const SizedBox(height: 24),
          _shimmer(width: double.infinity, height: 140, radius: 22),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
          ]),
          const SizedBox(height: 14),
          _shimmer(width: double.infinity, height: 170, radius: 22),
          const SizedBox(height: 14),
          _shimmer(width: double.infinity, height: 220, radius: 22),
        ],
      ),
    );
  }

  Widget _shimmer({required double width, required double height, required double radius}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF1F5F9), value),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
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
        Row(
          children: [
            // Notification bell with unread badge
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ).then((_) => _loadSabcoachUpdates());
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  if (_unreadCoachingCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          _unreadCoachingCount > 9 ? '9+' : '$_unreadCoachingCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_hasCoach) ...[
              const SizedBox(width: 10),
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
          ],
        ),
      ],
    );
  }

  // ── SabCoach Inbox ──────────────────────────────────────────────────────────
  Widget _buildSabcoachInbox() {
    final items = <Widget>[];

    // 1. Pending coaching invitation from getMyCoach()
    if (_pendingInvitation != null) {
      final inv = _pendingInvitation!;
      final coachName = inv['coach_name'] ?? 'Your Coach';
      final program = inv['program_name'] ?? 'Coaching Protocol';
      final clientId = (inv['id'] ?? '').toString();
      final coachId = (inv['coach_id'] ?? '').toString();
      items.add(_buildInboxItem(
        icon: Icons.mail_outline_rounded,
        color: const Color(0xFF6366F1),
        title: 'Coaching Invitation',
        subtitle: 'From $coachName · $program',
        body: 'Accept to stream live meals, workouts & biometrics to SabCoach and receive personalized protocols.',
        isUnread: true,
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  if (clientId.isNotEmpty) {
                    setState(() {
                      _isLoading = true;
                      _pendingInvitation = null;
                    });
                    await ApiService.respondCoachingRequest(clientId: clientId, accept: false);
                    await _refreshAll();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (clientId.isNotEmpty) {
                    setState(() {
                      _isLoading = true;
                      _pendingInvitation = null;
                    });
                    final res = await ApiService.respondCoachingRequest(
                      clientId: clientId,
                      accept: true,
                      coachId: coachId.isNotEmpty ? coachId : null,
                    );
                    if (res['success'] == true && res['client'] != null && mounted) {
                      setState(() {
                        _hasCoach = true;
                        _client = Map<String, dynamic>.from(res['client']);
                      });
                    }
                    await _refreshAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Connected! Live telemetry is now streaming to your coach.'),
                          backgroundColor: AppTheme.neonEmerald,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Accept & Link', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ));
    }

    // 2. Coaching-related notifications from the notification feed
    for (int i = 0; i < _sabcoachUpdates.length; i++) {
      final n = _sabcoachUpdates[i];
      final type = n['type'] as String? ?? '';
      final isUnread = n['is_read'] != true;
      final notifId = (n['id'] ?? '').toString();
      Map<String, dynamic> extraData = {};
      final rawExtra = n['extra_data'] ?? n['data'];
      if (rawExtra is Map) {
        extraData = Map<String, dynamic>.from(rawExtra);
      } else if (rawExtra is String && rawExtra.isNotEmpty) {
        try {
          extraData = Map<String, dynamic>.from(jsonDecode(rawExtra));
        } catch (_) {}
      }
      final clientId = (extraData['client_id'] ?? n['client_id'] ?? '').toString();
      final coachId = (extraData['coach_id'] ?? n['coach_id'] ?? '').toString();
      final coachName = (extraData['coach_name'] ?? n['coach_name'] ?? 'Your Coach').toString();

      Color itemColor;
      IconData itemIcon;
      switch (type) {
        case 'coaching_request':
          itemColor = const Color(0xFF6366F1);
          itemIcon = Icons.sports_rounded;
          break;
        case 'coaching_accepted':
          itemColor = AppTheme.neonEmerald;
          itemIcon = Icons.verified_user_rounded;
          break;
        case 'coaching_declined':
          itemColor = const Color(0xFF94A3B8);
          itemIcon = Icons.cancel_outlined;
          break;
        case 'program_assigned':
        case 'program_shared':
          itemColor = const Color(0xFF10B981);
          itemIcon = Icons.fitness_center_rounded;
          break;
        case 'coach_feedback':
          itemColor = const Color(0xFF06B6D4);
          itemIcon = Icons.rate_review_rounded;
          break;
        default:
          itemColor = AppTheme.accent;
          itemIcon = Icons.notifications_rounded;
      }

      Widget? actionWidget;
      if (type == 'coaching_request' && clientId.isNotEmpty) {
        actionWidget = Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  setState(() {
                    _sabcoachUpdates.removeAt(i);
                    _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
                  });
                  await ApiService.respondCoachingRequest(
                    clientId: clientId,
                    accept: false,
                    coachId: coachId.isNotEmpty ? coachId : null,
                  );
                  if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);
                  await _refreshAll();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _pendingInvitation = null;
                    _sabcoachUpdates.removeAt(i);
                    _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
                  });
                  final res = await ApiService.respondCoachingRequest(
                    clientId: clientId,
                    accept: true,
                    coachId: coachId.isNotEmpty ? coachId : null,
                  );
                  if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);

                  if (res['success'] == true && res['client'] != null && mounted) {
                    final savedClient = Map<String, dynamic>.from(res['client']);
                    setState(() {
                      _hasCoach = true;
                      _client = savedClient;
                      _coach ??= {
                        'id': coachId.isNotEmpty ? coachId : (savedClient['coach_id'] ?? 'coach_default'),
                        'name': coachName.isNotEmpty ? coachName : 'Your Coach',
                        'title': 'Performance & Nutrition Coach',
                        'specialty': 'Health & Fitness',
                        'bio': 'Dedicated performance coach on the SabCoach Ecosystem.',
                        'rating': 4.95,
                        'certifications': ['ISSA Certified', 'Precision Nutrition'],
                      };
                    });
                  }

                  await _refreshAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Connected! SabCoach telemetry link is live.'),
                        backgroundColor: AppTheme.neonEmerald,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: Text('Accept & Connect', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ],
        );
      } else if (type == 'program_assigned' || type == 'program_shared') {
        actionWidget = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);
              _loadSabcoachUpdates();
            },
            icon: const Icon(Icons.fitness_center_rounded, size: 15),
            label: Text('View in My Coach', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }

      items.add(_buildInboxItem(
        icon: itemIcon,
        color: itemColor,
        title: n['title'] ?? 'SabCoach Update',
        subtitle: type == 'coach_feedback'
            ? 'Coach Feedback'
            : type == 'coaching_accepted'
                ? 'Request Accepted'
                : type == 'coaching_declined'
                    ? 'Request Declined'
                    : type.replaceAll('_', ' ').toUpperCase(),
        body: n['body'] ?? '',
        isUnread: isUnread,
        actions: actionWidget,
        onTap: () async {
          if (isUnread && notifId.isNotEmpty) {
            await ApiService.markNotificationRead(notifId);
            setState(() {
              _sabcoachUpdates[i]['is_read'] = true;
              _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
            });
          }
        },
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inbox_rounded, color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'SabCoach Inbox',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
                if (_unreadCoachingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_unreadCoachingCount new',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ).then((_) => _loadSabcoachUpdates());
              },
              child: Text(
                'See All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildInboxItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String body,
    required bool isUnread,
    Widget? actions,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnread ? color.withOpacity(0.28) : const Color(0xFFE2E8F0),
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ],
            if (actions != null) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        ),
      ),
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

  // ── Quick Stats Strip ──────────────────────────────────────────────────────
  Widget _buildQuickStatsStrip() {
    final adh = _adherence ?? {};
    final double score = ((adh['adherence_percentage'] ?? 92.0) as num).toDouble();
    final int streak = ((adh['streak_days'] ?? _client?['streak_days'] ?? 0) as num).toInt();
    final int sessions = ((adh['sessions_this_week'] ?? _client?['sessions_this_week'] ?? 0) as num).toInt();

    return Row(
      children: [
        _buildStatTile('${score.toInt()}%', 'Adherence', Icons.bolt_rounded, const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        _buildStatTile('${streak}d', 'Streak', Icons.local_fire_department_rounded, const Color(0xFFF97316)),
        const SizedBox(width: 10),
        _buildStatTile('$sessions', 'Sessions', Icons.fitness_center_rounded, AppTheme.neonEmerald),
      ],
    );
  }

  Widget _buildStatTile(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
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
    final since = _client?['created_at'] != null
        ? (() {
            try {
              final dt = DateTime.parse(_client!['created_at'].toString());
              return 'Since ${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {
              return 'Active';
            }
          })()
        : 'Active';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Gradient hero banner
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.35), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.neonEmerald,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          specialty,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFCD34D)),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _openChatModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'Chat',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Certs + since row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'Connected · $since',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: certs.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          c.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disconnect Section ──────────────────────────────────────────────────────
  Widget _buildDisconnectSection() {
    if (!_showDisconnectConfirm) {
      return GestureDetector(
        onTap: () => setState(() => _showDisconnectConfirm = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                'Disconnect from Coach',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Text(
            'Are you sure you want to disconnect?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF991B1B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Your coach will lose access to your live telemetry stream.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFFB91C1C),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDisconnectConfirm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Disconnect by clearing — no dedicated API needed; just reload
                    setState(() {
                      _hasCoach = false;
                      _coach = null;
                      _client = null;
                      _todayPlan = null;
                      _feedbacks = [];
                      _showDisconnectConfirm = false;
                    });
                    await _loadCoachData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text('Disconnect', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
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

    final int targetCal = ((prescribed['calories'] ?? _todayPlan?['total_calories'] ?? 2250) as num).toInt();
    final int actualCal = ((actual['calories'] ?? 0) as num).toInt();
    final double targetProt = ((prescribed['protein'] ?? _todayPlan?['protein_g'] ?? 165.0) as num).toDouble();
    final double actualProt = ((actual['protein'] ?? 0.0) as num).toDouble();
    final double targetCarbs = ((prescribed['carbs'] ?? _todayPlan?['carbs_g'] ?? 240.0) as num).toDouble();
    final double actualCarbs = ((actual['carbs'] ?? 0.0) as num).toDouble();
    final double targetFats = ((prescribed['fats'] ?? _todayPlan?['fats_g'] ?? 65.0) as num).toDouble();
    final double actualFats = ((actual['fats'] ?? 0.0) as num).toDouble();

    double pct(double a, double t) => t > 0 ? (a / t).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1A2744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.neonCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Live Telemetry',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.neonEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonEmerald.withOpacity(0.35)),
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
          // Score ring + calorie info
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: pct(adherenceScore, 100),
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${adherenceScore.toInt()}%',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Score',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
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
                      'Calorie Compliance',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$actualCal kcal',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'of $targetCal',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct(actualCal.toDouble(), targetCal.toDouble()),
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Macro progress bars
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMacroBar('Protein', actualProt, targetProt, const Color(0xFF818CF8)),
                const SizedBox(height: 10),
                _buildMacroBar('Carbs', actualCarbs, targetCarbs, AppTheme.neonCyan),
                const SizedBox(height: 10),
                _buildMacroBar('Fats', actualFats, targetFats, const Color(0xFFF472B6)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Your coach monitors every logged plate in real time to fine-tune your macro targets.',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, double actual, double target, Color color) {
    final pct = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final over = actual > target && target > 0;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(over ? const Color(0xFFFBBF24) : color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${actual.toInt()}/${target.toInt()}g',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: over ? const Color(0xFFFBBF24) : Colors.white54,
          ),
        ),
      ],
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
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Dispatched for ${plan['target_date'] ?? 'Today'} · Live from SabCoach',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
    final protein = (plan['protein_g'] ?? 165) as num;
    final carbs = (plan['carbs_g'] ?? 240) as num;
    final fats = (plan['fats_g'] ?? 65) as num;
    final water = (plan['water_liters'] ?? 3.5) as num;

    final targets = [
      _MacroGoal('Protein', '${protein.toInt()}g', const Color(0xFF818CF8), Icons.egg_outlined),
      _MacroGoal('Carbs', '${carbs.toInt()}g', const Color(0xFF06B6D4), Icons.rice_bowl_outlined),
      _MacroGoal('Fats', '${fats.toInt()}g', const Color(0xFFF472B6), Icons.opacity_rounded),
      _MacroGoal('Water', '${water}L', const Color(0xFF10B981), Icons.water_drop_outlined),
    ];

    return Row(
      children: targets.asMap().entries.map((e) {
        final t = e.value;
        final isLast = e.key == targets.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(t.icon, color: t.color, size: 18),
                const SizedBox(height: 6),
                Text(
                  t.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: t.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFF06B6D4), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Coach Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              if (_feedbacks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_feedbacks.length} notes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0891B2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_feedbacks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFCBD5E1), size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Awaiting Coach Feedback',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep logging your meals & workouts. Your coach will review your data and leave feedback soon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
                  ),
                ],
              ),
            )
          else
            ..._feedbacks.map((fb) {
              final text = (fb['feedback_text'] ?? fb['text'] ?? '').toString();
              final rating = (fb['rating'] ?? 'great').toString().toLowerCase();
              final date = (fb['date'] ?? 'Today').toString();
              final ratingColor = rating == 'great'
                  ? const Color(0xFF059669)
                  : rating == 'needs_work'
                      ? const Color(0xFFD97706)
                      : const Color(0xFF0891B2);
              final ratingBg = rating == 'great'
                  ? const Color(0xFFECFDF5)
                  : rating == 'needs_work'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0F7FA);
              final ratingIcon = rating == 'great'
                  ? Icons.thumb_up_rounded
                  : rating == 'needs_work'
                      ? Icons.trending_up_rounded
                      : Icons.info_outline_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ratingBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ratingColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ratingIcon, color: ratingColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          rating.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: ratingColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          date,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildReactionChip(fb, '💪 Thanks!'),
                        const SizedBox(width: 6),
                        _buildReactionChip(fb, '🔥 On it!'),
                        const Spacer(),
                        InkWell(
                          onTap: _openChatModal,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReactionChip(dynamic fb, String label) {
    final key = (fb['id'] ?? fb['feedback_text'] ?? '').toString();
    final isSelected = _feedbackReactions[key] == label;
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _feedbackReactions.remove(key);
          } else {
            _feedbackReactions[key] = label;
          }
        });
        if (!isSelected) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reaction "$label" sent to your coach!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.white.withOpacity(0.6),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingInvitation != null) ...[
          _buildPendingInvitationCard(),
          const SizedBox(height: 20),
        ],
        // Hero banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.40),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 13),
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
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Your Coach. Your Data.\nReal-Time Accountability.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Link with your personal trainer. Every plate, workout, and biometric you log on SabTrack streams live to their telemetry dashboard.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              // Feature pills
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _featurePill(Icons.restaurant_menu_rounded, 'Diet Protocols'),
                  _featurePill(Icons.fitness_center_rounded, 'Training Plans'),
                  _featurePill(Icons.bolt_rounded, 'Live Telemetry'),
                  _featurePill(Icons.feedback_rounded, 'Daily Feedback'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // How it works strip
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How it works',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              _buildStep(1, 'Get your pairing code', 'Ask your coach for their SAB-... invite code.', const Color(0xFF6366F1)),
              _buildStep(2, 'Enter it below', 'Paste or type the code and tap Connect.', const Color(0xFF8B5CF6)),
              _buildStep(3, 'Start streaming', 'Your logs flow live to your coach\'s dashboard.', AppTheme.neonEmerald, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Connect with Invite Code Box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.06),
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
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
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
                      Text(
                        'Shared by your trainer',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppTheme.primary,
                ),
                decoration: InputDecoration(
                  hintText: 'SAB-XXXXXX',
                  hintStyle: GoogleFonts.spaceMono(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFF6366F1), size: 20),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConnecting
                      ? null
                      : () => _connectWithCode(_inviteCodeController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6366F1).withOpacity(0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Connect to Coach',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_availableCoaches.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Available SabCoaches',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_availableCoaches.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search & Filter
          TextField(
            onChanged: (val) => setState(() => _coachSearchQuery = val),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search coaches by name, specialty...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Strength', 'Fat Loss', 'Nutrition', 'Endurance'].map((tag) {
                final isSel = _selectedCoachSpecialty == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tag, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : const Color(0xFF64748B))),
                    selected: isSel,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSel ? const Color(0xFF6366F1) : Colors.grey.shade300),
                    onSelected: (_) => setState(() => _selectedCoachSpecialty = tag),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          ..._availableCoaches.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final spec = (c['specialty'] ?? c['title'] ?? '').toString().toLowerCase();
            final q = _coachSearchQuery.toLowerCase();
            final matchesQuery = q.isEmpty || name.contains(q) || spec.contains(q);
            final matchesSpec = _selectedCoachSpecialty == 'All' || spec.contains(_selectedCoachSpecialty.toLowerCase());
            return matchesQuery && matchesSpec;
          }).map((c) => _buildAvailableCoachCard(Map<String, dynamic>.from(c as Map))),
        ],
      ],
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String title, String desc, Color color, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
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

// Helper model for macro goal display
class _MacroGoal {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MacroGoal(this.label, this.value, this.color, this.icon);
}
