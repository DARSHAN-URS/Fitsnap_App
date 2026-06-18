import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/preferences_helper.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

import '../services/api_service.dart';

class MeasurementLogsScreen extends StatefulWidget {
  const MeasurementLogsScreen({super.key});

  @override
  State<MeasurementLogsScreen> createState() => _MeasurementLogsScreenState();
}

class _MeasurementLogsScreenState extends State<MeasurementLogsScreen> {
  // Metric categories mapping
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'weight',
      'name': 'Weight',
      'unit': 'kg',
      'icon': Icons.monitor_weight_outlined,
      'defaultCurrent': 76.4,
      'defaultTarget': 74.3,
      'prefKeyCurrent': 'weight_current',
      'prefKeyTarget': 'weight_target',
      'color': AppTheme.accent,
    },
    {
      'id': 'waist',
      'name': 'Waist',
      'unit': 'in',
      'icon': Icons.accessibility_new_rounded,
      'defaultCurrent': 34.0,
      'defaultTarget': 32.0,
      'prefKeyCurrent': 'waist_current',
      'prefKeyTarget': 'waist_target',
      'color': AppTheme.neonCyan,
    },
    {
      'id': 'chest',
      'name': 'Chest',
      'unit': 'in',
      'icon': Icons.sports_gymnastics_rounded,
      'defaultCurrent': 38.5,
      'defaultTarget': 40.0,
      'prefKeyCurrent': 'chest_current',
      'prefKeyTarget': 'chest_target',
      'color': AppTheme.neonAmber,
    },
    {
      'id': 'arms',
      'name': 'Arms',
      'unit': 'in',
      'icon': Icons.gesture_rounded,
      'defaultCurrent': 13.2,
      'defaultTarget': 14.0,
      'prefKeyCurrent': 'arms_current',
      'prefKeyTarget': 'arms_target',
      'color': AppTheme.neonIndigo,
    },
    {
      'id': 'thighs',
      'name': 'Thighs',
      'unit': 'in',
      'icon': Icons.directions_run_rounded,
      'defaultCurrent': 22.0,
      'defaultTarget': 23.0,
      'prefKeyCurrent': 'thighs_current',
      'prefKeyTarget': 'thighs_target',
      'color': AppTheme.neonEmerald,
    },
    {
      'id': 'strength',
      'name': 'Strength',
      'unit': 'kg',
      'icon': Icons.fitness_center_rounded,
      'defaultCurrent': 5.0,
      'defaultTarget': 15.0,
      'prefKeyCurrent': 'strength_current',
      'prefKeyTarget': 'strength_target',
      'color': AppTheme.neonPink,
    },
  ];

  int _selectedCategoryIndex = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _logs = [];
  double _currentVal = 0.0;
  double _targetVal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Map<String, dynamic> get _selectedCategory => _categories[_selectedCategoryIndex];

  Future<void> _loadCategoryData() async {
    setState(() {
      _isLoading = true;
    });

    final cat = _selectedCategory;
    final currentKey = cat['prefKeyCurrent'] as String;
    final targetKey = cat['prefKeyTarget'] as String;
    final defaultCurrent = cat['defaultCurrent'] as double;
    final defaultTarget = cat['defaultTarget'] as double;

    // Load goals from SharedPreferences
    double current = await PreferencesHelper.readDouble(currentKey) ?? defaultCurrent;
    double target = await PreferencesHelper.readDouble(targetKey) ?? defaultTarget;

    setState(() {
      _currentVal = current;
      _targetVal = target;
      _logs.clear();
    });

    // If authenticated, sync with backend
    if (ApiService.isAuthenticated) {
      final res = await ApiService.getMeasurements(metricType: cat['id']);
      if (res['success'] == true) {
        final List<dynamic> data = res['data'];
        setState(() {
          for (var item in data) {
            _logs.add({
              'id': item['id'],
              'date': item['date'] as String,
              'value': (item['value'] as num).toDouble(),
              'change': 0.0, // Calculated dynamically below
            });
          }
          _calculateChanges();
          if (_logs.isNotEmpty) {
            _currentVal = _logs.first['value'];
            PreferencesHelper.saveDouble(currentKey, _currentVal);
          }
          _isLoading = false;
        });
        return;
      }
    }

    // Offline / Fallback Cache load
    final String? cachedLogsJson = await PreferencesHelper.readString('cached_logs_${cat['id']}');
    setState(() {
      if (cachedLogsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedLogsJson);
          for (var item in decoded) {
            _logs.add(Map<String, dynamic>.from(item));
          }
          _calculateChanges();
          if (_logs.isNotEmpty) {
            _currentVal = _logs.first['value'];
          }
        } catch (e) {
          debugPrint('Error loading cached logs: $e');
        }
      }
      _isLoading = false;
    });
  }

  void _calculateChanges() {
    // Sort logs chronologically to compute changes relative to previous entry
    // Note: _logs is loaded sorted newest first
    for (int i = 0; i < _logs.length; i++) {
      if (i == _logs.length - 1) {
        _logs[i]['change'] = 0.0;
      } else {
        final currentVal = _logs[i]['value'] as double;
        final prevVal = _logs[i + 1]['value'] as double;
        final diff = currentVal - prevVal;
        _logs[i]['change'] = double.parse(diff.toStringAsFixed(1));
      }
    }
  }

  Future<void> _saveLocalLogs() async {
    final cat = _selectedCategory;
    await PreferencesHelper.saveDouble(cat['prefKeyCurrent'] as String, _currentVal);
    await PreferencesHelper.saveDouble(cat['prefKeyTarget'] as String, _targetVal);
    await PreferencesHelper.saveString('cached_logs_${cat['id']}', jsonEncode(_logs));
  }

  void _showLogMeasurementDialog() {
    final cat = _selectedCategory;
    final TextEditingController valController = TextEditingController(text: _currentVal.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Log Today\'s ${cat['name']}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your today\'s ${cat['name'].toLowerCase()} measurement to update progress tracking charts.',
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
                  controller: valController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: InputDecoration(
                    suffixText: cat['unit'],
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
              onPressed: () async {
                final double? newV = double.tryParse(valController.text.trim());
                Navigator.pop(context);
                if (newV != null && newV > 0) {
                  final now = DateTime.now();
                  final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  final String dateStr = "${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}";

                  setState(() {
                    _isLoading = true;
                  });

                  if (ApiService.isAuthenticated) {
                    final res = await ApiService.logMeasurement(
                      metricType: cat['id'],
                      value: newV,
                      date: dateStr,
                    );
                    if (res['success'] == true) {
                      final loggedItem = res['data'];
                      setState(() {
                        _currentVal = newV;
                        _logs.insert(0, {
                          'id': loggedItem['id'],
                          'date': loggedItem['date'] as String,
                          'value': (loggedItem['value'] as num).toDouble(),
                          'change': 0.0,
                        });
                        _calculateChanges();
                        _isLoading = false;
                      });
                      _saveLocalLogs();
                      _showSuccessSnackBar();
                      return;
                    }
                  }

                  // Offline Flow fallback
                  setState(() {
                    _currentVal = newV;
                    _logs.insert(0, {
                      'id': MathMock.randomId(),
                      'date': dateStr,
                      'value': newV,
                      'change': 0.0,
                    });
                    _calculateChanges();
                    _isLoading = false;
                  });
                  _saveLocalLogs();
                  _showSuccessSnackBar();
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

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New ${_selectedCategory['name'].toLowerCase()} log recorded!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _selectedCategory['color'],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showEditGoalDialog() {
    final cat = _selectedCategory;
    final TextEditingController goalController = TextEditingController(text: _targetVal.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Edit Target Goal',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set your target goal for ${cat['name'].toLowerCase()} in ${cat['unit']}.',
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
                  controller: goalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: InputDecoration(
                    suffixText: cat['unit'],
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
              onPressed: () async {
                final double? newGoal = double.tryParse(goalController.text.trim());
                Navigator.pop(context);
                if (newGoal != null && newGoal > 0) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  setState(() {
                    _targetVal = newGoal;
                  });
                  await _saveLocalLogs();
                  
                  // Sync if weight is updated in profile
                  if (cat['id'] == 'weight' && ApiService.isAuthenticated) {
                    final name = await PreferencesHelper.readString('profile_name') ?? 'Guest User';
                    final age = int.tryParse(await PreferencesHelper.readString('profile_age') ?? '25') ?? 25;
                    final height = await PreferencesHelper.readDouble('profile_height') ?? 178.0;
                    final goals = await PreferencesHelper.readString('profile_goal') ?? 'Build Muscle';
                    await ApiService.updateProfile(name: name, age: age, weight: _currentVal, height: height, goals: goals);
                  }

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Target goal updated successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green,
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
                'Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLog(Map<String, dynamic> log) async {
    final cat = _selectedCategory;
    final logId = log['id'] as String;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    bool deleteSuccess = true;
    if (ApiService.isAuthenticated && !logId.startsWith('mock_')) {
      final res = await ApiService.deleteMeasurement(logId);
      deleteSuccess = res['success'] == true;
    }

    if (deleteSuccess) {
      setState(() {
        _logs.removeWhere((l) => l['id'] == logId);
        _calculateChanges();
        if (_logs.isNotEmpty) {
          _currentVal = _logs.first['value'];
        } else {
          _currentVal = cat['defaultCurrent'] as double;
        }
        _isLoading = false;
      });
      _saveLocalLogs();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Log deleted successfully.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
      });
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to delete log from server.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _selectedCategory;
    final double diffTotal = _currentVal - _targetVal;
    
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
          'Measurements Log',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Horizontal category picker list
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = index == _selectedCategoryIndex;
                final col = category['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    if (index != _selectedCategoryIndex) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                      _loadCategoryData();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? col : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(
                        color: isSelected ? col : const Color(0xFFF1F5F9),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          Icon(
                            category['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : AppTheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category['name'],
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : AppTheme.primary,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                        // Header Stats Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cat['color'].withOpacity(0.08), cat['color'].withOpacity(0.02)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: AppTheme.cardRadius,
                            border: Border.all(color: cat['color'].withOpacity(0.15), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryColumn('Current', '${_currentVal.toStringAsFixed(1)} ${cat['unit']}', cat['color']),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.black12,
                                  ),
                                  GestureDetector(
                                    onTap: _showEditGoalDialog,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildSummaryColumn('Target Goal', '${_targetVal.toStringAsFixed(1)} ${cat['unit']}', Colors.black54),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_rounded, size: 12, color: Colors.black38),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.black12,
                                  ),
                                  _buildSummaryColumn(
                                    diffTotal >= 0 ? 'Surplus' : 'Remaining',
                                    '${diffTotal.abs().toStringAsFixed(1)} ${cat['unit']}',
                                    diffTotal >= 0 ? AppTheme.caloriesColor : Colors.green,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _showLogMeasurementDialog,
                                child: Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: cat['color'] as Color,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (cat['color'] as Color).withOpacity(0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Log Today\'s ${cat['name']}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
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
                            '${cat['name']} History',
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
                              child: _logs.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No logs recorded for ${cat['name'].toLowerCase()} yet.',
                                        style: GoogleFonts.inter(color: Colors.black45, fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
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
                                        final double change = log['change'] ?? 0.0;
                                        final bool isNegative = change < 0;
                                        final bool isZero = change == 0;

                                        // Set indicators based on metric types (strength/chest build gains vs weight/waist losses)
                                        final bool isProgressiveGoal = cat['id'] == 'chest' || cat['id'] == 'arms' || cat['id'] == 'thighs' || cat['id'] == 'strength';
                                        final bool isGoodChange = isProgressiveGoal ? !isNegative : isNegative;

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
                                                '${log['value']} ${cat['unit']}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Change Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isZero
                                                      ? Colors.grey.shade100
                                                      : (isGoodChange ? Colors.green.shade50 : Colors.red.shade50),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    if (!isZero)
                                                      Icon(
                                                        change < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                                        color: isGoodChange ? Colors.green.shade700 : Colors.red.shade700,
                                                        size: 11,
                                                      ),
                                                    if (!isZero) const SizedBox(width: 2),
                                                    Text(
                                                      isZero ? '--' : '${change.abs()} ${cat['unit']}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: isZero
                                                            ? Colors.black45
                                                            : (isGoodChange ? Colors.green.shade700 : Colors.red.shade700),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.black26, size: 18),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Delete Log'),
                                                      content: const Text('Are you sure you want to delete this measurement entry?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                            _deleteLog(log);
                                                          },
                                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
          ),
        ],
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
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: col),
        ),
      ],
    );
  }
}

class MathMock {
  static String randomId() {
    return 'mock_${MathMock._randomString(8)}';
  }

  static String _randomString(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    String res = '';
    for (int i = 0; i < len; i++) {
      res += chars[(rand + i) % chars.length];
    }
    return res;
  }
}
