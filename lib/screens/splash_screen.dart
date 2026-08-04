import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 1. Logo scales up from 0 → 1
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // 2. Glow pulses once
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // 3. Whole screen fades out
  late AnimationController _exitController;
  late Animation<double> _exitAnimation;

  @override
  void initState() {
    super.initState();

    // ── Scale in ──────────────────────────────────────────
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // ── Glow pulse ────────────────────────────────────────
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ── Fade-out exit ─────────────────────────────────────
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1 — Scale in logo
    await Future.delayed(const Duration(milliseconds: 150));
    await _scaleController.forward();

    // Step 2 — Glow pulse
    await _glowController.forward();
    await _glowController.reverse();

    // Step 3 — Hold for readability
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 4 — Fade out and navigate
    await _exitController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _exitAnimation.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4FC3F7), // light sky blue
                Color(0xFF81C784), // light green
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated logo ─────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
                  builder: (context, child) {
                    final glowOpacity = _glowAnimation.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        if (glowOpacity > 0)
                          Opacity(
                            opacity: glowOpacity * 0.35,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 60 * glowOpacity,
                                    spreadRadius: 20 * glowOpacity,
                                  ),
                                ],
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        // Logo
                        Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      ],
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── App name ──────────────────────────────────────
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Text(
                    'SABTRACK',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── Tagline ───────────────────────────────────────
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Text(
                    'AI-Powered Health Tracking',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
