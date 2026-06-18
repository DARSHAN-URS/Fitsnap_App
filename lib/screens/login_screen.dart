import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../dashboard_screen.dart';
import 'registration_screen.dart';
import 'onboarding_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/preferences_helper.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_overlay.dart';
import '../theme/sabtrack_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginSuccess() async {
    final username = _usernameController.text.trim();
    final profileRes = await ApiService.getProfile();
    bool onboardingCompleted = false;

    if (profileRes['success']) {
      final profileData = profileRes['data'];
      
      final String? serverName = profileData['name'];
      final String? serverPic = profileData['profile_picture_url'];
      if (serverName != null && serverName.isNotEmpty && serverName != 'Guest User') {
        await PreferencesHelper.saveString('profile_name', serverName);
      } else if (username.isNotEmpty) {
        await PreferencesHelper.saveString('profile_name', username);
      }
      if (serverPic != null && serverPic.isNotEmpty) {
        await PreferencesHelper.saveString('profile_pic_url', serverPic);
      }

      if (profileData['age'] != null && profileData['weight'] != null && profileData['height'] != null) {
        onboardingCompleted = true;
        await PreferencesHelper.saveString('profile_age', (profileData['age'] ?? 24).toString());
        await PreferencesHelper.saveDouble('profile_height', (profileData['height'] as num?)?.toDouble() ?? 175.0);
        await PreferencesHelper.saveDouble('profile_weight', (profileData['weight'] as num?)?.toDouble() ?? 75.0);
        await PreferencesHelper.saveString('profile_goal', profileData['goals'] ?? 'Build Muscle');
      }
    }

    await PreferencesHelper.saveBool('onboarding_completed', onboardingCompleted);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logged in successfully!'),
        backgroundColor: AppTheme.neonEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (onboardingCompleted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email/username and password.')),
      );
      return;
    }

    final email = username.contains('@') ? username : '$username@sabtrack.ai';
    ref.read(authProvider.notifier).authenticate(email: email, password: password, isLogin: true);
  }

  void _handleGoogleLogin() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '443720579971-1cp910a8alpjr5o4t1gi198kl3g5a0sl.apps.googleusercontent.com',
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Could not retrieve Google ID Token.');
      }

      final String displayName = googleUser.displayName ?? '';
      final String? photoUrl = googleUser.photoUrl;
      final String email = googleUser.email;

      if (displayName.isNotEmpty) {
        await PreferencesHelper.saveString('profile_name', displayName);
      }
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await PreferencesHelper.saveString('profile_pic_url', photoUrl);
      }

      // Reload profile to reflect Google details immediately in state
      ref.read(profileProvider.notifier).loadProfile();

      ref.read(authProvider.notifier).authenticateWithGoogle(
        idToken,
        displayName: displayName,
        photoUrl: photoUrl,
        email: email,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.success && !next.isLoading) {
        _onLoginSuccess();
      } else if (next.errorMessage != null && !next.isLoading && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: Stack(
          children: [
            _buildMeshBackground(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Top Header Row with back arrow button & progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        if (canPop)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        if (canPop) const Spacer(),
                        _buildProgressBar(),
                        if (canPop) const Spacer(flex: 2), // visually balances the back arrow
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
  
                  // Title & Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                              ),
                              child: const Center(
                                child: SabtrackLogo(size: 48, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Log - In',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the fields with your account informations',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 36),
  
                          // Username/Email Field
                          Text(
                            'Username or Email',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInputCard(
                            controller: _usernameController,
                            hintText: '@ Username',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 20),
  
                          // Password Field
                          Text(
                            'Password',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInputCard(
                            controller: _passwordController,
                            hintText: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white30,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 40),
  
                          // Enter CTA Button
                          CustomButton(
                            text: 'Enter',
                            isLoading: isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'Or continue with',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: isLoading ? null : _handleGoogleLogin,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/google_logo.png',
                                        height: 22,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.g_mobiledata, color: Colors.white, size: 28);
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Sign in with Google',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Color(0xFF818cf8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: 100,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 8,
          )
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF030712)),
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
