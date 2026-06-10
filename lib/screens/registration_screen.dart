import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String gender;
  final int age;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final String goal;
  final List<String> allergies;

  const RegistrationScreen({
    super.key,
    required this.gender,
    required this.age,
    required this.height,
    required this.heightUnit,
    required this.weight,
    required this.weightUnit,
    required this.goal,
    required this.allergies,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegistration() async {
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
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

    setState(() => _isLoading = true);

    // If they typed a username without @, format as email for backend auth compatibility
    final email = username.contains('@') ? username : '$username@fitflow.ai';

    // 1. Sign up on the backend
    final authResult = await ApiService.signup(email, password);

    if (authResult['success']) {
      final fullName = '$firstName $lastName'.trim();
      final displayName = fullName.isEmpty ? username : fullName;

      // 2. Synchronize collected onboarding metrics to the user profile table in backend database
      // If height/weight are in ft/lbs, we'll convert to cm/kg before database upload for standard representation
      double heightCm = widget.height;
      if (widget.heightUnit == 'ft') {
        heightCm = widget.height * 30.48;
      }
      double weightKg = widget.weight;
      if (widget.weightUnit == 'lbs') {
        weightKg = widget.weight / 2.20462;
      }

      await ApiService.updateProfile(
        name: displayName,
        age: widget.age,
        weight: weightKg,
        height: heightCm,
        goals: widget.goal,
      );

      // 3. Cache profile details in local SharedPreferences for fast, offline startup references
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', displayName);
      await prefs.setString('profile_age', widget.age.toString());
      await prefs.setString('profile_gender', widget.gender);
      await prefs.setString('profile_height', heightCm.toStringAsFixed(1));
      await prefs.setString('profile_weight', weightKg.toStringAsFixed(1));
      await prefs.setString('profile_goals', widget.goal);
      await prefs.setStringList('profile_allergies', widget.allergies);

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account registered successfully! Welcome to FitFlow.'),
          backgroundColor: AppTheme.neonEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      // 4. Navigate directly into the main Dashboard Screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authResult['error'] ?? 'Registration failed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.fitness_center_rounded, color: AppTheme.accent, size: 48);
                            },
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
                        Container(
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _isLoading ? null : _handleRegistration,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Text(
                                        'Finish',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
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
