import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/staggered_animation.dart';
import '../utils/preferences_helper.dart';
import 'group_details_screen.dart';

class GroupItem {
  final String title;
  int memberCount;
  final String desc;
  final IconData icon;
  final Color color;
  List<String> avatars;
  String extraMemberText;
  final String tag;
  bool isJoined;
  bool isPrivate;
  List<String> invitedFriends;

  GroupItem({
    required this.title,
    required this.memberCount,
    required this.desc,
    required this.icon,
    required this.color,
    required this.avatars,
    required this.extraMemberText,
    required this.tag,
    this.isJoined = false,
    this.isPrivate = false,
    this.invitedFriends = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'memberCount': memberCount,
      'desc': desc,
      'iconCode': icon.codePoint,
      'colorValue': color.value,
      'avatars': avatars,
      'extraMemberText': extraMemberText,
      'tag': tag,
      'isJoined': isJoined,
      'isPrivate': isPrivate,
      'invitedFriends': invitedFriends,
    };
  }

  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      title: json['title'] as String,
      memberCount: json['memberCount'] as int,
      desc: json['desc'] as String,
      icon: IconData(json['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue'] as int),
      avatars: List<String>.from(json['avatars'] as List),
      extraMemberText: json['extraMemberText'] as String,
      tag: json['tag'] as String,
      isJoined: json['isJoined'] as bool,
      isPrivate: json['isPrivate'] as bool? ?? false,
      invitedFriends: List<String>.from(json['invitedFriends'] as List? ?? []),
    );
  }
}

class FriendItem {
  final String name;
  final String email;
  final int steps;
  final int calories;
  final String avatar;
  final String status;

  FriendItem({
    required this.name,
    required this.email,
    required this.steps,
    required this.calories,
    required this.avatar,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'steps': steps,
      'calories': calories,
      'avatar': avatar,
      'status': status,
    };
  }

  factory FriendItem.fromJson(Map<String, dynamic> json) {
    return FriendItem(
      name: json['name'] as String,
      email: json['email'] as String,
      steps: json['steps'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
      avatar: json['avatar'] as String,
      status: json['status'] as String? ?? 'Offline',
    );
  }
}

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _friendEmailController = TextEditingController();
  late AnimationController _entryAnimController;
  
  final List<GroupItem> _groups = [
    GroupItem(
      title: 'Fitness & Workouts',
      memberCount: 114,
      desc: 'Share daily workouts that match your calorie goals, keep each other accountable.',
      icon: Icons.fitness_center_rounded,
      color: AppTheme.carbsColor,
      avatars: ['JD', 'RS', 'A'],
      extraMemberText: '+11',
      tag: 'Trending',
    ),
    GroupItem(
      title: 'New to Calorie Tracking',
      memberCount: 162,
      desc: 'Beginner questions, quick meal tips, tracking shortcuts, and celebrating first wins.',
      icon: Icons.track_changes_rounded,
      color: AppTheme.accent,
      avatars: ['M', 'TL', 'BK'],
      extraMemberText: '+34',
      tag: 'Popular',
    ),
    GroupItem(
      title: 'Muscle Gain & Bulking',
      memberCount: 199,
      desc: 'Strategies for eating in a clean surplus, protein recipes, and heavy weight lifting.',
      icon: Icons.accessibility_new_rounded,
      color: AppTheme.neonEmerald,
      avatars: ['P', 'SO', 'D'],
      extraMemberText: '+18',
      tag: 'Highly Active',
    ),
    GroupItem(
      title: 'Clean Fasting Habits',
      memberCount: 89,
      desc: 'Share your intermittent fasting protocols, water fasting tips, and support.',
      icon: Icons.timer_outlined,
      color: AppTheme.neonPink,
      avatars: ['E', 'W', 'CH'],
      extraMemberText: '+4',
      tag: 'New',
    ),
  ];

  List<GroupItem> _filteredGroups = [];
  final List<FriendItem> _friends = [
    FriendItem(name: 'Sarah Miller', email: 'sarah.m@fitflow.ai', steps: 8420, calories: 1850, avatar: 'SM', status: 'Active'),
    FriendItem(name: 'Alex Johnson', email: 'alex.j@fitflow.ai', steps: 11200, calories: 2300, avatar: 'AJ', status: 'Active'),
    FriendItem(name: 'John Doe', email: 'john.d@fitflow.ai', steps: 4320, calories: 1600, avatar: 'JD', status: 'Offline'),
    FriendItem(name: 'Emma Wilson', email: 'emma.w@fitflow.ai', steps: 9800, calories: 1950, avatar: 'EW', status: 'Active'),
  ];
  int _selectedTab = 0;
  bool _isAddingFriend = false;

  @override
  void initState() {
    super.initState();
    _filteredGroups = List.from(_groups);
    _searchController.addListener(_filterGroups);
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimController.forward();
    _loadGroups();
    _loadFriends();
  }

  Future<void> _loadGroups() async {
    final List<String>? groupsJsonList = await PreferencesHelper.readStringList('user_groups');
    if (groupsJsonList != null && groupsJsonList.isNotEmpty) {
      try {
        final List<GroupItem> loaded = groupsJsonList.map((gJson) => GroupItem.fromJson(jsonDecode(gJson))).toList();
        setState(() {
          _groups.clear();
          _groups.addAll(loaded);
          _filterGroups();
        });
      } catch (e) {
        debugPrint('Error loading user groups: $e');
      }
    } else {
      _saveGroups();
    }
  }

  Future<void> _saveGroups() async {
    final List<String> groupsJsonList = _groups.map((group) => jsonEncode(group.toJson())).toList();
    await PreferencesHelper.saveStringList('user_groups', groupsJsonList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _friendEmailController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final List<String>? friendsJsonList = await PreferencesHelper.readStringList('user_friends');
    if (friendsJsonList != null && friendsJsonList.isNotEmpty) {
      try {
        final List<FriendItem> loaded = friendsJsonList.map((fJson) => FriendItem.fromJson(jsonDecode(fJson))).toList();
        setState(() {
          _friends.clear();
          _friends.addAll(loaded);
        });
      } catch (e) {
        debugPrint('Error loading user friends: $e');
      }
    } else {
      _saveFriends();
    }
  }

  Future<void> _saveFriends() async {
    final List<String> friendsJsonList = _friends.map((friend) => jsonEncode(friend.toJson())).toList();
    await PreferencesHelper.saveStringList('user_friends', friendsJsonList);
  }

  void _addFriend() async {
    final email = _friendEmailController.text.trim();
    if (email.isEmpty) return;

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (_friends.any((f) => f.email.toLowerCase() == email.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email is already in your friends list!')),
      );
      return;
    }

    setState(() => _isAddingFriend = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    final String namePart = email.split('@')[0];
    final String friendName = namePart.split('.').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    final String initials = namePart.split('.').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase();
    }).take(2).join();

    final newFriend = FriendItem(
      name: friendName,
      email: email,
      steps: 4000 + (1000 * (email.length % 7)),
      calories: 1500 + (100 * (email.length % 5)),
      avatar: initials.isNotEmpty ? initials : 'FR',
      status: 'Active',
    );

    setState(() {
      _friends.add(newFriend);
      _isAddingFriend = false;
      _friendEmailController.clear();
    });
    _saveFriends();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request accepted! $friendName is now your friend.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _filterGroups() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = List.from(_groups);
      } else {
        _filteredGroups = _groups.where((group) {
          return group.title.toLowerCase().contains(query) ||
              group.desc.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleGroupJoin(GroupItem group) {
    setState(() {
      if (group.isJoined) {
        group.isJoined = false;
        group.memberCount--;
      } else {
        group.isJoined = true;
        group.memberCount++;
      }
      _filterGroups();
    });
    _saveGroups();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(group.isJoined ? 'Joined "${group.title}"!' : 'Left "${group.title}".'),
        duration: const Duration(seconds: 1),
        backgroundColor: group.isJoined ? Colors.green : AppTheme.primary,
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        bool isPrivate = false;
        final List<String> selectedFriends = [];
        final friends = _friends.map((f) => f.name).toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Create a Community',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary),
                      decoration: InputDecoration(
                        labelText: 'Community Name',
                        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                        hintText: 'e.g., Keto Diet Enthusiasts',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
                        hintText: 'What is this group about?',
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Private Group Toggle
                    SwitchListTile(
                      activeColor: AppTheme.accent,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Private Group (Invite Only)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      subtitle: Text(
                        'Only invited friends can view activity feed and leaderboards.',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.black38),
                      ),
                      value: isPrivate,
                      onChanged: (val) {
                        setDialogState(() {
                          isPrivate = val;
                        });
                      },
                    ),
                    if (isPrivate) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Invite Friends',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (friends.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No friends added yet. Go to Friends tab to add friends!',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        )
                      else
                        ...friends.map((friend) {
                          final isSelected = selectedFriends.contains(friend);
                          return CheckboxListTile(
                            activeColor: AppTheme.accent,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              friend,
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedFriends.add(friend);
                                } else {
                                  selectedFriends.remove(friend);
                                }
                              });
                            },
                          );
                        }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: Colors.black45, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final desc = descController.text.trim();
                    if (name.isNotEmpty && desc.isNotEmpty) {
                      // Generate initials for avatars
                      final List<String> invitedAvatars = ['ME'];
                      for (var friend in selectedFriends) {
                        final parts = friend.split(' ');
                        String init = '';
                        if (parts.isNotEmpty && parts[0].isNotEmpty) {
                          init += parts[0][0];
                        }
                        if (parts.length > 1 && parts[1].isNotEmpty) {
                          init += parts[1][0];
                        }
                        if (init.isNotEmpty) {
                          invitedAvatars.add(init.toUpperCase());
                        }
                      }

                      final displayAvatars = invitedAvatars.take(3).toList();
                      final extraCountText = invitedAvatars.length > 3 ? "+${invitedAvatars.length - 3}" : "";

                      setState(() {
                        _groups.insert(
                          0,
                          GroupItem(
                            title: name,
                            memberCount: selectedFriends.length + 1,
                            desc: desc,
                            icon: isPrivate ? Icons.lock_outline_rounded : Icons.group_rounded,
                            color: isPrivate ? AppTheme.accent : AppTheme.accent,
                            avatars: displayAvatars,
                            extraMemberText: extraCountText,
                            tag: isPrivate ? 'Private' : 'New',
                            isJoined: true,
                            isPrivate: isPrivate,
                            invitedFriends: selectedFriends,
                          ),
                        );
                        _filterGroups();
                      });
                      _saveGroups();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Community "$name" created successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Friend Input Row
        Container(
          height: 54,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendEmailController,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primary),
                  decoration: InputDecoration(
                    hintText: 'Enter email to add friend...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _addFriend(),
                ),
              ),
              GestureDetector(
                onTap: _addFriend,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isAddingFriend
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        )
                      : Text(
                          'Add',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Friends (${_friends.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_friends.isEmpty)
          ClipRRect(
            borderRadius: AppTheme.cardRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  color: Colors.white.withOpacity(0.55),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people_outline_rounded, color: AppTheme.primary, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'No Friends Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search your friends\' email to add them\nand share your fitness goals!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
              final Color avatarCol = _getAvatarColor(index);
              final isOnline = friend.status.toLowerCase() == 'active';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.cardRadius,
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: avatarCol.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: avatarCol.withOpacity(0.25), width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  friend.avatar,
                                  style: GoogleFonts.inter(
                                    color: avatarCol,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Name/Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                friend.email,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status text
                        Text(
                          friend.status,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green.shade600 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Stats summary
                        Row(
                          children: [
                            Icon(Icons.directions_walk_rounded, color: Colors.orange.shade800, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${friend.steps} steps',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.local_fire_department_rounded, color: AppTheme.accent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${friend.calories} kcal',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),

                        // Actions Row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Fitness challenge invite sent to ${friend.name}! 👟'),
                                    backgroundColor: AppTheme.accent,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
                                ),
                                child: Text(
                                  'Challenge',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Opening chat with ${friend.name}... 💬'),
                                    backgroundColor: AppTheme.primary,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                                ),
                                child: Text(
                                  'Chat',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTabControl() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Communities',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 0 ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Friends',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 1 ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          StaggeredListItem(
            index: 0,
            animationController: _entryAnimController,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Groups',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -1,
                  ),
                ),
                GestureDetector(
                  onTap: _showCreateGroupDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 24),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tab Control Bar
          StaggeredListItem(
            index: 1,
            animationController: _entryAnimController,
            child: _buildTabControl(),
          ),
          const SizedBox(height: 24),

          if (_selectedTab == 0) ...[
            // Communities tab content
            StaggeredListItem(
              index: 2,
              animationController: _entryAnimController,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primary),
                  decoration: InputDecoration(
                    hintText: 'Search communities, challenges...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            
            StaggeredListItem(
              index: 3,
              animationController: _entryAnimController,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discover Communities',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showCreateGroupDialog,
                    child: Text(
                      'Create Private',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_filteredGroups.isEmpty)
              StaggeredListItem(
                index: 4,
                animationController: _entryAnimController,
                child: ClipRRect(
                  borderRadius: AppTheme.cardRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.cardRadius,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        color: Colors.white.withOpacity(0.55),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 40),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No Communities Found',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different search or\ncreate your own community.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreateGroupDialog,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text(
                              'Create Community',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              ..._filteredGroups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;
                return StaggeredListItem(
                  index: 4 + index,
                  animationController: _entryAnimController,
                  child: _buildGroupCard(group),
                );
              }),
          ] else ...[
            // Friends tab content
            StaggeredListItem(
              index: 2,
              animationController: _entryAnimController,
              child: _buildFriendsTab(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupItem group) {
    final Color displayColor = group.color == Colors.white ? AppTheme.accent : group.color;
    return GestureDetector(
      onTap: () {
        if (!group.isJoined) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join the group first to access the dashboard!'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailsScreen(group: group),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
              color: Colors.white.withOpacity(0.55),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: displayColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: displayColor.withOpacity(0.2)),
                      ),
                      child: Icon(group.icon, color: displayColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (group.isPrivate) ...[
                                Icon(Icons.lock_outline_rounded, color: Colors.amber.shade700, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  group.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: displayColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: displayColor.withOpacity(0.25)),
                                ),
                                child: Text(
                                  group.tag,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: displayColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.memberCount} members',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  group.desc,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Overlapping Avatar Stack
                    _buildAvatarStack(group.avatars, group.extraMemberText),
                    
                    // Join / Leave Button
                    TapScaleWrapper(
                      onTap: () => _toggleGroupJoin(group),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: group.isJoined ? const Color(0xFFF1F5F9) : AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                          border: group.isJoined ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                        ),
                        child: Text(
                          group.isJoined ? 'Leave Group' : 'Join Group',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: group.isJoined ? AppTheme.primary : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStack(List<String> initials, String extraCount) {
    List<Widget> items = [];
    
    for (int i = 0; i < initials.length; i++) {
      items.add(
        Positioned(
          left: i * 18.0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _getAvatarColor(i),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                initials[i],
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Extra count circle
    if (extraCount.isNotEmpty) {
      items.add(
        Positioned(
          left: initials.length * 18.0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                extraCount,
                style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: (initials.length + (extraCount.isNotEmpty ? 1 : 0)) * 18.0 + 8.0,
      height: 26,
      child: Stack(
        children: items,
      ),
    );
  }

  Color _getAvatarColor(int index) {
    List<Color> colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
    ];
    return colors[index % colors.length];
  }
}
