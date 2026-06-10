import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  int _selectedSegment = 0; // 0 = Terms of Service, 1 = Privacy Policy

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Legal & Info',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Segment Switcher
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSegmentButton(0, 'Terms of Service'),
                  _buildSegmentButton(1, 'Privacy Policy'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.cardRadius,
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: AppTheme.cardRadius,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _selectedSegment == 0
                        ? _buildTermsContent()
                        : _buildPrivacyContent(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.black45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Last Updated: June 2026'),
        const SizedBox(height: 16),
        _buildParagraph(
          'Welcome to SABTRACK AI. Please read these Terms of Service ("Terms") carefully before using our mobile application and related API services.',
        ),
        _buildParagraph(
          'By accessing or using SABTRACK AI, you agree to be bound by these Terms. If you do not agree to all of the terms and conditions, you are prohibited from using the application.',
        ),
        const SizedBox(height: 16),
        _buildSubHeader('1. Use of AI Services'),
        _buildParagraph(
          'SABTRACK AI provides nutrition estimates using artificial intelligence systems. These estimates are generated based on photo uploads and text inputs. You acknowledge that AI estimations are predictions and may contain inaccuracies. They should not replace consulting a certified dietitian or healthcare professional.',
        ),
        const SizedBox(height: 16),
        _buildSubHeader('2. User Accounts'),
        _buildParagraph(
          'To save your logs and use interactive community features, you must create an account. You are responsible for safeguarding your login credentials and for any activity under your account. You agree to provide accurate, complete, and updated information.',
        ),
        const SizedBox(height: 16),
        _buildSubHeader('3. User Conduct'),
        _buildParagraph(
          'You agree not to upload harmful code, disrupt servers, bypass RLS security policies, or upload inappropriate images (non-food photos designed to break analysis frameworks) to the platform.',
        ),
        const SizedBox(height: 16),
        _buildSubHeader('4. Intellectual Property'),
        _buildParagraph(
          'SABTRACK AI and its original content, features, code, and design are owned by the developers and protected by international copyright, trademark, and other proprietary rights laws.',
        ),
        const SizedBox(height: 16),
        _buildSubHeader('5. Limitation of Liability'),
        _buildParagraph(
          'In no event shall SABTRACK AI or its creators be liable for any medical issues, dietary errors, health complications, or computational service downtime resulting from your use of the application.',
        ),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Last Updated: June 2026'),
        const SizedBox(height: 16),
        _buildParagraph(
          'We value your privacy and are committed to protecting your personal data. This Privacy Policy details how we collect, use, and secure your information.',
        ),
        const SizedBox(height: 20),
        _buildSubHeader('Information We Collect'),
        _buildBulletPoint('Account Data: Email and password credentials securely stored via Supabase Authentication.'),
        _buildBulletPoint('Nutritional Logs: Details of meals tracked, portion sizes, calorie counts, and macro profiles.'),
        _buildBulletPoint('Fasting & Weight History: Progress data, fasting timers, and weight logs uploaded to monitor personal trends.'),
        _buildBulletPoint('Uploaded Images: Food pictures sent to the Google Gemini API for macro estimation (we do not store or sell your photos).'),
        const SizedBox(height: 20),
        _buildSubHeader('How We Use Your Data'),
        _buildParagraph(
          'Your data is exclusively used to provide personal fitness analytics, update progress charts, synchronize dashboard records across devices, and offer community groups feature functionality.',
        ),
        const SizedBox(height: 20),
        _buildSubHeader('Third-Party Integrations'),
        _buildParagraph(
          'SABTRACK AI securely coordinates with Supabase for data hosting and authentication, and sends food media/text to the Google Gemini AI backend to extract macronutrient variables. We do not distribute database records to any third-party marketing services.',
        ),
        const SizedBox(height: 20),
        _buildSubHeader('Your Rights'),
        _buildParagraph(
          'You maintain full ownership of your data. You can request to delete your account and wipe all linked database tables (meals, fasting records, user stats) at any time by contacting support or from your profile settings.',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppTheme.accent,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.black54,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
