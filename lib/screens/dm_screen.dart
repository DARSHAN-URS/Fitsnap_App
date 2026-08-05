import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class DmScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final Color avatarColor;

  const DmScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    this.avatarColor = AppTheme.accent,
  });

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  Timer? _pollTimer;
  bool _isSending = false;
  bool _isLoading = true;
  String? _myProfileName;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    // Get my profile to mark messages as "mine"
    if (_myProfileName == null || _myUserId == null) {
      final profileRes = await ApiService.getProfile();
      if (profileRes['success'] == true && profileRes['data'] != null) {
        _myProfileName = profileRes['data']['name'] ?? '';
        _myUserId = profileRes['data']['id']?.toString() ?? '';
      }
    }

    final res = await ApiService.getDmMessages(widget.friendId);
    if (res['success'] == true && mounted) {
      final List<dynamic> raw = res['data'] ?? [];
      final myToken = ApiService.token ?? '';
      final cleanTokenId = myToken.replaceAll('mock-token-', '');

      // Check for new incoming messages and notify
      if (silent && raw.length > _messages.length) {
        final oldIds = _messages.map((m) => m['id']).toSet();
        final newMsgs = raw.where((m) {
          final id = m['id']?.toString() ?? '';
          final senderId = m['sender_id']?.toString() ?? '';
          final isSenderMe = (_myUserId != null && _myUserId!.isNotEmpty && senderId == _myUserId) ||
                              (myToken.isNotEmpty && (senderId == myToken || senderId == cleanTokenId));
          return !oldIds.contains(id) && !isSenderMe;
        }).toList();

        for (var m in newMsgs) {
          NotificationService.showNotification(
            id: (m['id'] ?? '').hashCode,
            title: '${widget.friendName} 💬',
            body: m['message'] ?? '',
          );
        }
      }

      setState(() {
        _messages.clear();
        for (var m in raw) {
          final senderId = m['sender_id']?.toString() ?? '';
          final isMe = (_myUserId != null && _myUserId!.isNotEmpty && senderId == _myUserId) ||
                       (myToken.isNotEmpty && (senderId == myToken || senderId == cleanTokenId));
          _messages.add({
            'id': m['id']?.toString() ?? '',
            'message': m['message'] ?? '',
            'isMe': isMe,
            'time': _formatTime(m['created_at']),
          });
        }
        _isLoading = false;
      });

      if (!silent) _scrollToBottom();
    } else if (!silent && mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return 'Now';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return 'Now';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _chatController.clear();

    // Optimistic UI: add message immediately
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'message': text,
      'isMe': true,
      'time': _formatTime(DateTime.now().toIso8601String()),
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    final res = await ApiService.sendDm(widget.friendId, text);
    if (!res['success']) {
      // Remove optimistic message on failure
      setState(() => _messages.removeWhere((m) => m['id'] == tempMsg['id']));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Refresh from server to get the real ID
      await _loadMessages(silent: true);
    }

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.avatarColor.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: widget.avatarColor.withOpacity(0.4), width: 1.5),
              ),
              child: Center(
                child: Text(
                  widget.friendAvatar,
                  style: GoogleFonts.inter(
                    color: widget.avatarColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Direct Message',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded,
                                  color: AppTheme.accent, size: 40),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No messages yet',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Say hi to ${widget.friendName}! 👋',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['isMe'] == true;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: TextField(
                      controller: _chatController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.friendName}...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: _isSending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: widget.avatarColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: widget.avatarColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  widget.friendAvatar,
                  style: GoogleFonts.inter(
                    color: widget.avatarColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppTheme.primaryGradient : null,
                    color: isMe ? null : const Color(0xFF334155),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    msg['message'] ?? '',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg['time'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
