import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getNotifications();
    if (res['success'] == true && res['data'] != null) {
      final List<dynamic> list = res['data'];
      setState(() {
        _notifications = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String notifId, int index) async {
    await ApiService.markNotificationRead(notifId);
    setState(() {
      _notifications[index]['is_read'] = true;
    });
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add_rounded;
      case 'friend_accept':
        return Icons.people_alt_rounded;
      case 'coaching_request':
        return Icons.sports_rounded;
      case 'coaching_accepted':
        return Icons.verified_user_rounded;
      case 'program_assigned':
      case 'program_shared':
        return Icons.fitness_center_rounded;
      case 'coach_feedback':
        return Icons.rate_review_rounded;
      case 'group_message':
        return Icons.forum_rounded;
      case 'dm':
        return Icons.mark_chat_unread_rounded;
      case 'challenge_invite':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'friend_request':
        return const Color(0xFF6366F1);
      case 'friend_accept':
        return const Color(0xFF10B981);
      case 'coaching_request':
        return const Color(0xFF6366F1);
      case 'coaching_accepted':
        return const Color(0xFF10B981);
      case 'program_assigned':
      case 'program_shared':
        return const Color(0xFF10B981);
      case 'coach_feedback':
        return const Color(0xFF06B6D4);
      case 'group_message':
        return const Color(0xFFF59E0B);
      case 'dm':
        return const Color(0xFFEC4899);
      case 'challenge_invite':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppTheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_none_rounded, size: 48, color: AppTheme.accent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All Caught Up!',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You have no new notifications right now.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppTheme.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final notifId = (item['id'] ?? '').toString();
                      final isRead = item['is_read'] == true;
                      final type = item['type'] as String?;
                      final color = _getColorForType(type);

                      return GestureDetector(
                        onTap: () {
                          if (!isRead && notifId.isNotEmpty) {
                            _markRead(notifId, index);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : color.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead ? const Color(0xFFE2E8F0) : color.withOpacity(0.3),
                              width: isRead ? 1.0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_getIconForType(type), color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['title'] ?? 'Notification',
                                            style: GoogleFonts.inter(
                                              fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                                              fontSize: 14,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['body'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF475569),
                                        height: 1.4,
                                      ),
                                    ),
                                    if (type == 'coaching_request') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final extraData = item['extra_data'] as Map?;
                                                final clientId = (extraData?['client_id'] ?? '').toString();
                                                if (clientId.isNotEmpty) {
                                                  await ApiService.respondCoachingRequest(clientId: clientId, accept: false);
                                                }
                                                if (notifId.isNotEmpty) {
                                                  _markRead(notifId, index);
                                                }
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Coaching request declined.')),
                                                  );
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              child: Text('Decline', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                final extraData = item['extra_data'] as Map?;
                                                final clientId = (extraData?['client_id'] ?? '').toString();
                                                if (clientId.isNotEmpty) {
                                                  await ApiService.respondCoachingRequest(clientId: clientId, accept: true);
                                                }
                                                if (notifId.isNotEmpty) {
                                                  _markRead(notifId, index);
                                                }
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Connected to Coach! Live telemetry linked.'),
                                                      backgroundColor: AppTheme.neonEmerald,
                                                    ),
                                                  );
                                                  Navigator.pop(context);
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF6366F1),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              child: Text('Accept & Connect', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (type == 'program_assigned' || type == 'program_shared') ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (notifId.isNotEmpty) {
                                              _markRead(notifId, index);
                                            }
                                            Navigator.pop(context);
                                          },
                                          icon: const Icon(Icons.fitness_center_rounded, size: 16),
                                          label: const Text('View Program in My Coach'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
