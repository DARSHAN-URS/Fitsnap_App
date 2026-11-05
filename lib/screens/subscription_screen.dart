import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../services/api_service.dart';
import '../utils/preferences_helper.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  String _selectedPlanId = 'yearly'; // default to best value
  bool _isProcessing = false;
  bool _isApplyingPromo = false;
  String? _appliedPromoCode;
  String? _userEmail;
  final TextEditingController _promoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _promoFocusNode = FocusNode();

  // Apple In-App Purchase variables
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscriptionStream;
  final Map<String, ProductDetails> _appleProducts = {};

  static const String _appleMonthlyId = 'sabtrack_pro_monthly';
  static const String _appleHalfYearlyId = 'sabtrack_pro_half_yearly';
  static const String _appleYearlyId = 'sabtrack_pro_yearly';
  static const Set<String> _appleProductIds = {
    _appleMonthlyId,
    _appleHalfYearlyId,
    _appleYearlyId,
  };

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) {
      _initStoreKit();
    } else {
      // Initialize Razorpay SDK instance on Android
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }

    _promoFocusNode.addListener(() {
      if (_promoFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    _loadUserInfo();
  }

  Future<void> _initStoreKit() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscriptionStream = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscriptionStream?.cancel(),
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('StoreKit error: $error'), backgroundColor: Colors.redAccent),
          );
        }
      },
    );

    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) return;

      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_appleProductIds);
      if (mounted) {
        setState(() {
          for (final ProductDetails product in response.productDetails) {
            _appleProducts[product.id] = product;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    final email = await PreferencesHelper.readString('user_email');
    if (mounted) {
      setState(() {
        _userEmail = email;
      });
    }
  }

  @override
  void dispose() {
    _subscriptionStream?.cancel();
    if (!Platform.isIOS) {
      _razorpay.clear();
    }
    _promoController.dispose();
    _scrollController.dispose();
    _promoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a promo code')),
      );
      return;
    }

    setState(() => _isApplyingPromo = true);
    FocusScope.of(context).unfocus();

    try {
      final res = await ref.read(subscriptionProvider.notifier).applyPromoCode(code);
      if (!mounted) return;
      setState(() => _isApplyingPromo = false);

      if (res['success'] == true) {
        setState(() {
          _appliedPromoCode = code.toUpperCase();
        });
        _showCelebrationDialog('VIP Pro 100% Free Plan', 'PROMO_${code.toUpperCase()}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Invalid promo code'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplyingPromo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying code: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);

    try {
      final verifyRes = await ApiService.verifyPayment(
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
        planId: _selectedPlanId,
      );

      if (verifyRes['success'] == true) {
        final data = verifyRes['data'] ?? {};
        final planName = data['plan_name'] ?? 'Pro Plan';
        final expiresAt = data['expires_at'] ?? DateTime.now().add(const Duration(days: 365)).toIso8601String();

        // Update Riverpod subscription provider
        await ref.read(subscriptionProvider.notifier).setProActivated(
          planId: _selectedPlanId,
          planName: planName,
          expiresAtIso: expiresAt,
        );

        if (mounted) {
          setState(() => _isProcessing = false);
          _showCelebrationDialog(planName, response.paymentId ?? '');
        }
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verifyRes['error'] ?? 'Payment verification failed. Please contact support.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message ?? 'Cancelled by user'}'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirected to external wallet: ${response.walletName}'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isProcessing = true);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(purchaseDetails.error?.message ?? 'Purchase failed'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (mounted) setState(() => _isProcessing = false);
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        try {
          final planId = purchaseDetails.productID == _appleMonthlyId
              ? 'monthly'
              : (purchaseDetails.productID == _appleHalfYearlyId ? 'half_yearly' : 'yearly');
          final planName = purchaseDetails.productID == _appleMonthlyId
              ? 'Monthly Pro'
              : (purchaseDetails.productID == _appleHalfYearlyId ? '6 Months Pro' : 'Annual Pro Plan');

          final durationDays = planId == 'monthly' ? 30 : (planId == 'half_yearly' ? 180 : 365);
          final expiresAt = DateTime.now().add(Duration(days: durationDays)).toIso8601String();

          // 1. Activate in local Riverpod state
          await ref.read(subscriptionProvider.notifier).setProActivated(
            planId: planId,
            planName: planName,
            expiresAtIso: expiresAt,
          );

          // 2. Call backend verification
          if (ApiService.isAuthenticated) {
            await ApiService.verifyApplePayment(
              productId: purchaseDetails.productID,
              transactionId: purchaseDetails.purchaseID ?? 'apple_${DateTime.now().millisecondsSinceEpoch}',
            );
          }

          if (mounted) {
            setState(() => _isProcessing = false);
            _showCelebrationDialog(planName, purchaseDetails.purchaseID ?? 'StoreKit');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error validating purchase: $e'), backgroundColor: Colors.redAccent),
            );
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isProcessing = true);
    if (Platform.isIOS) {
      try {
        await _inAppPurchase.restorePurchases();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restoring previous purchases...')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      await ref.read(subscriptionProvider.notifier).fetchRemoteStatus();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription status refreshed.')),
        );
      }
    }
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _startCheckout(SubscriptionPlan plan, String? razorpayKeyId) async {
    setState(() => _isProcessing = true);

    if (Platform.isIOS) {
      try {
        String targetProductId = _appleYearlyId;
        if (plan.id == 'monthly') {
          targetProductId = _appleMonthlyId;
        } else if (plan.id == 'half_yearly') {
          targetProductId = _appleHalfYearlyId;
        }

        ProductDetails? product = _appleProducts[targetProductId];
        if (product == null) {
          final response = await _inAppPurchase.queryProductDetails(_appleProductIds);
          for (final p in response.productDetails) {
            _appleProducts[p.id] = p;
          }
          product = _appleProducts[targetProductId];
        }

        if (product == null) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Product ($targetProductId) not found in App Store. Please ensure In-App Purchases are configured in App Store Connect.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initiating Apple purchase: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      return;
    }

    try {
      final orderRes = await ApiService.createPaymentOrder(plan.id);

      if (orderRes['success'] != true || orderRes['data'] == null) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(orderRes['error'] ?? 'Could not initialize order. Please check connection.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final orderData = orderRes['data'];
      final String orderId = orderData['order_id'];
      final int amountPaise = orderData['amount'];
      final String keyId = orderData['key_id'] ?? razorpayKeyId ?? 'rzp_test_mock';

      final Map<String, dynamic> options = {
        'key': keyId,
        'amount': amountPaise,
        'name': 'SABTRACK AI',
        'description': '${plan.name} Membership',
        'order_id': orderId,
        'prefill': {
          'contact': '',
          'email': _userEmail ?? 'member@sabtrack.in',
        },
        'theme': {
          'color': '#007AFF',
        },
        'modal': {
          'confirm_close': true,
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        }
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating payment: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCelebrationDialog(String planName, String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to PRO!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your $planName is now active. All premium features, AI Vision, and export studios are permanently unlocked.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  'Payment Ref: ${paymentId.isNotEmpty ? paymentId : "Verified"}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(); // Back to main screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Let\'s Get Started',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final plans = subState.plans;
    final activePlan = plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => plans.isNotEmpty ? plans.first : _createFallbackYearlyPlan(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Restore',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Crown Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),

                  // Header Title
                  Text(
                    'Upgrade to SABTRACK PRO',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supercharge your health & nutrition transformation with intelligent AI coaching.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feature Checklist
                  _buildFeatureList(),
                  const SizedBox(height: 24),

                  // Plan Selection Cards
                  Text(
                    'CHOOSE YOUR PLAN',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (plans.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    ...plans.map((plan) => _buildPlanCard(plan)),

                  const SizedBox(height: 16),

                  // Promo Code Input Box
                  _buildPromoCodeSection(),

                  const SizedBox(height: 8),

                  // Checkout CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _startCheckout(activePlan, subState.razorpayKeyId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: AppTheme.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue with ${activePlan.name} • ${_getDisplayPrice(activePlan)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Trust & Security Notice & Subscription Disclosures (Apple Guideline 3.1.2)
                  if (Platform.isIOS)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(
                              'Secured via Apple App Store',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period in your Apple ID Account Settings.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _openLegalUrl('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                              child: Text(
                                'Terms of Use (EULA)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text('•', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => _openLegalUrl('https://sabtrack.in/privacy'),
                              child: Text(
                                'Privacy Policy',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Secured by Razorpay • UPI, Cards & Netbanking',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _appliedPromoCode != null ? const Color(0xFF10B981) : const Color(0xFF1E293B),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text(
                'Have a Promo Code?',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_appliedPromoCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Text(
                    '100% OFF APPLIED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF34D399),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _promoController,
                    focusNode: _promoFocusNode,
                    textCapitalization: TextCapitalization.characters,
                    scrollPadding: const EdgeInsets.only(bottom: 80),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isApplyingPromo ? null : _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _isApplyingPromo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Apply',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {'icon': Icons.camera_alt_rounded, 'title': 'Unlimited AI Vision Food Logging', 'desc': 'Instant multi-dish macro breakdown with photo'},
      {'icon': Icons.picture_as_pdf_rounded, 'title': 'Export Studio PDF & Visual Cards', 'desc': 'Generate branded doctor & trainer summaries'},
      {'icon': Icons.insights_rounded, 'title': 'Advanced Fasting & Health Analytics', 'desc': 'Detailed trends, streaks, and metabolism curves'},
      {'icon': Icons.support_agent_rounded, 'title': 'Priority VIP 24/7 Coaching Support', 'desc': 'Direct assistance from nutrition experts'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f['icon'] as IconData, color: const Color(0xFF38BDF8), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['title'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlanId == plan.id;
    final isYearly = plan.id == 'yearly';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A2642) : const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFF1E293B),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                // Radio Check indicator
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : const Color(0xFF475569),
                      width: 2,
                    ),
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),

                // Plan details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (plan.discountPercent != null && plan.discountPercent! > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${plan.discountPercent}% OFF',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${plan.perMonthPrice} / month',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pricing
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getDisplayPrice(plan),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (plan.basePriceInr != null && plan.basePriceInr! > plan.priceInr)
                      Text(
                        '₹${plan.basePriceInr}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Badge for Popular / Best Value
            if (plan.badge != null)
              Positioned(
                top: -26,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isYearly
                        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                        : const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isYearly ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    plan.badge!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SubscriptionPlan _createFallbackYearlyPlan() {
    return SubscriptionPlan(
      id: 'yearly',
      name: 'Annual Pro Plan',
      durationMonths: 12,
      durationDays: 365,
      priceInr: 2799,
      basePriceInr: 3588,
      discountPercent: 22,
      perMonthPrice: 233,
      description: 'Ultimate year-long health & fitness transformation',
      features: [],
      badge: 'BEST VALUE',
      isPopular: true,
    );
  }

  String _getDisplayPrice(SubscriptionPlan plan) {
    if (Platform.isIOS) {
      String targetProductId = _appleYearlyId;
      if (plan.id == 'monthly') {
        targetProductId = _appleMonthlyId;
      } else if (plan.id == 'half_yearly') {
        targetProductId = _appleHalfYearlyId;
      }
      final product = _appleProducts[targetProductId];
      if (product != null) return product.price;
    }
    return '₹${plan.priceInr}';
  }
}
