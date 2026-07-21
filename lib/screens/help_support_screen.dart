import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedCategory = 'General Inquiry';
  
  final List<String> _categories = [
    'General Inquiry',
    'AI Scanner Help',
    'Account & Syncing',
    'Report a Bug',
    'Feature Request',
  ];

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How does the AI Meal Scanner work?',
      'answer': 'SABTRACK AI uses advanced computer vision models (Google Gemini AI) to identify food items in your pictures and estimate their portion size, volume, and corresponding macronutrients (protein, carbs, fats) and calories.'
    },
    {
      'question': 'How accurate are the calorie estimates?',
      'answer': 'Estimates are highly accurate for standard dishes and whole foods. For custom or complex recipes, we recommend using the "Describe Meal" text entry feature to specify exact ingredients or portion sizes for the best accuracy.'
    },
    {
      'question': 'Can I sync my data across multiple devices?',
      'answer': 'Yes! If you sign up for an account, all of your logged meals, fasting sessions, and weight metrics are safely stored in our Supabase cloud database, meaning they will sync instantly when logging in on any device.'
    },
    {
      'question': 'What is Intermittent Fasting tracking?',
      'answer': 'Our fasting tool allows you to select a protocol (such as 16:8 or 18:6) and track your fasting and eating windows in real-time. It runs in the background and logs your completed fasting sessions in your history.'
    },
    {
      'question': 'How do I change my target weight or calories?',
      'answer': 'Go to your Profile tab, scroll down to "Goals & Tracking", and tap "Edit Nutrition Goals". There you can adjust your daily calorie limit and individual targets for protein, carbs, and fats.'
    }
  ];

  List<Map<String, String>> _filteredFaqs = [];
  final Set<int> _expandedFaqIndices = {};

  @override
  void initState() {
    super.initState();
    _filteredFaqs = List.from(_faqs);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _expandedFaqIndices.clear();
      if (query.isEmpty) {
        _filteredFaqs = List.from(_faqs);
      } else {
        _filteredFaqs = _faqs.where((faq) {
          return faq['question']!.toLowerCase().contains(query) ||
              faq['answer']!.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleFaq(int index) {
    setState(() {
      if (_expandedFaqIndices.contains(index)) {
        _expandedFaqIndices.remove(index);
      } else {
        _expandedFaqIndices.add(index);
      }
    });
  }

  void _submitTicket() async {
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    final category = _selectedCategory;

    if (email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill out all fields.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
    );

    final res = await ApiService.submitSupportTicket(
      email: email,
      category: category,
      message: message,
    );

    if (mounted) {
      Navigator.pop(context); // Pop loading spinner
    }

    if (res['success'] == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.neonEmerald, size: 28),
              const SizedBox(width: 8),
              Text(
                'Ticket Submitted',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          content: Text(
            'Thank you! Your request has been registered. Our support team will get back to you at $email within 24 hours.',
            style: GoogleFonts.inter(color: Colors.black54),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _messageController.clear();
                  _emailController.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Great', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Failed to submit ticket. Please check connection.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
          'Help & Support',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle info
            Text(
              'How can we help you today?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find answers in our FAQ or submit a ticket to our support team.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Search FAQs
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primary),
                decoration: InputDecoration(
                  hintText: 'Search FAQ articles...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.black38, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // FAQ Title
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // FAQ List Accordion
            if (_filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No FAQ articles matched your search.',
                    style: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredFaqs.length,
                itemBuilder: (context, index) {
                  final faq = _filteredFaqs[index];
                  final isExpanded = _expandedFaqIndices.contains(index);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.cardRadius,
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(
                        color: isExpanded ? AppTheme.accent.withOpacity(0.15) : const Color(0xFFF1F5F9),
                        width: 1.5,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: PageStorageKey(faq['question']),
                        initiallyExpanded: isExpanded,
                        onExpansionChanged: (_) => _toggleFaq(index),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isExpanded ? AppTheme.accent.withOpacity(0.08) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.question_answer_rounded,
                            color: isExpanded ? AppTheme.accent : Colors.black45,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          faq['question']!,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primary,
                          ),
                        ),
                        trailing: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: isExpanded ? AppTheme.accent : Colors.black38,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 4),
                            child: Text(
                              faq['answer']!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // Submit Ticket Form
            Text(
              'Still Need Help?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Send a message directly to our engineering & support staff.',
              style: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dropdown for Category
                  Text(
                    'Topic Category',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Email Input
                  Text(
                    'Your Email Address',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'name@example.com',
                        hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Message Input
                  Text(
                    'Message Details',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'Describe the issue or feature request in detail...',
                        hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: ElevatedButton(
                      onPressed: _submitTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Submit Support Ticket',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
}
