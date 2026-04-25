import 'package:flutter/material.dart';
import 'camera_screen.dart';

class MealSelectionScreen extends StatelessWidget {
  const MealSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B121E),
      appBar: AppBar(
        title: const Text('Add Meal'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How would you like to log your meal?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            _buildSelectionCard(
              context,
              'Describe',
              'Type or speak what you ate',
              Icons.mic_none_rounded,
              const Color(0xFF3ABEF9),
              () => _showComingSoon(context, 'Manual Description'),
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              context,
              'Photo',
              'Take a picture of your food',
              Icons.camera_alt_rounded,
              const Color(0xFFFF5252),
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraScreen())),
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              context,
              'Barcode',
              'Scan product barcode',
              Icons.qr_code_scanner_rounded,
              const Color(0xFFFFAB40),
              () => _showComingSoon(context, 'Barcode Scanning'),
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              context,
              'Package Backside',
              'Scan nutrition label',
              Icons.assignment_rounded,
              const Color(0xFF69F0AE),
              () => _showComingSoon(context, 'Label Scanning'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon to SabTrack!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3ABEF9),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161F2C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }
}
