import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'package:provider/provider.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'weight_screen.dart';
import 'macro_targets_screen.dart';
import 'measurements_screen.dart';
import 'medical_history_screen.dart';
import '../providers/auth_provider.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userName = user?['full_name'] ?? user?['email']?.split('@')[0] ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF05080E),
      appBar: AppBar(
        title: const AppLogo(fontSize: 22),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildProfileHeader(context, userName, user?['email'] ?? 'Welcome back!'),
            const SizedBox(height: 30),
            
            _buildSection(context, 'Account Settings', [
              _item(context, Icons.person_outline_rounded, 'Personal Profile', 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
              _item(context, Icons.notifications_none_rounded, 'Notifications', 
                  onTap: () => _showComingSoon(context, 'Notifications')),
              _item(context, Icons.medical_services_outlined, 'Medical History', color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicalHistoryScreen()))),
              _item(context, Icons.settings_outlined, 'App Settings', 
                  onTap: () => _showComingSoon(context, 'Settings')),
            ]),

            _buildSection(context, 'Health & Goals', [
              _item(context, Icons.track_changes_rounded, 'Calorie & Macro Targets', color: const Color(0xFF3ABEF9),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MacroTargetsScreen()))),
              _item(context, Icons.monitor_weight_outlined, 'Weight Tracker', 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WeightScreen()))),
              _item(context, Icons.straighten_rounded, 'Body Measurements', color: Colors.orangeAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MeasurementsScreen()))),
              _item(context, Icons.restaurant_menu_rounded, 'Recipe Discovery', 
                  onTap: () => _showComingSoon(context, 'Recipes')),
              _item(context, Icons.bookmark_border_rounded, 'Personal Library', 
                  onTap: () => _showComingSoon(context, 'Library')),
            ]),

            _buildSection(context, 'Community', [
              _item(context, Icons.people_outline_rounded, 'Friends & Social', 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()))),
              _item(context, Icons.card_giftcard_rounded, 'Referral Program', 
                  onTap: () => _showComingSoon(context, 'Referrals')),
            ]),

            _buildSection(context, 'Support', [
              _item(context, Icons.help_outline_rounded, 'Help Center', 
                  onTap: () => _showComingSoon(context, 'Support')),
              _item(context, Icons.info_outline_rounded, 'About SabTrack', 
                  onTap: () => _showComingSoon(context, 'About')),
            ]),

            const SizedBox(height: 20),
            _buildLogoutButton(context, authProvider),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF161F2C), const Color(0xFF1A2636)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFF3ABEF9).withOpacity(0.2),
            child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3ABEF9))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                      child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ],
                ),
                Text(subtitle, style: TextStyle(color: Colors.blueGrey[400], fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueGrey, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12, top: 24),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161F2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? Colors.blueGrey).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color ?? Colors.blueGrey[200], size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    return InkWell(
      onTap: () => auth.logout(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 10),
              Text('Sign Out Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
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
}
