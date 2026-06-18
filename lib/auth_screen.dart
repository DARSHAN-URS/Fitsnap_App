import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'utils/preferences_helper.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/sabtrack_logo.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  // IMPORTANT: To fix Google Sign In Error (sign_in_failed, code 10):
  // 1. Add these Android SHA-1 keys to your Google Cloud Console / Supabase Google provider settings:
  //    Debug SHA-1: 03:A0:8B:4B:FF:CF:81:E8:E3:7D:2C:C5:21:28:88:DC:65:A3:C8:EB
  //    Release SHA-1: 9C:DB:09:EE:5D:0E:16:37:72:7F:60:1C:BC:28:F5:CE:3F:A0:AE:ED
  // 2. Uncomment serverClientId below and paste your Web Client ID from Google Cloud Console.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '443720579971-1cp910a8alpjr5o4t1gi198kl3g5a0sl.apps.googleusercontent.com',
  );
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    if (!isLogin) {
      if (_confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm your password')),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
    }
    // Use Riverpod auth provider
    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.authenticate(
      email: _emailController.text,
      password: _passwordController.text,
      isLogin: isLogin,
    );
    if (authNotifier.state.success) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authNotifier.state.errorMessage ?? 'Authentication failed'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Could not retrieve Google ID Token.');
      }

      final String displayName = googleUser.displayName ?? '';
      final String? photoUrl = googleUser.photoUrl;
      final String email = googleUser.email;

      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.authenticateWithGoogle(
        idToken,
        displayName: displayName,
        photoUrl: photoUrl,
        email: email,
      );

      if (authNotifier.state.success) {
        if (displayName.isNotEmpty) {
          await PreferencesHelper.saveString('profile_name', displayName);
        }
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await PreferencesHelper.saveString('profile_pic_url', photoUrl);
        }

        // Reload profile in provider to reflect Google details immediately
        ref.read(profileProvider.notifier).loadProfile();

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authNotifier.state.errorMessage ?? 'Google Authentication failed'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Google Sign In Error: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMeshBackground(),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 2),
                          
                          // Custom Logo
                          Center(
                            child: _buildPremiumLogo(),
                          ),
                          const SizedBox(height: 32),
                          
                          // Title & Subtitle
                          Text(
                            isLogin ? 'Welcome Back' : 'Create Account',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLogin ? 'Sign in to continue your fitness journey' : 'Start your AI-powered fitness journey today',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 44),

                          // Inputs
                          _buildInput('Email address', Icons.mail_outline, _emailController),
                          const SizedBox(height: 18),
                          _buildInput(
                            'Password',
                            Icons.lock_outline_rounded,
                            _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          if (!isLogin) ...[
                            const SizedBox(height: 18),
                            _buildInput(
                              'Confirm Password',
                              Icons.lock_outline_rounded,
                              _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),

                          // Auth Button
                          Container(
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: ref.watch(authProvider).isLoading ? null : _handleAuth,
                                  child: Center(
                                    child: ref.watch(authProvider).isLoading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            isLogin ? 'Sign In' : 'Sign Up',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                  ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 18),

                          // "Or continue with" Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: const Color(0xFF0F172A).withOpacity(0.12), thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'Or continue with',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: const Color(0xFF0F172A).withOpacity(0.12), thickness: 1)),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Google Sign-In Button
                          Container(
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: ref.watch(authProvider).isLoading ? null : _handleGoogleSignIn,
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          'https://developers.google.com/static/identity/images/g-logo.png',
                                          height: 22,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.g_mobiledata, color: AppTheme.accent, size: 28);
                                          },
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Sign in with Google',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
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



                          const Spacer(flex: 3),

                          // Toggle Login/Signup
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin ? "Don't have an account? " : "Already have an account? ",
                                style: GoogleFonts.inter(color: const Color(0xFF475569)),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    _controller.forward(from: 0);
                                  });
                                },
                                child: Text(
                                  isLogin ? 'Sign Up' : 'Sign In',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        // Premium Light Background Base
        Container(color: const Color(0xFFF8FAFC)),
        
        // Blur Bubble 1 (Top Left) - Soft Teal
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.12),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        
        // Blur Bubble 2 (Middle Right) - Soft Light Blue/Cyan
        Positioned(
          top: 220,
          right: -120,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06B6D4).withOpacity(0.08),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        // Blur Bubble 3 (Bottom Left) - Soft Indigo
        Positioned(
          bottom: -120,
          left: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.08),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumLogo() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: SabtrackLogo(size: 48, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildInput(String hint, IconData icon, TextEditingController controller, {bool obscureText = false, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: 15),
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ),
    );
  }
}
