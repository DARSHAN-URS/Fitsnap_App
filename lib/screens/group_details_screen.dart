import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';
import 'groups_tab.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupItem group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  int _activeTab = 0; // 0: Leaderboard, 1: Activity Feed, 2: Group Chat
  int _rankMetric = 0; // 0: Steps, 1: Calories, 2: Workouts

  // Mock data for friends
  final Map<String, Map<String, dynamic>> _friendStats = {
    'Alex Johnson': {'steps': 8420, 'calories': 380, 'workouts': 1, 'avatar': 'AJ', 'color': Colors.blue},
    'Sarah Miller': {'steps': 10150, 'calories': 450, 'workouts': 2, 'avatar': 'SM', 'color': Colors.pink},
    'John Doe': {'steps': 4320, 'calories': 210, 'workouts': 0, 'avatar': 'JD', 'color': Colors.teal},
    'Emma Wilson': {'steps': 6800, 'calories': 290, 'workouts': 1, 'avatar': 'EW', 'color': Colors.amber},
  };

  // Mock public users for public groups
  final List<Map<String, dynamic>> _publicMembers = [
    {'name': 'RunningPro', 'steps': 12450, 'calories': 560, 'workouts': 2, 'avatar': 'RP', 'color': Colors.purple},
    {'name': 'FatLossWarrior', 'steps': 9820, 'calories': 410, 'workouts': 1, 'avatar': 'FW', 'color': Colors.orange},
    {'name': 'ActiveUser1', 'steps': 5620, 'calories': 240, 'workouts': 0, 'avatar': 'A1', 'color': Colors.cyan},
  ];

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

  // Pre-populated chat messages
  final List<Map<String, dynamic>> _initialMessages = [
    {'sender': 'Sarah Miller', 'message': 'Hey guys! Ready to crush our step goals today? 🔥', 'time': '2h ago', 'isMe': false, 'color': Colors.pink},
    {'sender': 'Alex Johnson', 'message': 'Just finished a 5km morning run. Feels amazing!', 'time': '1h ago', 'isMe': false, 'color': Colors.blue},
    {'sender': 'John Doe', 'message': 'I am trying to hit 10k steps today, currently at 4.3k.', 'time': '45m ago', 'isMe': false, 'color': Colors.teal},
  ];

  // Feed items
  final List<Map<String, dynamic>> _feedItems = [
    {'user': 'Sarah Miller', 'action': 'completed a 5.3 km Run', 'time': '2 hours ago', 'icon': Icons.directions_run_rounded, 'color': Colors.pink},
    {'user': 'Alex Johnson', 'action': 'completed a 12.0 km Cycle', 'time': '4 hours ago', 'icon': Icons.directions_bike_rounded, 'color': Colors.blue},
    {'user': 'Emma Wilson', 'action': 'completed a 30 min Fasting session', 'time': '5 hours ago', 'icon': Icons.timer_outlined, 'color': Colors.amber},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _setupChat();
  }

  Future<void> _loadUserStats() async {
    final int steps = await PreferencesHelper.readInt('steps_today') ?? 4820;
    final List<String> workouts = await PreferencesHelper.readStringList('workout_history') ?? [];
    
    // Calculate calories dynamically
    final int calories = (steps * 0.04).toInt();
    final int workoutsCount = workouts.length;

    // Load actual friends list from SharedPreferences
    final List<String>? friendsJsonList = await PreferencesHelper.readStringList('user_friends');
    if (friendsJsonList != null && friendsJsonList.isNotEmpty) {
      try {
        final List<FriendItem> loaded = friendsJsonList.map((fJson) => FriendItem.fromJson(jsonDecode(fJson))).toList();
        _friendStats.clear();
        for (int i = 0; i < loaded.length; i++) {
          final friend = loaded[i];
          final List<Color> colors = [
            Colors.blue,
            Colors.pink,
            Colors.teal,
            Colors.amber,
            Colors.purple,
            Colors.orange,
            Colors.cyan,
          ];
          final color = colors[i % colors.length];
          _friendStats[friend.name] = {
            'steps': friend.steps,
            'calories': (friend.steps * 0.045).toInt(),
            'workouts': (friend.steps / 4000).toInt(),
            'avatar': friend.avatar,
            'color': color,
          };
        }
      } catch (e) {
        debugPrint('Error loading user friends for details: $e');
      }
    }

    if (mounted) {
      setState(() {
        _mySteps = steps;
        _myCalories = calories;
        _myWorkouts = workoutsCount;
        _rebuildMembersList();
      });
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

    if (widget.group.isPrivate) {
      // Add invited friends
      for (var friend in widget.group.invitedFriends) {
        if (_friendStats.containsKey(friend)) {
          final stats = _friendStats[friend]!;
          temp.add({
            'name': friend,
            'steps': stats['steps'],
            'calories': stats['calories'],
            'workouts': stats['workouts'],
            'avatar': stats['avatar'],
            'color': stats['color'],
            'isMe': false,
          });
        }
      }
    } else {
      // Public group members
      for (var member in _publicMembers) {
        temp.add({
          'name': member['name'],
          'steps': member['steps'],
          'calories': member['calories'],
          'workouts': member['workouts'],
          'avatar': member['avatar'],
          'color': member['color'],
          'isMe': false,
        });
      }

      // Add user's friends to public groups as well to make it feel active and integrated
      for (var friend in _friendStats.keys) {
        if (!temp.any((m) => m['name'] == friend)) {
          final stats = _friendStats[friend]!;
          temp.add({
            'name': friend,
            'steps': stats['steps'],
            'calories': stats['calories'],
            'workouts': stats['workouts'],
            'avatar': stats['avatar'],
            'color': stats['color'],
            'isMe': false,
          });
        }
      }
    }

    // Sort initial list based on ranking metric
    _sortMembers(temp);

    setState(() {
      _members = temp;
    });
  }

  void _sortMembers(List<Map<String, dynamic>> list) {
    if (_rankMetric == 0) {
      // Steps
      list.sort((a, b) => (b['steps'] as int).compareTo(a['steps'] as int));
    } else if (_rankMetric == 1) {
      // Calories
      list.sort((a, b) => (b['calories'] as int).compareTo(a['calories'] as int));
    } else {
      // Workouts
      list.sort((a, b) => (b['workouts'] as int).compareTo(a['workouts'] as int));
    }
  }

  void _setupChat() {
    _chatMessages.addAll(_initialMessages);
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({
        'sender': 'Me',
        'message': text,
        'time': 'Just now',
        'isMe': true,
        'color': AppTheme.accent,
      });
      _chatController.clear();
    });

    // Auto scroll chat to bottom
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Trigger auto response after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final friends = widget.group.isPrivate ? widget.group.invitedFriends : ['Sarah Miller', 'Alex Johnson'];
      if (friends.isEmpty) return;

      final responder = friends[0];
      final responderStats = _friendStats[responder] ?? {'color': Colors.pink};

      final responses = [
        "Nice! Keep up the great work! 💪",
        "Awesome! Let's hit our goals today!",
        "Brilliant job, inspiring to see! 🙌",
        "Keep moving! We got this!"
      ];
      final randomResponse = responses[DateTime.now().second % responses.length];

      setState(() {
        _chatMessages.add({
          'sender': responder,
          'message': randomResponse,
          'time': 'Just now',
          'isMe': false,
          'color': responderStats['color'] as Color,
        });
      });

      // Scroll to bottom after response
      Timer(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _showInviteFriendsDialog() {
    final friends = _friendStats.keys.toList();
    final availableFriends = friends.where((f) => !widget.group.invitedFriends.contains(f)).toList();

    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All friends are already in this group!'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final List<String> toInvite = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Invite Friends',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: availableFriends.map((friend) {
                    final isSelected = toInvite.contains(friend);
                    return CheckboxListTile(
                      activeColor: AppTheme.accent,
                      title: Text(
                        friend,
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            toInvite.add(friend);
                          } else {
                            toInvite.remove(friend);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black45)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (toInvite.isNotEmpty) {
                      setState(() {
                        widget.group.invitedFriends.addAll(toInvite);
                        widget.group.memberCount += toInvite.length;

                        // Rebuild avatars stack representation
                        final List<String> newAvatars = ['ME'];
                        for (var f in widget.group.invitedFriends) {
                          final stats = _friendStats[f];
                          if (stats != null && stats['avatar'] != null) {
                            newAvatars.add(stats['avatar']);
                          } else {
                            final parts = f.split(' ');
                            String init = '';
                            if (parts.isNotEmpty && parts[0].isNotEmpty) {
                              init += parts[0][0];
                            }
                            if (parts.length > 1 && parts[1].isNotEmpty) {
                              init += parts[1][0];
                            }
                            if (init.isNotEmpty) {
                              newAvatars.add(init.toUpperCase());
                            } else {
                              newAvatars.add('FR');
                            }
                          }
                        }
                        widget.group.avatars.clear();
                        widget.group.avatars.addAll(newAvatars.take(3));
                        widget.group.extraMemberText = newAvatars.length > 3 ? "+${newAvatars.length - 3}" : "";

                        _rebuildMembersList();
                      });
                      
                      // Persist changes in SharedPreferences
                      _saveGlobalGroupsState();

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invited ${toInvite.join(", ")}!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Invite', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveGlobalGroupsState() async {
    final List<String>? groupsJsonList = await PreferencesHelper.readStringList('user_groups');
    if (groupsJsonList != null) {
      try {
        final List<GroupItem> allGroups = groupsJsonList.map((gJson) => GroupItem.fromJson(jsonDecode(gJson))).toList();
        final idx = allGroups.indexWhere((g) => g.title == widget.group.title);
        if (idx != -1) {
          allGroups[idx] = widget.group;
          final List<String> updatedJson = allGroups.map((g) => jsonEncode(g.toJson())).toList();
          await PreferencesHelper.saveStringList('user_groups', updatedJson);
        }
      } catch (e) {
        debugPrint('Error updating user groups global storage: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Matching dark theme for workout groups
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
        actions: [
          if (widget.group.isPrivate)
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              onPressed: _showInviteFriendsDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Subheader details (description + members count)
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

          // Tab Navigation Selector (Leaderboard / Activity Feed / Chat)
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
        onTap: () => setState(() => _activeTab = index),
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
        // Rank Metric Toggle Selector (Steps / Calories / Workouts)
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

        // Leaderboard Stack list
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
                    // Rank badge
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

                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (member['color'] as Color).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: (member['color'] as Color).withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          member['avatar'],
                          style: GoogleFonts.inter(
                            color: member['color'] as Color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['name'],
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

                    // Stats value
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
    if (index == 0) return const Color(0xFFF59E0B); // Gold
    if (index == 1) return const Color(0xFF94A3B8); // Silver
    if (index == 2) return const Color(0xFFB45309); // Bronze
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
        // Chat messages scrollable area
        Expanded(
          child: ListView.builder(
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

        // Text input field at bottom
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
