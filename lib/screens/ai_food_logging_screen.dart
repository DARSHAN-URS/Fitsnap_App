import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import '../services/ai_food_logging_service.dart';
import '../theme/app_theme.dart';
import 'meal_review_screen.dart';

class AiFoodLoggingScreen extends StatefulWidget {
  const AiFoodLoggingScreen({super.key});

  @override
  State<AiFoodLoggingScreen> createState() => _AiFoodLoggingScreenState();
}

class _AiFoodLoggingScreenState extends State<AiFoodLoggingScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  String _statusText = "Preprocessing Image...";
  String? _errorMsg;

  Future<void> _getImage(ImageSource source) async {
    setState(() {
      _errorMsg = null;
    });

    // Just-In-Time Permission Request before accessing camera or gallery
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        _showPermissionDialog('Camera permission is required to take food photos. Please enable it in Settings.');
        return;
      }
      if (status.isDenied) return;
    } else {
      final status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        _showPermissionDialog('Photo gallery permission is required to pick food images. Please enable it in Settings.');
        return;
      }
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85, // Pre-compress on client
      );

      if (pickedFile == null) return;

      setState(() {
        _isAnalyzing = true;
        _statusText = "Compressing Image...";
      });

      // Simple artificial delay for fluid status presentation
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _statusText = "AI Recognizing Food...";
      });

      final res = await AiFoodLoggingService.analyzeMeal(pickedFile.path);

      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _statusText = "Running Nutrition Engine...";
        });
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
        });

        // Navigate to the Review screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MealReviewScreen(
              initialFoods: List<Map<String, dynamic>>.from(res['data']['foods']),
              imagePath: pickedFile.path,
            ),
          ),
        );
      } else {
        setState(() {
          _isAnalyzing = false;
          _errorMsg = res['error'] ?? "Failed to analyze food image. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMsg = "An error occurred: $e";
      });
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF007AFF), size: 24),
            const SizedBox(width: 10),
            Text(
              'Permission Required',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cal AI Inspired Minimal Blue Accent Style
    const Color accentBlue = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Food Logger',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Premium Icon Logo representation
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: accentBlue.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentBlue.withOpacity(0.12), width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: accentBlue,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Instant Cal AI Logging',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Take a picture of your plate. SABTRACK AI detects foods, weight, cooking methods, and compiles exact nutrition automatically.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                
                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                Column(
                  children: [
                    // Camera Trigger
                    GestureDetector(
                      onTap: () => _getImage(ImageSource.camera),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: accentBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentBlue.withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Take a Photo',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Gallery Trigger
                    GestureDetector(
                      onTap: () => _getImage(ImageSource.gallery),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_search_rounded, color: AppTheme.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Upload from Gallery',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // High-Contrast AI Loading Popup Overlay
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Deep Solid Dark Slate Card
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.35),
                          blurRadius: 36,
                          offset: const Offset(0, 12),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dual Ring Glowing Spinner
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(
                              width: 52,
                              height: 52,
                              child: CircularProgressIndicator(
                                color: Color(0xFF38BDF8),
                                strokeWidth: 4.5,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF38BDF8),
                              size: 26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Analyzing Meal...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // High Contrast Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                          ),
                          child: Text(
                            _statusText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF38BDF8), // Electric Cyan - Ultra Clear
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'SABTRACK AI Vision & Nutrition Engine',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
