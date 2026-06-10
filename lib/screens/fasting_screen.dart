import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  bool _isFasting = false;
  String _selectedProtocol = '16:8';
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  DateTime? _fastStart;

  final Map<String, int> _protocols = {
    '12:12': 12,
    '14:10': 14,
    '16:8': 16,
    '18:6': 18,
    '20:4': 20,
  };

  @override
  void initState() {
    super.initState();
    _loadFastingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadFastingState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProtocol = prefs.getString('fasting_selected_protocol') ?? '16:8';
      _isFasting = prefs.getBool('fasting_is_fasting') ?? false;
      final String? startStr = prefs.getString('fasting_start_time');
      if (startStr != null) {
        _fastStart = DateTime.tryParse(startStr);
      }
      
      if (_isFasting && _fastStart != null) {
        _elapsedTime = DateTime.now().difference(_fastStart!);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime = DateTime.now().difference(_fastStart!);
          });
        });
      }
    });
  }

  Future<void> _saveFastingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fasting_is_fasting', _isFasting);
    await prefs.setString('fasting_selected_protocol', _selectedProtocol);
    if (_fastStart != null) {
      await prefs.setString('fasting_start_time', _fastStart!.toIso8601String());
    } else {
      await prefs.remove('fasting_start_time');
    }
  }

  void _toggleFasting() {
    setState(() {
      if (_isFasting) {
        // Stop Fasting
        _timer?.cancel();
        _isFasting = false;
        
        final durationStr = "${_elapsedTime.inHours}h ${_elapsedTime.inMinutes.remainder(60)}m";
        _elapsedTime = Duration.zero;
        _fastStart = null;
        
        // Show completion modal
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.neonAmber, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Fast Completed!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            content: Text(
              'Great job! You completed a fast of $durationStr. Your eating window has now started.',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Perfect', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        // Start Fasting
        _isFasting = true;
        _fastStart = DateTime.now();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime = DateTime.now().difference(_fastStart!);
          });
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fasting timer started! Stay hydrated.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    });
    _saveFastingState();
  }

  String _formatDuration(Duration d) {
    String hours = d.inHours.toString().padLeft(2, '0');
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final int totalFastHours = _protocols[_selectedProtocol]!;
    final double percentage = _isFasting
        ? (_elapsedTime.inSeconds / (totalFastHours * 3600)).clamp(0.0, 1.0)
        : 0.0;

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
          'Intermittent Fasting',
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
          children: [
            // Header stats
            Row(
              children: [
                Expanded(child: _buildStatCard('Fasts Logged', '24', AppTheme.neonPink)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Avg. Duration', '15.8h', AppTheme.neonCyan)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Fasting Streak', '5 days', AppTheme.neonEmerald)),
              ],
            ),
            const SizedBox(height: 28),

            // Main circular timer widget
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Text(
                    _isFasting ? 'FASTING WINDOW ACTIVE' : 'EATING WINDOW ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _isFasting ? AppTheme.neonPink : AppTheme.neonEmerald,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Radial dial indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: _isFasting ? percentage : 1.0,
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: _isFasting ? AppTheme.neonPink : AppTheme.neonEmerald,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isFasting ? _formatDuration(_elapsedTime) : '16:00:00',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isFasting ? 'Elapsed Time' : 'Protocol Target',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 36),
                  
                  // Fasting Action Button
                  GestureDetector(
                    onTap: _toggleFasting,
                    child: Container(
                      height: 58,
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: _isFasting
                            ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF87171)])
                            : AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (_isFasting ? Colors.red : AppTheme.accent).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isFasting ? 'End Fasting' : 'Start Fasting',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select Protocol Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose Fasting Protocol',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: _protocols.keys.map((proto) {
                  final isSelected = _selectedProtocol == proto;
                  final fastH = _protocols[proto];
                  final eatH = 24 - fastH!;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withOpacity(0.04) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: Text(
                        '$proto Fasting',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                      subtitle: Text(
                        '$fastH hours fast • $eatH hours eating window',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w500),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 22)
                          : const Icon(Icons.circle_outlined, color: Colors.black12, size: 22),
                      enabled: !_isFasting, // Disable changes while fast is running
                      onTap: () {
                        setState(() => _selectedProtocol = proto);
                        _saveFastingState();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: col),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
