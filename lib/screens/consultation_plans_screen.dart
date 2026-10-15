import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/preferences_helper.dart';

class ConsultationPlansScreen extends StatefulWidget {
  const ConsultationPlansScreen({super.key});

  @override
  State<ConsultationPlansScreen> createState() => _ConsultationPlansScreenState();
}

class _ConsultationPlansScreenState extends State<ConsultationPlansScreen> {
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'essential',
      'number': '01',
      'name': 'ESSENTIAL',
      'title': '01 — ESSENTIAL',
      'subtitle': 'Fitness & Nutrition',
      'price': '₹3,000/month',
      'billing': 'Billed monthly retainer',
      'badge': 'FOUNDATION',
      'badgeColor': const Color(0xFF6366F1),
      'badgeBg': Color(0xFFEEF2FF),
      'icon': Icons.fitness_center_rounded,
      'bio':
          'Get expert guidance from certified fitness trainers and nutritionists to build sustainable habits and improve your everyday health. Whether your goal is fat loss, muscle gain, better fitness or improved nutrition, your coach creates a practical plan around your lifestyle.',
      'bestFor':
          'Fitness • Weight Management • Strength • Nutrition • Lifestyle Habits',
      'tags': ['Fat Loss', 'Muscle Gain', 'Nutrition', 'Daily Habits'],
    },
    {
      'id': 'elite',
      'number': '02',
      'name': 'ELITE',
      'title': '02 — ELITE',
      'subtitle': 'Specialised Health & Performance',
      'price': '₹6,000/package',
      'billing': 'Complete clinical protocol package',
      'badge': 'MOST POPULAR',
      'badgeColor': const Color(0xFFF59E0B),
      'badgeBg': Color(0xFFFEF3C7),
      'icon': Icons.health_and_safety_rounded,
      'bio':
          'Work with experienced trainers and nutrition specialists who understand complex health and lifestyle needs. Get personalised guidance for areas such as PCOS/PCOD, diabetes, thyroid conditions, hypertension, metabolic health and weight management, with programs designed around your individual needs.',
      'bestFor':
          'PCOS/PCOD • Diabetes • Thyroid • Hypertension • Metabolic Health • Specialised Weight Management',
      'tags': ['PCOS / PCOD', 'Diabetes & Thyroid', 'Hypertension', 'Metabolic Health'],
    },
    {
      'id': 'longevity',
      'number': '03',
      'name': 'LONGEVITY — Biohacking & Wellness',
      'title': '03 — LONGEVITY',
      'subtitle': 'Advanced Wellness & Healthspan',
      'price': 'Premium',
      'billing': 'Multidisciplinary concierge team',
      'badge': 'CONCIERGE & MEDICAL',
      'badgeColor': const Color(0xFF10B981),
      'badgeBg': Color(0xFFECFDF5),
      'icon': Icons.auto_awesome_rounded,
      'bio':
          'A multidisciplinary approach to longevity, performance, recovery and healthy ageing. Work with a team of trainers, doctors and nutrition professionals to optimise sleep, nutrition, fitness, recovery and other evidence-based wellness strategies—built around your goals, lifestyle and long-term health.',
      'bestFor':
          'Longevity • Healthy Ageing • Recovery • Performance • Sleep • Metabolic Optimisation • Advanced Wellness',
      'tags': ['Biohacking', 'Recovery & Sleep', 'Biomarkers', 'Healthy Ageing'],
    },
  ];

  void _showBookingSheet(Map<String, dynamic> plan) {
    final noteController = TextEditingController();
    final List<String> quickGoalChips = [
      'Fat Loss',
      'PCOS / Hormones',
      'Strength & Hypertrophy',
      'Longevity & Sleep',
      'Thyroid Support',
      'Metabolic Health',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      enableDrag: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            return AnimatedPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 30,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Top Header: Icon + Titles + Close Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (plan['badgeColor'] as Color).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                plan['icon'] as IconData,
                                color: plan['badgeColor'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                      letterSpacing: -0.02,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plan['subtitle'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Meta Badges Pill Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: (plan['badgeBg'] as Color),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (plan['badgeColor'] as Color).withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                plan['badge'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: plan['badgeColor'] as Color,
                                  letterSpacing: 0.04,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                plan['price'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // How Specialist Matching Works (Clinical Notice)
                        Container(
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
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEEF2FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Specialist Coach Placement',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Clinical Admin',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Our clinical director evaluates your health profile and pairs you with a verified specialist coach. Once approved, your dedicated coach will appear in your "My Coaches" tab.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Health Goals Label + Optional Chip
                        Row(
                          children: [
                            Text(
                              'Primary Health Goals or Conditions',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Optional',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Quick-Tap Suggestion Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: quickGoalChips.map((chipText) {
                              final isAlreadyAdded = noteController.text.contains(chipText);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6, bottom: 4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setSheetState(() {
                                      if (isAlreadyAdded) {
                                        // Remove chip
                                        String updated = noteController.text
                                            .replaceAll('$chipText, ', '')
                                            .replaceAll(', $chipText', '')
                                            .replaceAll(chipText, '')
                                            .trim();
                                        noteController.text = updated;
                                      } else {
                                        // Append chip
                                        if (noteController.text.trim().isEmpty) {
                                          noteController.text = chipText;
                                        } else {
                                          noteController.text = '${noteController.text.trim()}, $chipText';
                                        }
                                      }
                                      noteController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: noteController.text.length),
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isAlreadyAdded ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isAlreadyAdded ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isAlreadyAdded) ...[
                                          const Icon(Icons.check_rounded, size: 12, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          chipText,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: isAlreadyAdded ? FontWeight.w700 : FontWeight.w500,
                                            color: isAlreadyAdded ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Elevated Text Field
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          minLines: 2,
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, height: 1.4),
                          decoration: InputDecoration(
                            hintText: 'e.g. Weight loss, PCOS management, muscle hypertrophy, thyroid support...',
                            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Submit CTA Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    setSheetState(() => _isSubmitting = true);
                                    Navigator.pop(ctx);
                                    await _executeBooking(plan, noteController.text.trim());
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Confirm & Request Consultation',
                                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 16),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeBooking(Map<String, dynamic> plan, String notes) async {
    setState(() => _isSubmitting = true);

    try {
      final userEmail = await PreferencesHelper.readString('user_email') ?? 'athlete@sabtrack.in';
      final userName = await PreferencesHelper.readString('user_name') ?? 'Athlete';

      final requestPayload = {
        'plan_id': plan['id'],
        'plan_name': plan['name'],
        'plan_price': plan['price'],
        'user_email': userEmail,
        'user_name': userName,
        'notes': notes,
        'requested_at': DateTime.now().toIso8601String(),
        'status': 'pending_admin_placement',
      };

      // Save locally to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_consultation_request', jsonEncode(requestPayload));

      // Attempt backend post if available
      try {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/consultations/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestPayload),
        );
      } catch (err) {
        debugPrint('Consultation endpoint offline, cached locally: $err');
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                'Request Received!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You selected the ${plan['name']} tier (${plan['price']}).',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Our clinical admin team will review your biometrics and place your verified specialist coach. Your assigned coach will appear on your "My Coaches" tab shortly.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.45),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // back to MyCoach tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Got It', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultation Plans',
          style: GoogleFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: -0.02,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Explanation Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              'VERIFIED COACHING NETWORK',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF6366F1),
                                letterSpacing: 0.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Clinical & Performance Matching',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To connect with a dedicated personal coach, select a consultation plan below. Our administration will assign you a specialist according to your individual health goals.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SabTrack plan members can search coaches for an introductory chat. Full dedicated 1:1 coaching requires an active Consultation Plan.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Select Your Consultation Tier',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Plan Cards
            ..._plans.map((p) => _buildPlanCard(p)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final bool isElite = plan['id'] == 'elite';
    final Color accentColor = plan['badgeColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isElite ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isElite ? 1.8 : 1,
        ),
        boxShadow: isElite
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Banner
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: plan['badgeBg'] as Color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        plan['badge'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.04,
                        ),
                      ),
                    ),
                    Text(
                      plan['price'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -0.02,
                  ),
                ),
                Text(
                  plan['subtitle'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),

                // Bio
                Text(
                  'Bio:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan['bio'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 14),

                // Best for
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best for:',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['bestFor'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF475569),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showBookingSheet(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isElite ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
                      foregroundColor: isElite ? const Color(0xFF0F172A) : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          plan['id'] == 'longevity'
                              ? 'Request Longevity Concierge'
                              : 'Select Plan — ${plan['price']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 15),
                      ],
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
}
