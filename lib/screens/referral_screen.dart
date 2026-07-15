import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';
import '../services/api_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String _referralCode = '';
  int _points = 0;
  List<dynamic> _referredFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    setState(() {
      _isLoading = true;
    });
    final res = await ApiService.getReferralInfo();
    if (res['success'] && res['data'] != null) {
      final data = res['data'];
      setState(() {
        _referralCode = data['code'] ?? '';
        _referredFriends = data['referrals'] ?? [];
        _points = data['points'] ?? 0;
        _isLoading = false;
      });
    } else {
      String? code = await PreferencesHelper.getReferralCode();
      if (code == null || code.isEmpty) {
        code = 'FIT-LOCAL';
      }
      setState(() {
        _referralCode = code!;
        _referredFriends = [];
        _points = 0;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Referral code copied to clipboard!'),
        backgroundColor: AppTheme.neonEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _shareCode() {
    final message = "Join me on SABTRACK AI to level up your fitness journey! Use my referral code: $_referralCode to earn 100 bonus points. Download now!";
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invite Friends',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _loadReferralCode,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, size: 54, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Invite & Get Rewards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Share your invite code with friends. For every friend who registers and joins, you both get 100 bonus reward points!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Your Unique Referral Code',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _referralCode,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Two side-by-side buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareCode,
                            icon: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                            label: Text(
                              'Share Code',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.white),
                            label: Text(
                              'Copy Code',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    
                    // Stats section card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                _referredFriends.length.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Friends Invited',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Column(
                            children: [
                              Text(
                                _points.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rewards Earned',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Referred Friends List
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Referred Friends',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_referredFriends.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No friends referred yet.\nShare your invite code to start earning rewards!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _referredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _referredFriends[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_rounded, color: AppTheme.accent, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend['name'] ?? 'Friend',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        friend['email'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+100 pts',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
