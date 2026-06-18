import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLanguageCode = 'en';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'nativeName': 'English', 'code': 'en', 'flag': '🇺🇸'},
    {'name': 'Spanish', 'nativeName': 'Español', 'code': 'es', 'flag': '🇪🇸'},
    {'name': 'French', 'nativeName': 'Français', 'code': 'fr', 'flag': '🇫🇷'},
    {'name': 'German', 'nativeName': 'Deutsch', 'code': 'de', 'flag': '🇩🇪'},
    {'name': 'Hindi', 'nativeName': 'हिन्दी', 'code': 'hi', 'flag': '🇮🇳'},
    {'name': 'Japanese', 'nativeName': '日本語', 'code': 'ja', 'flag': '🇯🇵'},
    {'name': 'Chinese', 'nativeName': '中文', 'code': 'zh', 'flag': '🇨🇳'},
    {'name': 'Arabic', 'nativeName': 'العربية', 'code': 'ar', 'flag': '🇸🇦'},
    {'name': 'Portuguese', 'nativeName': 'Português', 'code': 'pt', 'flag': '🇧🇷'},
  ];

  List<Map<String, String>> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = List.from(_languages);
    _searchController.addListener(_filterList);
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final code = await PreferencesHelper.readString('selected_language_code');
    if (code != null) {
      setState(() {
        _selectedLanguageCode = code;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = List.from(_languages);
      } else {
        _filteredLanguages = _languages.where((lang) {
          return lang['name']!.toLowerCase().contains(query) ||
              lang['nativeName']!.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectLanguage(String code, String name) async {
    setState(() => _selectedLanguageCode = code);
    await PreferencesHelper.saveString('selected_language_code', code);
    await PreferencesHelper.saveString('selected_language_name', name);
    
    // Simulate updating language
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Language changed to $name!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(milliseconds: 1000),
      ),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
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
          'Language',
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
            // Search Input
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
                  hintText: 'Search languages...',
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
            const SizedBox(height: 24),

            // Scrollable List
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
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredLanguages.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                      indent: 72,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, index) {
                      final lang = _filteredLanguages[index];
                      final isSelected = _selectedLanguageCode == lang['code'];

                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              lang['flag']!,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        title: Text(
                          lang['name']!,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          lang['nativeName']!,
                          style: GoogleFonts.inter(
                            color: Colors.black38,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 22)
                            : const Icon(Icons.circle_outlined, color: Colors.black12, size: 22),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        onTap: () => _selectLanguage(lang['code']!, lang['name']!),
                      );
                    },
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
}
