import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'onboarding_screen.dart';
import '../providers/auth_provider.dart';
import '../utils/preferences_helper.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_overlay.dart';
import '../theme/sabtrack_logo.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegistrationSuccess() async {
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isEmpty ? username : fullName;

    // Cache profile name securely and set onboarding_completed to false
    await PreferencesHelper.saveString('profile_name', displayName);
    await PreferencesHelper.saveBool('onboarding_completed', false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Account registered successfully! Let's complete your profile setup."),
        backgroundColor: AppTheme.neonEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    // Navigate into the Onboarding Screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  void _handleRegistration() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and Password are required.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    // If they typed a username without @, format as email for backend auth compatibility
    final email = username.contains('@') ? username : '$username@sabtrack.ai';
    ref.read(authProvider.notifier).authenticate(email: email, password: password, isLogin: false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.success && !next.isLoading) {
        _onRegistrationSuccess();
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
                        const Spacer(),
                        _buildProgressBar(),
                        const Spacer(flex: 2), // visually balances the back arrow
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
  
                  // Form Content
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
                          const SizedBox(height: 24),
                          Text(
                            'Registration',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the fields with information about yourself',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 28),
  
                          // Username/Email Field
                          Text(
                            'Username or Email',
                            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 8),
                          _buildInputCard(
                            controller: _usernameController,
                            hintText: '@ Username',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 16),
  
                          // First & Last Name
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'First name',
                                      style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInputCard(
                                      controller: _firstNameController,
                                      hintText: 'First name',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last name',
                                      style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInputCard(
                                      controller: _lastNameController,
                                      hintText: 'Last name',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
  
                          // Set Password Field
                          Text(
                            'Set password',
                            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 8),
                          _buildInputCard(
                            controller: _passwordController,
                            hintText: 'Set password',
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
                          const SizedBox(height: 16),
  
                          // Rewrite Password Field
                          Text(
                            'Rewrite password',
                            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 8),
                          _buildInputCard(
                            controller: _confirmPasswordController,
                            hintText: 'Rewrite password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white30,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          const SizedBox(height: 36),
  
                          // Finish CTA Button
                          CustomButton(
                            text: 'Finish',
                            isLoading: isLoading,
                            onPressed: _handleRegistration,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Sign In",
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
