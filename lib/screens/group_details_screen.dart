import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'groups_tab.dart';
import '../services/api_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupItem group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  int _activeTab = 0; // 0: Leaderboard, 1: Activity Feed, 2: Group Chat
  int _rankMetric = 0; // 0: Steps, 1: Calories, 2: Workouts

  // Stats for friends (loaded dynamically)
  final Map<String, Map<String, dynamic>> _friendStats = {};

  // User stats (loaded dynamically)
  int _mySteps = 0;
  int _myCalories = 0;
  int _myWorkouts = 0;

  // Group Members list
  List<Map<String, dynamic>> _members = [];

  // Chat parameters
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatMessages = [];
  Timer? _chatTimer;

  // Feed items
  final List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStatsAndData();
    _startChatPolling();
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startChatPolling() {
    _chatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_activeTab == 2) {
        _loadChatMessages(silent: true);
      }
    });
  }

  Future<void> _loadUserStatsAndData() async {
    if (mounted) setState(() => _isLoading = true);
    
    // Fetch today's stats from backend
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final statsRes = await ApiService.getDailyStats(date: todayStr);
    if (statsRes['success'] == true && statsRes['data'] != null) {
      _mySteps = statsRes['data']['steps'] ?? 0;
      _myCalories = statsRes['data']['water_ml'] != null ? (statsRes['data']['water_ml'] as num).toInt() : (_mySteps * 0.04).toInt();
    }
    
    // Fetch workouts
    final workoutsRes = await ApiService.getWorkouts();
    if (workoutsRes['success'] == true && workoutsRes['data'] != null) {
      _myWorkouts = (workoutsRes['data'] as List).length;
    }
    
    // Fetch friends list from backend
    final friendsRes = await ApiService.getFriends();
    if (friendsRes['success'] == true && friendsRes['data'] != null) {
      final List<dynamic> friendsList = friendsRes['data'];
      _friendStats.clear();
      for (int i = 0; i < friendsList.length; i++) {
        final f = friendsList[i];
        final name = f['name'] ?? 'Friend';
        _friendStats[name] = {
          'steps': f['steps'] ?? 0,
          'calories': f['calories'] ?? 0,
          'workouts': ((f['steps'] ?? 0) / 4000).toInt() + 1,
          'avatar': f['avatar'] ?? 'FR',
          'color': _getSenderColor(name),
        };
      }
    }
    
    _rebuildMembersList();
    await _loadChatMessages(silent: false);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _rebuildMembersList() {
    final List<Map<String, dynamic>> temp = [];

    // Add Myself
    temp.add({
      'name': 'Me (You)',
      'steps': _mySteps,
      'calories': _myCalories,
      'workouts': _myWorkouts,
      'avatar': 'ME',
      'color': AppTheme.accent,
      'isMe': true,
    });

    // Add friends
    for (final friendName in _friendStats.keys) {
      final stats = _friendStats[friendName]!;
      temp.add({
        'name': friendName,
        'steps': stats['steps'],
        'calories': stats['calories'],
        'workouts': stats['workouts'],
        'avatar': stats['avatar'],
        'color': stats['color'],
        'isMe': false,
      });
    }

    // Sort initial list based on ranking metric
    _sortMembers(temp);

    _members = temp;
    _buildFeedItems();
  }

  void _sortMembers(List<Map<String, dynamic>> list) {
    if (_rankMetric == 0) {
      list.sort((a, b) => (b['steps'] as int).compareTo(a['steps'] as int));
    } else if (_rankMetric == 1) {
      list.sort((a, b) => (b['calories'] as int).compareTo(a['calories'] as int));
    } else {
      list.sort((a, b) => (b['workouts'] as int).compareTo(a['workouts'] as int));
    }
  }

  void _buildFeedItems() {
    _feedItems.clear();
    final friends = _friendStats.keys.toList();
    if (friends.isNotEmpty) {
      for (int i = 0; i < friends.length; i++) {
        final friendName = friends[i];
        final stats = _friendStats[friendName]!;
        final stepsVal = stats['steps'] ?? 5000;
        final runDist = (stepsVal * 0.00075).toStringAsFixed(1);
        _feedItems.add({
          'user': friendName,
          'action': 'completed a $runDist km walk/run ($stepsVal steps today)',
          'time': '${i + 2} hours ago',
          'icon': Icons.directions_run_rounded,
          'color': stats['color'] as Color,
        });
      }
    } else {
      _feedItems.addAll([
        {'user': 'Sarah Miller', 'action': 'completed a 5.3 km Run', 'time': '2 hours ago', 'icon': Icons.directions_run_rounded, 'color': Colors.pink},
        {'user': 'Alex Johnson', 'action': 'completed a 12.0 km Cycle', 'time': '4 hours ago', 'icon': Icons.directions_bike_rounded, 'color': Colors.blue},
      ]);
    }
  }

  Future<void> _loadChatMessages({bool silent = false}) async {
    final res = await ApiService.getGroupMessages(widget.group.id);
    if (res['success'] == true) {
      final List<dynamic> list = res['data'] ?? [];
      final List<Map<String, dynamic>> loadedMessages = [];
      
      // Get current user profile name to check if "isMe"
      final profileRes = await ApiService.getProfile();
      final myName = (profileRes['success'] == true) ? (profileRes['data']?['name'] ?? '') : '';
      
      for (final m in list) {
        final senderName = m['sender_name'] ?? 'Guest';
        final isMe = (myName.isNotEmpty && senderName == myName) || (m['user_id'] == ApiService.token);
        
        loadedMessages.add({
          'id': m['id'].toString(),
          'sender': senderName,
          'message': m['message'] ?? '',
          'time': _formatMessageTime(m['created_at']),
          'isMe': isMe,
          'color': _getSenderColor(senderName),
        });
      }
      
      if (mounted) {
        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(loadedMessages);
        });
        
        if (!silent) {
          _scrollToBottom();
        }
      }
    }
  }

  String _formatMessageTime(String? createdAtStr) {
    if (createdAtStr == null) return 'Just now';
    final dt = DateTime.tryParse(createdAtStr);
    if (dt == null) return 'Just now';
    final localDt = dt.toLocal();
    final hours = localDt.hour.toString().padLeft(2, '0');
    final minutes = localDt.minute.toString().padLeft(2, '0');
    return "$hours:$minutes";
  }

  Color _getSenderColor(String name) {
    final colors = [
      Colors.pink,
      Colors.blue,
      Colors.teal,
      Colors.amber,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    
    _chatController.clear();
    final res = await ApiService.sendGroupMessage(widget.group.id, text);
    if (res['success'] == true) {
      await _loadChatMessages(silent: true);
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to send message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.group.isPrivate) ...[
              const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              widget.group.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                // Subheader details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: AppTheme.cardRadius,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.desc,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${widget.group.memberCount} members active',
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.group.isPrivate ? Colors.amber.withOpacity(0.15) : Colors.cyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.group.isPrivate ? Colors.amberAccent.withOpacity(0.3) : Colors.cyan.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                widget.group.isPrivate ? 'PRIVATE GROUP' : 'PUBLIC COMMUNITY',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: widget.group.isPrivate ? Colors.amberAccent : Colors.cyanAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildTabButton(0, Icons.leaderboard_rounded, 'Leaderboard'),
                        _buildTabButton(1, Icons.rss_feed_rounded, 'Feed'),
                        _buildTabButton(2, Icons.chat_bubble_rounded, 'Chat'),
                      ],
                    ),
                  ),
                ),

                // Main Tab Body
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildActiveTabContent(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = index);
          if (index == 2) {
            _scrollToBottom();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 1:
        return _buildActivityFeedTab();
      case 2:
        return _buildGroupChatTab();
      case 0:
      default:
        return _buildLeaderboardTab();
    }
  }

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        // Metric toggle selector
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _buildMetricToggleButton(0, 'Steps'),
              _buildMetricToggleButton(1, 'Calories'),
              _buildMetricToggleButton(2, 'Workouts'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Expanded(
          child: ListView.builder(
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final isMe = member['isMe'] == true;
              
              String displayVal = "";
              if (_rankMetric == 0) {
                displayVal = "${member['steps']} steps";
              } else if (_rankMetric == 1) {
                displayVal = "${member['calories']} kcal";
              } else {
                displayVal = "${member['workouts']} workouts";
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.03),
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(
                    color: isMe ? AppTheme.accent.withOpacity(0.3) : Colors.white.withOpacity(0.06),
                    width: isMe ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _getRankColor(index),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    CircleAvatar(
                      radius: 19,
                      backgroundColor: (member['color'] as Color).withOpacity(0.15),
                      child: Text(
                        member['avatar'] ?? 'US',
                        style: GoogleFonts.inter(
                          color: member['color'] as Color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['name'] ?? 'User',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (isMe)
                            Text(
                              'Syncing live metrics',
                              style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),

                    Text(
                      displayVal,
                      style: GoogleFonts.plusJakartaSans(
                        color: isMe ? AppTheme.accent : Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricToggleButton(int index, String label) {
    final isSelected = _rankMetric == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _rankMetric = index;
            _sortMembers(_members);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFF59E0B);
    if (index == 1) return const Color(0xFF94A3B8);
    if (index == 2) return const Color(0xFFB45309);
    return Colors.white10;
  }

  Widget _buildActivityFeedTab() {
    return ListView.builder(
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.3),
                        children: [
                          TextSpan(
                            text: item['user'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: item['action'],
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['time'] as String,
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupChatTab() {
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet. Send a message to start the conversation!',
                    style: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final isMe = msg['isMe'] == true;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.accent : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                          border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                msg['sender'] as String,
                                style: GoogleFonts.inter(
                                  color: msg['color'] as Color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 4),
                            Text(
                              msg['message'] as String,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                msg['time'] as String,
                                style: GoogleFonts.inter(
                                  color: isMe ? Colors.white60 : Colors.white30,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Input Field
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: TextField(
                      controller: _chatController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
