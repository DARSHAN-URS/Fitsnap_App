import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initializes deep link listening on app startup.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // 1. Process initial link (if app was opened via a deep link while cold)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error fetching initial link: $e');
    }

    // 2. Listen to incoming links (if app is already open in background)
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('DeepLinkService: Error on link stream: $err');
      },
    );
  }

  static void _handleDeepLink(Uri uri) {
    debugPrint('DeepLinkService received link: $uri');
    
    // Extract code or group_id parameter
    final String? groupCode = uri.queryParameters['code'] ?? uri.queryParameters['group_id'];
    
    if (groupCode == null || groupCode.isEmpty) return;

    // Check path or host to confirm it's a join-group link
    final String host = uri.host.toLowerCase();
    final String path = uri.path.toLowerCase();

    if (host == 'join-group' || path.contains('join-group')) {
      _processGroupJoin(groupCode);
    }
  }

  static Future<void> _processGroupJoin(String groupCode) async {
    // Wait slightly for Navigator/UI to be ready
    await Future.delayed(const Duration(milliseconds: 600));

    final BuildContext? context = _navigatorKey?.currentContext;
    if (context == null) return;

    // Show prompt to join group
    showDialog(
      context: context,
      builder: (ctx) => _GroupJoinDialog(groupCode: groupCode),
    );
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }
}

class _GroupJoinDialog extends StatefulWidget {
  final String groupCode;
  const _GroupJoinDialog({required this.groupCode});

  @override
  State<_GroupJoinDialog> createState() => _GroupJoinDialogState();
}

class _GroupJoinDialogState extends State<_GroupJoinDialog> {
  bool _isJoining = false;

  Future<void> _join() async {
    setState(() => _isJoining = true);
    final res = await ApiService.joinGroup(widget.groupCode);
    if (!mounted) return;
    setState(() => _isJoining = false);
    Navigator.of(context).pop();

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Successfully joined group!'),
          backgroundColor: Color(0xFF007AFF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Failed to join group'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.group_add_rounded, color: Color(0xFF007AFF), size: 28),
          SizedBox(width: 10),
          Text('Join Group Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Text(
        'You have been invited to join a group (Code: ${widget.groupCode}). Would you like to join now?',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isJoining ? null : _join,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isJoining
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Join Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
