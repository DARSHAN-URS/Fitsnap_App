import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/staggered_animation.dart';
import '../utils/preferences_helper.dart';
import 'group_details_screen.dart';
import 'dm_screen.dart';
import 'notifications_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/groups_provider.dart';

class GroupItem {
  final String id;
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
    required this.id,
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

  factory GroupItem.fromJson(Map<String, dynamic> json) => GroupItem.fromBackendJson(json);

  GroupItem copyWith({
    String? id,
    String? title,
    int? memberCount,
    String? desc,
    IconData? icon,
    Color? color,
    List<String>? avatars,
    String? extraMemberText,
    String? tag,
    bool? isJoined,
    bool? isPrivate,
    List<String>? invitedFriends,
  }) {
    return GroupItem(
      id: id ?? this.id,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
      desc: desc ?? this.desc,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      avatars: avatars ?? this.avatars,
      extraMemberText: extraMemberText ?? this.extraMemberText,
      tag: tag ?? this.tag,
      isJoined: isJoined ?? this.isJoined,
      isPrivate: isPrivate ?? this.isPrivate,
      invitedFriends: invitedFriends ?? this.invitedFriends,
    );
  }

  factory GroupItem.fromBackendJson(Map<String, dynamic> json) {
    final String name = json['name'] ?? json['title'] ?? '';
    IconData iconData = Icons.group_rounded;
    if (name.toLowerCase().contains('workout') || name.toLowerCase().contains('fitness')) {
      iconData = Icons.fitness_center_rounded;
    } else if (name.toLowerCase().contains('calorie') || name.toLowerCase().contains('diet')) {
      iconData = Icons.track_changes_rounded;
    } else if (name.toLowerCase().contains('muscle') || name.toLowerCase().contains('bulking')) {
      iconData = Icons.accessibility_new_rounded;
    } else if (name.toLowerCase().contains('fasting') || name.toLowerCase().contains('timer')) {
      iconData = Icons.timer_outlined;
    }
    
    return GroupItem(
      id: (json['id'] ?? '').toString(),
      title: name,
      memberCount: json['memberCount'] ?? 1,
      desc: json['description'] ?? json['desc'] ?? '',
      icon: iconData,
      color: AppTheme.accent,
      avatars: List<String>.from(json['avatars'] ?? []),
      extraMemberText: json['extraMemberText'] ?? '',
      tag: json['tag'] ?? 'Trending',
      isJoined: json['isJoined'] ?? false,
      isPrivate: !(json['is_public'] ?? true),
      invitedFriends: [],
    );
  }
}

String getSmartDisplayName(String? name, String? username, String? email) {
  final n = (name ?? '').trim();
  final u = (username ?? '').trim();
  final e = (email ?? '').trim();

  if (n.isNotEmpty && !['user', 'friend user', 'user user', 'none', 'null'].contains(n.toLowerCase())) {
    return n;
  }
  if (u.isNotEmpty && !['user', 'none', 'null'].contains(u.toLowerCase())) {
    return u;
  }
  if (e.isNotEmpty && e.contains('@')) {
    final prefix = e.split('@').first.trim();
    if (prefix.isNotEmpty && !['user', 'none', 'null'].contains(prefix.toLowerCase())) {
      return prefix;
    }
  }
  return n.isNotEmpty ? n : (u.isNotEmpty ? u : 'User');
}

String getAvatarInitials(String displayName) {
  final cleaned = displayName.trim();
  if (cleaned.isEmpty) return 'U';
  final parts = cleaned.split(' ').where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}

class FriendItem {
  final String id;
  final String friendId;
  final String name;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final int steps;
  final int calories;
  final String avatar;
  final String status;

  factory FriendItem.fromJson(Map<String, dynamic> json) => FriendItem.fromBackendJson(json);

  FriendItem({
    required this.id,
    this.friendId = '',
    required this.name,
    this.username = '',
    this.email = '',
    this.profilePictureUrl,
    this.steps = 0,
    this.calories = 0,
    this.avatar = 'FR',
    this.status = 'Active',
    String? activity,
  });

  factory FriendItem.fromBackendJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final uname = json['username'] ?? '';
    final mail = json['email'] ?? '';
    final resolvedName = getSmartDisplayName(rawName, uname, mail);
    final rawAvatar = json['avatar'];
    final avatarInit = (rawAvatar != null && rawAvatar != 'FR' && rawAvatar != 'US' && rawAvatar.toString().trim().isNotEmpty)
        ? rawAvatar.toString()
        : getAvatarInitials(resolvedName);

    return FriendItem(
      id: (json['id'] ?? '').toString(),
      friendId: (json['friend_id'] ?? '').toString(),
      name: resolvedName,
      username: uname,
      email: mail,
      profilePictureUrl: json['profile_picture_url'],
      steps: json['steps'] ?? 0,
      calories: json['calories'] ?? 0,
      avatar: avatarInit,
      status: json['status'] ?? 'Active',
    );
  }
}

class GroupsTab extends ConsumerStatefulWidget {
  const GroupsTab({super.key});

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<GroupsTab> with TickerProviderStateMixin {
  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -120,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.08),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          right: -120,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonIndigo.withOpacity(0.06),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _friendEmailController = TextEditingController();
  late AnimationController _entryAnimController;
  
  final List<GroupItem> _groups = [];
  List<GroupItem> _filteredGroups = [];
  final List<FriendItem> _friends = [];
  final List<dynamic> _pendingRequests = [];
  int _selectedTab = 0;
  bool _isAddingFriend = false;
  bool _isLoading = true;

  List<dynamic> _searchSuggestions = [];
  final List<dynamic> _suggestions = [];
  String _lastSearchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterGroups);
    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimController.forward();
    _loadCachedDataAndFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _friendEmailController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedDataAndFetch() async {
    final cachedGroups = await PreferencesHelper.readString('cache_groups_list');
    final cachedFriends = await PreferencesHelper.readString('cache_friends_list');
    
    bool hasCached = false;
    if (cachedGroups != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedGroups);
        _groups.clear();
        _groups.addAll(list.map((g) => GroupItem.fromBackendJson(g)).toList());
        _isLoading = false;
        hasCached = true;
      } catch (_) {}
    }
    
    if (cachedFriends != null) {
      try {
        final List<dynamic> list = jsonDecode(cachedFriends);
        _friends.clear();
        _friends.addAll(list.map((f) => FriendItem.fromBackendJson(f)).toList());
        _isLoading = false;
        hasCached = true;
      } catch (_) {}
    }
    
    if (hasCached && mounted) {
      setState(() {});
    }
    
    await _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    if (_groups.isEmpty && _friends.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    final groupsRes = await ApiService.getGroups();
    final friendsRes = await ApiService.getFriends();
    final suggestionsRes = await ApiService.getFriendSuggestions();
    final pendingRes = await ApiService.getPendingFriendRequests();
    
    List<GroupItem> newGroups = _groups;
    if (groupsRes['success'] == true) {
      final List<dynamic> list = groupsRes['data'] ?? [];
      newGroups = list.map((g) => GroupItem.fromBackendJson(g)).toList();
      await PreferencesHelper.saveString('cache_groups_list', jsonEncode(list));
    }
    
    List<FriendItem> newFriends = _friends;
    if (friendsRes['success'] == true) {
      final List<dynamic> list = friendsRes['data'] ?? [];
      newFriends = list.map((f) => FriendItem.fromBackendJson(f)).toList();
      await PreferencesHelper.saveString('cache_friends_list', jsonEncode(list));
    }

    List<dynamic> newSuggestions = [];
    if (suggestionsRes['success'] == true) {
      newSuggestions = suggestionsRes['data'] ?? [];
    }

    List<dynamic> newPending = [];
    if (pendingRes['success'] == true) {
      newPending = pendingRes['data'] ?? [];
    }
    
    if (mounted) {
      setState(() {
        _groups.clear();
        _groups.addAll(newGroups);
        _friends.clear();
        _friends.addAll(newFriends);
        _suggestions.clear();
        _suggestions.addAll(newSuggestions);
        _pendingRequests.clear();
        _pendingRequests.addAll(newPending);
        _isLoading = false;
        _filterGroups();
      });
    }
  }

  Future<void> _addFriend() async {
    final query = _friendEmailController.text.trim();
    if (query.isEmpty) return;
    await _addFriendWithUsername(query);
  }

  Future<void> _addFriendWithUsername(String query) async {
    setState(() => _isAddingFriend = true);

    final res = await ApiService.addFriend(query);
    if (res['success'] == true) {
      _friendEmailController.clear();
      setState(() {
        _searchSuggestions.clear();
        _lastSearchQuery = '';
      });
      await _fetchData();
      
      NotificationService.showNotification(
        id: query.hashCode,
        title: 'Friend Request Sent! 📩',
        body: 'Your friend request to $query has been sent.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $query! 📩'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'User not found or request already sent'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isAddingFriend = false);
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final res = await ApiService.acceptFriendRequest(requestId);
    if (res['success'] == true) {
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted! 🤝'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to accept request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    final res = await ApiService.declineFriendRequest(requestId);
    if (res['success'] == true) {
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  void _onSearchTextChanged(String val) {
    final query = val.trim();
    setState(() {
      _lastSearchQuery = query;
    });

    if (query.length < 2) {
      setState(() {
        _searchSuggestions.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _fetchSearchSuggestions(query);
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    final res = await ApiService.searchUsers(query);
    if (mounted && query == _lastSearchQuery) {
      setState(() {
        _searchSuggestions = res['data'] ?? [];
        _isSearching = false;
      });
    }
  }

  int _groupFilterIndex = 0; // 0 = All, 1 = Public, 2 = Private

  void _filterGroups() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGroups = _groups.where((group) {
        final matchesQuery = query.isEmpty ||
            group.title.toLowerCase().contains(query) ||
            group.desc.toLowerCase().contains(query);
        final matchesCategory = _groupFilterIndex == 0 ||
            (_groupFilterIndex == 1 && !group.isPrivate) ||
            (_groupFilterIndex == 2 && group.isPrivate);
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  Future<void> _toggleGroupJoin(GroupItem group) async {
    final bool isLeaving = group.isJoined;

    // 1. Optimistic 0ms UI update: update local list item immediately
    setState(() {
      group.isJoined = !isLeaving;
      if (isLeaving) {
        group.memberCount = (group.memberCount - 1).clamp(0, 999999);
      } else {
        group.memberCount += 1;
      }
      _filterGroups();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isLeaving ? 'Joined "${group.title}"!' : 'Left "${group.title}".'),
          duration: const Duration(seconds: 1),
          backgroundColor: !isLeaving ? Colors.green : AppTheme.primary,
        ),
      );
    }

    // 2. Perform network request in background without blocking screen
    final res = isLeaving 
        ? await ApiService.leaveGroup(group.id)
        : await ApiService.joinGroup(group.id);

    if (res['success'] != true) {
      // Revert local state on failure
      if (mounted) {
        setState(() {
          group.isJoined = isLeaving;
          if (isLeaving) {
            group.memberCount += 1;
          } else {
            group.memberCount = (group.memberCount - 1).clamp(0, 999999);
          }
          _filterGroups();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Operation failed. Reverting.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Sync Riverpod state silently
      ref.read(groupsProvider.notifier).fetchAllData(showLoading: false);
    }
  }

  Future<void> _createGroupBackend(String name, String desc, bool isPrivate) async {
    if (mounted) setState(() => _isLoading = true);
    final res = await ApiService.createGroup(name, desc, isPublic: !isPrivate);
    if (res['success'] == true) {
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Community "$name" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to create community'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        bool isPrivate = false;

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
                      Navigator.pop(context);
                      _createGroupBackend(name, desc, isPrivate);
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
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 54,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _friendEmailController,
                      onChanged: _onSearchTextChanged,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'Enter username or email to add friend...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        suffixIcon: _friendEmailController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _friendEmailController.clear();
                                  _onSearchTextChanged('');
                                },
                                child: const Icon(Icons.cancel_rounded, color: Colors.black26, size: 20),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _addFriend(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _addFriend,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
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
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        if (_isSearching || _searchSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
                          ),
                        ),
                      ),
                    if (!_isSearching && _searchSuggestions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No matching users found',
                            style: GoogleFonts.inter(
                              color: Colors.black38,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (!_isSearching && _searchSuggestions.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _searchSuggestions.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final user = _searchSuggestions[index];
                            final String username = user['username'] ?? '';
                            final String email = user['email'] ?? '';
                            final String displayName = getSmartDisplayName(user['name'], username, email);
                            final String? picUrl = user['profile_picture_url'];
                            
                            // Check if already friends
                            final isAlreadyFriend = _friends.any((f) => 
                              f.friendId.toString() == user['id'].toString() || 
                              (email.isNotEmpty && f.email.toLowerCase() == email.toLowerCase())
                            );

                            final List<Color> gradients = [
                              AppTheme.accent,
                              AppTheme.neonPink,
                              AppTheme.neonEmerald,
                              AppTheme.neonAmber,
                            ];
                            final Color placeholderColor = gradients[index % gradients.length];

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                      gradient: picUrl == null || picUrl.isEmpty
                                          ? LinearGradient(
                                              colors: [
                                                placeholderColor.withOpacity(0.12),
                                                placeholderColor.withOpacity(0.04),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      image: picUrl != null && picUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: picUrl.startsWith('http')
                                                  ? CachedNetworkImageProvider(picUrl)
                                                  : FileImage(File(picUrl)) as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: picUrl == null || picUrl.isEmpty
                                        ? Center(
                                            child: Text(
                                              getAvatarInitials(displayName),
                                              style: GoogleFonts.inter(
                                                color: placeholderColor,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username.isNotEmpty ? '@$username' : email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: Colors.black45,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isAlreadyFriend)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_rounded, color: Colors.grey.shade600, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Friends',
                                            style: GoogleFonts.inter(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => _addFriendWithUsername(username.isNotEmpty ? username : email),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Add',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (!_isSearching && _searchSuggestions.isEmpty && _pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Pending Friend Requests',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_pendingRequests.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingRequests.length,
            itemBuilder: (context, index) {
              final req = _pendingRequests[index];
              final String requestId = (req['id'] ?? '').toString();
              final String username = req['username'] ?? '';
              final String email = req['email'] ?? '';
              final String name = getSmartDisplayName(req['name'], username, email);
              final String avatar = req['avatar'] != null && req['avatar'] != 'FR' && req['avatar'] != 'US'
                  ? req['avatar']
                  : getAvatarInitials(name);
              final String? picUrl = req['profile_picture_url'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withOpacity(0.12),
                        image: picUrl != null && picUrl.isNotEmpty
                            ? DecorationImage(
                                image: picUrl.startsWith('http')
                                    ? CachedNetworkImageProvider(picUrl)
                                    : FileImage(File(picUrl)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: picUrl == null || picUrl.isEmpty
                          ? Center(
                              child: Text(
                                avatar,
                                style: GoogleFonts.inter(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _acceptRequest(requestId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Accept', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _declineRequest(requestId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Decline', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        if (!_isSearching && _searchSuggestions.isEmpty && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Suggested Friends',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final user = _suggestions[index];
                final String username = user['username'] ?? '';
                final String email = user['email'] ?? '';
                final String displayName = getSmartDisplayName(user['name'], username, email);
                final String? picUrl = user['profile_picture_url'];
                
                final List<Color> gradients = [
                  AppTheme.accent,
                  AppTheme.neonPink,
                  AppTheme.neonEmerald,
                  AppTheme.neonAmber,
                ];
                final Color placeholderColor = gradients[index % gradients.length];
                
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                          gradient: picUrl == null || picUrl.isEmpty
                              ? LinearGradient(
                                  colors: [
                                    placeholderColor.withOpacity(0.12),
                                    placeholderColor.withOpacity(0.04),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          image: picUrl != null && picUrl.isNotEmpty
                              ? DecorationImage(
                                  image: picUrl.startsWith('http')
                                      ? CachedNetworkImageProvider(picUrl)
                                      : FileImage(File(picUrl)) as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: picUrl == null || picUrl.isEmpty
                            ? Center(
                                child: Text(
                                  getAvatarInitials(displayName),
                                  style: GoogleFonts.inter(
                                    color: placeholderColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username.isNotEmpty ? '@$username' : (email.isNotEmpty ? email : 'User'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _addFriendWithUsername(username.isNotEmpty ? username : email),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Add',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Friends (${_friends.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_friends.isEmpty)
          ClipRRect(
            borderRadius: AppTheme.cardRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: AppTheme.cardRadius,
                  border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                  color: Colors.white.withOpacity(0.6),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accent.withOpacity(0.18),
                            AppTheme.accent.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.people_outline_rounded, color: AppTheme.accent, size: 40),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Friends Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        fontSize: 18,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search your friends\' username or email above\nto connect, chat, and challenge each other!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
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

              return ClipRRect(
                borderRadius: AppTheme.cardRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: AppTheme.cardRadius,
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
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
                                    image: friend.profilePictureUrl != null && friend.profilePictureUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: friend.profilePictureUrl!.startsWith('http')
                                                ? CachedNetworkImageProvider(friend.profilePictureUrl!)
                                                : FileImage(File(friend.profilePictureUrl!)) as ImageProvider,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: friend.profilePictureUrl == null || friend.profilePictureUrl!.isEmpty
                                      ? Center(
                                          child: Text(
                                            friend.avatar,
                                            style: GoogleFonts.inter(
                                              color: avatarCol,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        )
                                      : null,
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    friend.email,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.black45,
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
                        const Divider(height: 24, thickness: 0.8, color: Color(0xFFF1F5F9)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stats summary
                            Row(
                              children: [
                                // Steps Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${friend.steps}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF0F172A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Calories Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEF4444), size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${friend.calories} kcal',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF0F172A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Actions Row
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final fId = friend.friendId.isNotEmpty ? friend.friendId : friend.id;
                                    final res = await ApiService.inviteFriendToChallenge(fId);
                                    if (context.mounted) {
                                      if (res['success'] == true) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Fitness challenge invite sent to ${friend.name}! 👟'),
                                            backgroundColor: AppTheme.accent,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res['error'] ?? 'Failed to send challenge invite'),
                                            backgroundColor: Colors.red.shade600,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accent.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    ),
                                    child: Text(
                                      'Challenge',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    final fId = friend.friendId.isNotEmpty ? friend.friendId : friend.id;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DmScreen(
                                          friendId: fId,
                                          friendName: friend.name,
                                          friendAvatar: friend.avatar,
                                          friendPicUrl: friend.profilePictureUrl,
                                          avatarColor: avatarCol,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                    ),
                                    child: Text(
                                      'Chat',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
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
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTabControl() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: _selectedTab == 0 ? AppTheme.primaryGradient : null,
                      boxShadow: _selectedTab == 0 ? [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 16,
                          color: _selectedTab == 0 ? Colors.white : AppTheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Communities',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 0 ? Colors.white : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: _selectedTab == 1 ? AppTheme.primaryGradient : null,
                      boxShadow: _selectedTab == 1 ? [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: _selectedTab == 1 ? Colors.white : AppTheme.primary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Friends',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 1 ? Colors.white : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMeshBackground(),
        SingleChildScrollView(
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                            ),
                            child: const Icon(Icons.notifications_none_rounded, color: AppTheme.primary, size: 22),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _showCreateGroupDialog,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                            ),
                            child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 24),
                          ),
                        ),
                      ],
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

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80.0),
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_selectedTab == 0) ...[
                // Communities tab content
                StaggeredListItem(
                  index: 2,
                  animationController: _entryAnimController,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _filterGroups(),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                          decoration: InputDecoration(
                            hintText: 'Search communities, challenges...',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.black38, size: 22),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Group Filter Chips (All, Public, Private)
                StaggeredListItem(
                  index: 3,
                  animationController: _entryAnimController,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 0),
                      const SizedBox(width: 8),
                      _buildFilterChip('Public', 1),
                      const SizedBox(width: 8),
                      _buildFilterChip('Private 🔒', 2),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showCreateGroupDialog,
                        child: Text(
                          '+ Create',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w800,
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
                            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                            color: Colors.white.withOpacity(0.6),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accent.withOpacity(0.18),
                                      AppTheme.accent.withOpacity(0.04),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
                                ),
                                child: const Icon(Icons.groups_rounded, color: AppTheme.accent, size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Communities Found',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  fontSize: 18,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try a different search or\ncreate your own community.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showCreateGroupDialog,
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: Text(
                                  'Create Community',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
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
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final bool isSelected = _groupFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _groupFilterIndex = index;
          _filterGroups();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primary.withOpacity(0.7),
          ),
        ),
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
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
              color: Colors.white.withOpacity(0.6),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            displayColor.withOpacity(0.18),
                            displayColor.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: displayColor.withOpacity(0.25), width: 1.5),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      displayColor.withOpacity(0.12),
                                      displayColor.withOpacity(0.04),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: displayColor.withOpacity(0.2)),
                                ),
                                child: Text(
                                  group.tag,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: displayColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.memberCount} members',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  group.desc,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4, fontWeight: FontWeight.w500),
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
                          gradient: group.isJoined ? null : AppTheme.primaryGradient,
                          color: group.isJoined ? Colors.white.withOpacity(0.5) : null,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: group.isJoined ? const Color(0xFFE2E8F0) : AppTheme.accent.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: group.isJoined ? null : [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Text(
                          group.isJoined ? 'Leave' : 'Join Group',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: group.isJoined ? AppTheme.primary.withOpacity(0.7) : Colors.white,
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
      final color = _getAvatarColor(i);
      items.add(
        Positioned(
          left: i * 18.0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Center(
              child: Text(
                initials[i],
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Center(
              child: Text(
                extraCount,
                style: GoogleFonts.inter(
                  color: const Color(0xFF475569),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: (initials.length + (extraCount.isNotEmpty ? 1 : 0)) * 18.0 + 10.0,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
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
