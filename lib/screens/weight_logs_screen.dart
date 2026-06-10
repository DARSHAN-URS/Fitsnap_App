import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class WeightLogsScreen extends StatefulWidget {
  const WeightLogsScreen({super.key});

  @override
  State<WeightLogsScreen> createState() => _WeightLogsScreenState();
}

class _WeightLogsScreenState extends State<WeightLogsScreen> {
  final List<Map<String, dynamic>> _logs = [
    {'date': 'Jun 08, 2026', 'weight': 76.4, 'change': -0.2},
    {'date': 'Jun 05, 2026', 'weight': 76.6, 'change': -0.3},
    {'date': 'Jun 01, 2026', 'weight': 76.9, 'change': -0.4},
    {'date': 'May 25, 2026', 'weight': 77.3, 'change': -0.7},
    {'date': 'May 20, 2026', 'weight': 78.0, 'change': 0.2},
    {'date': 'May 15, 2026', 'weight': 77.8, 'change': -0.4},
    {'date': 'May 10, 2026', 'weight': 78.2, 'change': -0.3},
    {'date': 'May 05, 2026', 'weight': 78.5, 'change': 0.0},
  ];

  double _currentWeight = 76.4;
  double _targetWeight = 74.3;

  @override
  void initState() {
    super.initState();
    _loadWeightLogs();
  }

  Future<void> _loadWeightLogs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentWeight = prefs.getDouble('weight_current') ?? 76.4;
      _targetWeight = prefs.getDouble('weight_target') ?? 74.3;
      final String? logsJson = prefs.getString('weight_logs');
      if (logsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(logsJson);
          _logs.clear();
          for (var item in decoded) {
            _logs.add(Map<String, dynamic>.from(item));
          }
        } catch (e) {
          debugPrint('Error loading weight logs: $e');
        }
      }
    });
  }

  Future<void> _saveWeightLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weight_current', _currentWeight);
    await prefs.setDouble('weight_target', _targetWeight);
    await prefs.setString('weight_logs', jsonEncode(_logs));
  }

  void _showLogWeightDialog() {
    final TextEditingController weightController = TextEditingController(text: _currentWeight.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Log Today\'s Weight',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your weight to update progress tracking metrics.',
                style: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: const InputDecoration(
                    suffixText: 'kg',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.black45, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final double? newW = double.tryParse(weightController.text.trim());
                Navigator.pop(context);
                if (newW != null && newW > 0) {
                  final double diff = newW - _currentWeight;
                  
                  // Calculate date string
                  final now = DateTime.now();
                  final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  final String dateStr = "${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}";

                  setState(() {
                    _currentWeight = newW;
                    _logs.insert(0, {
                      'date': dateStr,
                      'weight': newW,
                      'change': double.parse(diff.toStringAsFixed(1)),
                    });
                  });
                  _saveWeightLogs();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('New weight log recorded!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(
                'Log',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double diffTotal = _currentWeight - _targetWeight;
    
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
          'Weight Logs',
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
            // Header Stats Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent.withOpacity(0.08), AppTheme.accent.withOpacity(0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: AppTheme.accent.withOpacity(0.15), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryColumn('Current Weight', '${_currentWeight.toStringAsFixed(1)} kg', AppTheme.accent),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.black12,
                      ),
                      _buildSummaryColumn('Target Weight', '${_targetWeight.toStringAsFixed(1)} kg', Colors.black54),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.black12,
                      ),
                      _buildSummaryColumn('Remaining', '${diffTotal.toStringAsFixed(1)} kg', AppTheme.caloriesColor),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _showLogWeightDialog,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: Center(
                        child: Text(
                          'Log Today\'s Weight',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // History Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Log History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // History list
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
                    itemCount: _logs.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                      indent: 20,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final double change = log['change'];
                      final bool isNegative = change < 0;
                      final bool isZero = change == 0;

                      return ListTile(
                        title: Text(
                          log['date'],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                            fontSize: 14.5,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${log['weight']} kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Change Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isZero
                                    ? Colors.grey.shade100
                                    : (isNegative ? Colors.green.shade50 : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  if (!isZero)
                                    Icon(
                                      isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      color: isNegative ? Colors.green.shade700 : Colors.red.shade700,
                                      size: 11,
                                    ),
                                  if (!isZero) const SizedBox(width: 2),
                                  Text(
                                    isZero ? '--' : '${change.abs()} kg',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isZero
                                          ? Colors.black45
                                          : (isNegative ? Colors.green.shade700 : Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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

  Widget _buildSummaryColumn(String title, String val, Color col) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: col),
        ),
      ],
    );
  }
}
