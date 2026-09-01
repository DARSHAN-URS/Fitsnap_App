import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../screens/subscription_screen.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final int durationMonths;
  final int durationDays;
  final int priceInr;
  final int? basePriceInr;
  final int? discountPercent;
  final int perMonthPrice;
  final String description;
  final List<String> features;
  final String? badge;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.durationMonths,
    required this.durationDays,
    required this.priceInr,
    this.basePriceInr,
    this.discountPercent,
    required this.perMonthPrice,
    this.description = '',
    this.features = const [],
    this.badge,
    this.isPopular = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      durationMonths: json['duration_months'] ?? 1,
      durationDays: json['duration_days'] ?? 30,
      priceInr: json['price_inr'] ?? 0,
      basePriceInr: json['base_price_inr'],
      discountPercent: json['discount_percent'],
      perMonthPrice: json['per_month_price'] ?? 0,
      description: json['description'] ?? '',
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      badge: json['badge'],
      isPopular: json['is_popular'] ?? false,
    );
  }
}

class SubscriptionState {
  final bool isPro;
  final bool isTrialActive;
  final int trialDaysRemaining;
  final DateTime? trialEndsAt;
  final String subscriptionTier; // 'pro', 'trial', 'free'
  final String? planId;
  final String? planName;
  final DateTime? expiresAt;
  final int daysRemaining;
  final bool isLoading;
  final List<SubscriptionPlan> plans;
  final String? razorpayKeyId;
  final String? errorMessage;

  SubscriptionState({
    this.isPro = false,
    this.isTrialActive = true,
    this.trialDaysRemaining = 7,
    this.trialEndsAt,
    this.subscriptionTier = 'trial',
    this.planId,
    this.planName,
    this.expiresAt,
    this.daysRemaining = 0,
    this.isLoading = false,
    this.plans = const [],
    this.razorpayKeyId,
    this.errorMessage,
  });

  /// Returns true if user has active Pro subscription or is in their 7-day free trial
  bool get canAccessPremium => isPro || isTrialActive;

  SubscriptionState copyWith({
    bool? isPro,
    bool? isTrialActive,
    int? trialDaysRemaining,
    DateTime? trialEndsAt,
    String? subscriptionTier,
    String? planId,
    String? planName,
    DateTime? expiresAt,
    int? daysRemaining,
    bool? isLoading,
    List<SubscriptionPlan>? plans,
    String? razorpayKeyId,
    String? errorMessage,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      expiresAt: expiresAt ?? this.expiresAt,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      errorMessage: errorMessage,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(SubscriptionState()) {
    _init();
  }

  Future<void> _init() async {
    await loadLocalSubscription();
    await fetchPlans();
    await fetchRemoteStatus();
  }

  Future<void> loadLocalSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPro = prefs.getBool('is_pro_member') ?? false;
      final planId = prefs.getString('pro_plan_id');
      final planName = prefs.getString('pro_plan_name');
      final expiresStr = prefs.getString('pro_expires_at');
      DateTime? expiresAt;
      int days = 0;

      final now = DateTime.now();

      // Check paid pro expiration
      if (expiresStr != null) {
        expiresAt = DateTime.tryParse(expiresStr);
        if (expiresAt != null && expiresAt.isAfter(now)) {
          days = expiresAt.difference(now).inDays;
        }
      }

      // Check 7-day free trial
      String? firstLaunch = prefs.getString('first_app_launch_date');
      if (firstLaunch == null) {
        firstLaunch = now.toIso8601String();
        await prefs.setString('first_app_launch_date', firstLaunch);
      }

      final firstLaunchDate = DateTime.tryParse(firstLaunch) ?? now;
      final trialEndsAt = firstLaunchDate.add(const Duration(days: 7));
      final bool isTrialActive = now.isBefore(trialEndsAt);
      final int trialDaysRemaining = isTrialActive
          ? (trialEndsAt.difference(now).inDays + 1).clamp(1, 7)
          : 0;

      final String tier = isPro ? 'pro' : (isTrialActive ? 'trial' : 'free');

      state = state.copyWith(
        isPro: isPro && (expiresAt == null || expiresAt.isAfter(now)),
        isTrialActive: isTrialActive,
        trialDaysRemaining: trialDaysRemaining,
        trialEndsAt: trialEndsAt,
        subscriptionTier: tier,
        planId: planId,
        planName: isPro ? planName : (isTrialActive ? '7-Day Free Trial' : 'Free Plan'),
        expiresAt: expiresAt,
        daysRemaining: days,
      );
    } catch (_) {}
  }

  Future<void> fetchPlans() async {
    try {
      final res = await ApiService.getPaymentPlans();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final List<dynamic> rawPlans = data['plans'] ?? [];
        final parsed = rawPlans.map((p) => SubscriptionPlan.fromJson(p)).toList();
        final keyId = data['razorpay_key_id'] as String?;

        state = state.copyWith(
          plans: parsed,
          razorpayKeyId: keyId,
        );
      } else {
        _setFallbackPlans();
      }
    } catch (_) {
      _setFallbackPlans();
    }
  }

  void _setFallbackPlans() {
    state = state.copyWith(
      plans: [
        SubscriptionPlan(
          id: 'monthly',
          name: 'Monthly Pro',
          durationMonths: 1,
          durationDays: 30,
          priceInr: 299,
          basePriceInr: 299,
          discountPercent: 0,
          perMonthPrice: 299,
          description: 'Flexible monthly billing with full access to all features',
          features: [
            'Unlimited AI Food & Nutrition Vision Logging',
            'High-Resolution PDF Export Studio',
            'Complete Health & Fasting Analytics',
            'Custom Macro & Calorie Targets',
            'Priority Customer Support',
          ],
        ),
        SubscriptionPlan(
          id: 'half_yearly',
          name: '6 Months Pro',
          durationMonths: 6,
          durationDays: 180,
          priceInr: 1499,
          basePriceInr: 1794,
          discountPercent: 16,
          perMonthPrice: 249,
          description: 'Commit to half-year fitness transformation',
          badge: 'POPULAR',
          features: [
            'All Monthly Pro Features Included',
            'Save 16% compared to monthly plan',
            'Continuous Progress Tracking & Trends',
            'Early Access to New AI Features',
            'Priority Support & Cloud Backups',
          ],
        ),
        SubscriptionPlan(
          id: 'yearly',
          name: 'Annual Pro Plan',
          durationMonths: 12,
          durationDays: 365,
          priceInr: 2799,
          basePriceInr: 3588,
          discountPercent: 22,
          perMonthPrice: 233,
          isPopular: true,
          badge: 'BEST VALUE',
          features: [
            'All Pro Features Unlocked for a Full Year',
            'Massive 22% Discount (Save ₹789)',
            'Only ₹233/month equivalent',
            'Unlimited Multi-Dish AI Vision Scans',
            'VIP Priority Customer Support',
            'All Future Pro Upgrades Included',
          ],
        ),
      ],
    );
  }

  Future<void> fetchRemoteStatus() async {
    if (!ApiService.isAuthenticated) return;
    try {
      final res = await ApiService.getSubscriptionStatus();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final isPro = data['is_pro'] ?? false;
        final isTrial = data['is_trial_active'] ?? false;
        final trialDays = data['trial_days_remaining'] ?? 0;
        final tier = data['subscription_tier'] ?? (isPro ? 'pro' : (isTrial ? 'trial' : 'free'));
        final planId = data['plan_id'];
        final planName = data['plan_name'];
        final expiresStr = data['expires_at'];
        final days = data['days_remaining'] ?? 0;

        DateTime? expiresAt;
        if (expiresStr != null) {
          expiresAt = DateTime.tryParse(expiresStr);
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_pro_member', isPro);
        if (planId != null) await prefs.setString('pro_plan_id', planId);
        if (planName != null) await prefs.setString('pro_plan_name', planName);
        if (expiresStr != null) await prefs.setString('pro_expires_at', expiresStr);

        state = state.copyWith(
          isPro: isPro,
          isTrialActive: isTrial,
          trialDaysRemaining: trialDays,
          subscriptionTier: tier,
          planId: planId,
          planName: planName,
          expiresAt: expiresAt,
          daysRemaining: days,
        );
      }
    } catch (_) {}
  }

  Future<void> setProActivated({
    required String planId,
    required String planName,
    required String expiresAtIso,
  }) async {
    final expiresAt = DateTime.tryParse(expiresAtIso) ?? DateTime.now().add(const Duration(days: 30));
    final days = expiresAt.difference(DateTime.now()).inDays;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_member', true);
    await prefs.setString('pro_plan_id', planId);
    await prefs.setString('pro_plan_name', planName);
    await prefs.setString('pro_expires_at', expiresAtIso);

    state = state.copyWith(
      isPro: true,
      isTrialActive: false,
      subscriptionTier: 'pro',
      planId: planId,
      planName: planName,
      expiresAt: expiresAt,
      daysRemaining: days,
    );
  }

  Future<Map<String, dynamic>> applyPromoCode(String promoCode) async {
    final cleanCode = promoCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'success': false, 'error': 'Please enter a promo code'};
    }

    if (cleanCode == 'VIGATRON100') {
      final now = DateTime.now();
      final oneYearLater = now.add(const Duration(days: 365));
      final expiresIso = oneYearLater.toIso8601String();

      // Local activation
      await setProActivated(
        planId: 'yearly',
        planName: 'VIP Pro (Promo VIGATRON100)',
        expiresAtIso: expiresIso,
      );

      // Remote backend sync
      if (ApiService.isAuthenticated) {
        try {
          await ApiService.applyPromoCode(cleanCode);
        } catch (_) {}
      }

      return {
        'success': true,
        'message': '🎉 Code VIGATRON100 Applied! 100% OFF — All Pro features are now completely free!',
      };
    }

    // Try backend for other codes
    if (ApiService.isAuthenticated) {
      final res = await ApiService.applyPromoCode(cleanCode);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final expiresIso = data['expires_at'] ?? DateTime.now().add(const Duration(days: 365)).toIso8601String();
        await setProActivated(
          planId: data['plan_id'] ?? 'yearly',
          planName: data['plan_name'] ?? 'VIP Pro',
          expiresAtIso: expiresIso,
        );
        return {
          'success': true,
          'message': data['message'] ?? 'Promo code applied successfully!',
        };
      } else {
        return {
          'success': false,
          'error': res['error'] ?? 'Invalid promo code. Please check and try again.',
        };
      }
    }

    return {
      'success': false,
      'error': 'Invalid promo code. Please check and try again.',
    };
  }

  /// Gatekeeper check: returns true if allowed; if trial expired & free, shows premium modal & returns false
  bool guardPremiumFeature(BuildContext context, {required String featureName}) {
    if (state.canAccessPremium) {
      return true;
    }
    showPremiumGateModal(context, featureName: featureName);
    return false;
  }
}

/// Global modal sheet displayed when user tries to log / export after 7-day trial ends
void showPremiumGateModal(BuildContext context, {required String featureName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Crown Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),

          Text(
            '7-Day Free Trial Ended',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Your 7-day all-access trial has completed. To save and log $featureName, unlock unlimited access with SABTRACK PRO.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Free note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_walk_rounded, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Daily step tracking remains 100% free',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Upgrade Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Plans & Promo Codes',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  );
                },
                child: Text(
                  '🎟️ Have a Promo Code?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF38BDF8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: Color(0xFF475569))),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Maybe Later',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
