import 'dart:convert';
import 'package:flutter/material.dart';
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

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
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
    _entryAnimController.dispose();
    super.dispose();
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
        final friends = ['Alex Johnson', 'Sarah Miller', 'John Doe', 'Emma Wilson'];

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
          const SizedBox(height: 20),

          // Search Bar
          StaggeredListItem(
            index: 1,
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
            index: 2,
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
              index: 3,
              animationController: _entryAnimController,
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: AppTheme.cardRadius,
                image: DecorationImage(
                  image: CachedNetworkImageProvider('https://images.unsplash.com/photo-1529156069898-49953e39b3ac?q=80&w=600&auto=format&fit=crop'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.white70, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Communities Found',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try a different search or\ncreate your own community.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white60,
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
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            )
          else
            ..._filteredGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return StaggeredListItem(
                index: 3 + index,
                animationController: _entryAnimController,
                child: _buildGroupCard(group),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupItem group) {
    String imageUrl = 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=600&auto=format&fit=crop';
    if (group.title.toLowerCase().contains('fitness') || group.title.toLowerCase().contains('workout')) {
      imageUrl = 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=600&auto=format&fit=crop';
    } else if (group.title.toLowerCase().contains('calorie') || group.title.toLowerCase().contains('tracking')) {
      imageUrl = 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=600&auto=format&fit=crop';
    } else if (group.title.toLowerCase().contains('muscle') || group.title.toLowerCase().contains('bulking')) {
      imageUrl = 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?q=80&w=600&auto=format&fit=crop';
    } else if (group.title.toLowerCase().contains('fasting')) {
      imageUrl = 'https://images.unsplash.com/photo-1548690312-e3b507d8c110?q=80&w=600&auto=format&fit=crop';
    }

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: AppTheme.cardRadius,
          image: DecorationImage(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.65),
              BlendMode.darken,
            ),
          ),
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Icon(group.icon, color: group.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (group.isPrivate) ...[
                            const Icon(Icons.lock_outline_rounded, color: Colors.amberAccent, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              group.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              group.tag,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.memberCount} members',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              group.desc,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
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
                      color: group.isJoined ? Colors.white24 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: group.isJoined ? Border.all(color: Colors.white38) : null,
                    ),
                    child: Text(
                      group.isJoined ? 'Leave Group' : 'Join Group',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: group.isJoined ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
