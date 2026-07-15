import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SupplementsScreen extends StatefulWidget {
  const SupplementsScreen({super.key});

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  List<dynamic> _supplements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSupplements();
  }

  Future<void> _fetchSupplements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.getSupplements();
    if (res['success'] == true) {
      final data = res['data'] as List<dynamic>;
      setState(() {
        _supplements = data;
        _isLoading = false;
      });

      // Synchronize all notification alarms
      for (var item in _supplements) {
        final id = item['id'];
        final name = item['name'];
        final dosage = item['dosage'] ?? '';
        final timeStr = item['time'];
        if (id != null && name != null && timeStr != null) {
          await NotificationService.scheduleSupplementNotification(
            id: id.hashCode,
            name: name,
            dosage: dosage,
            timeStr: timeStr,
          );
        }
      }
    } else {
      setState(() {
        _errorMessage = res['error'] ?? 'Failed to load supplements';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSupplement(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    // Show optimistic loading/deleting state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting ${item['name']}...'),
        duration: const Duration(milliseconds: 500),
      ),
    );

    final res = await ApiService.deleteSupplement(id);
    if (res['success'] == true) {
      // Cancel Scheduled Notification
      await NotificationService.cancelSupplementNotification(id.hashCode);

      setState(() {
        _supplements.removeWhere((element) => element['id'] == id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['name']} deleted successfully!'),
            backgroundColor: AppTheme.neonPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to delete supplement'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  void _showAddSupplementBottomSheet() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Supplement',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Supplement Name',
                        labelStyle: GoogleFonts.inter(color: Colors.black45),
                        hintText: 'e.g. Omega-3 Fish Oil',
                        hintStyle: GoogleFonts.inter(color: Colors.black26),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dosageController,
                      decoration: InputDecoration(
                        labelText: 'Dosage (Optional)',
                        labelStyle: GoogleFonts.inter(color: Colors.black45),
                        hintText: 'e.g. 1 softgel or 1000mg',
                        hintStyle: GoogleFonts.inter(color: Colors.black26),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reminder Time',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.primary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedTime = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.alarm_rounded, color: AppTheme.accent),
                          label: Text(
                            selectedTime.format(context),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final dosage = dosageController.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a supplement name.'),
                                      backgroundColor: AppTheme.caloriesColor,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSaving = true;
                                });

                                final timeFormatted =
                                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                                final res = await ApiService.addSupplement(
                                  name: name,
                                  dosage: dosage,
                                  time: timeFormatted,
                                );

                                if (res['success'] == true) {
                                  final newSupp = res['data'];
                                  
                                  // Schedule reminder notification
                                  await NotificationService
                                      .scheduleSupplementNotification(
                                    id: newSupp['id'].hashCode,
                                    name: newSupp['name'],
                                    dosage: newSupp['dosage'] ?? '',
                                    timeStr: newSupp['time'],
                                  );

                                  if (mounted) {
                                    setState(() {
                                      _supplements.add(newSupp);
                                    });
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$name scheduled successfully!'),
                                        backgroundColor: AppTheme.neonEmerald,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    isSaving = false;
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error'] ??
                                            'Failed to add supplement'),
                                        backgroundColor: AppTheme.caloriesColor,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Save Supplement',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary),
        ),
        title: Text(
          'Supplements & Meds',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchSupplements,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _supplements.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medication_rounded,
                                size: 68,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Supplements Logged',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your daily supplements or medicines, select a reminder time, and we will remind you.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.black45,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _showAddSupplementBottomSheet,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Supplement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _supplements.length,
                      itemBuilder: (context, index) {
                        final item = _supplements[index] as Map<String, dynamic>;
                        final name = item['name'] ?? 'Unknown';
                        final dosage = item['dosage'] ?? 'No dosage info';
                        final timeStr = item['time'] ?? '08:00';

                        // Parse time for formatted display
                        String displayTime = timeStr;
                        try {
                          final timeParts = timeStr.split(':');
                          final hr = int.parse(timeParts[0]);
                          final mn = int.parse(timeParts[1]);
                          final tod = TimeOfDay(hour: hr, minute: mn);
                          displayTime = tod.format(context);
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: AppTheme.cardRadius,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: AppTheme.cardRadius,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.01),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.medication_rounded,
                                        color: AppTheme.accent,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dosage,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.black45,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.alarm_rounded,
                                                size: 14,
                                                color: AppTheme.accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Remind daily at $displayTime',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteSupplement(item),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppTheme.caloriesColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _supplements.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAddSupplementBottomSheet,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}
