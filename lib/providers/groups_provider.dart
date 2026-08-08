import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../screens/groups_tab.dart';

class GroupsState {
  final List<GroupItem> groups;
  final List<FriendItem> friends;
  final List<Map<String, dynamic>> friendRequests;
  final List<Map<String, dynamic>> challenges;
  final bool isLoading;
  final String? error;

  const GroupsState({
    this.groups = const [],
    this.friends = const [],
    this.friendRequests = const [],
    this.challenges = const [],
    this.isLoading = false,
    this.error,
  });

  GroupsState copyWith({
    List<GroupItem>? groups,
    List<FriendItem>? friends,
    List<Map<String, dynamic>>? friendRequests,
    List<Map<String, dynamic>>? challenges,
    bool? isLoading,
    String? error,
  }) {
    return GroupsState(
      groups: groups ?? this.groups,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      challenges: challenges ?? this.challenges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GroupsNotifier extends StateNotifier<GroupsState> {
  GroupsNotifier() : super(const GroupsState());

  /// Initial load from server/cache
  Future<void> fetchAllData({bool showLoading = true}) async {
    if (showLoading && state.groups.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final results = await Future.wait([
        ApiService.getGroups(),
        ApiService.getFriends(),
        ApiService.getPendingFriendRequests(),
      ]);

      final groupsRes = results[0];
      final friendsRes = results[1];
      final requestsRes = results[2];

      List<GroupItem> parsedGroups = [];
      if (groupsRes['success'] == true && groupsRes['data'] is List) {
        parsedGroups = (groupsRes['data'] as List).map((g) => GroupItem.fromJson(g as Map<String, dynamic>)).toList();
      }

      List<FriendItem> parsedFriends = [];
      if (friendsRes['success'] == true && friendsRes['data'] is List) {
        parsedFriends = (friendsRes['data'] as List).map((f) => FriendItem.fromJson(f as Map<String, dynamic>)).toList();
      }

      List<Map<String, dynamic>> parsedRequests = [];
      if (requestsRes['success'] == true && requestsRes['data'] is List) {
        parsedRequests = (requestsRes['data'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }

      state = state.copyWith(
        groups: parsedGroups,
        friends: parsedFriends,
        friendRequests: parsedRequests,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('GroupsNotifier fetch error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// INSTANT (0ms) Optimistic Group Leave
  Future<bool> leaveGroupOptimistic(String groupId) async {
    final originalGroups = state.groups;
    final groupIndex = originalGroups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return false;

    final targetGroup = originalGroups[groupIndex];
    final updatedGroup = targetGroup.copyWith(
      isJoined: false,
      memberCount: (targetGroup.memberCount - 1).clamp(0, 999999),
    );

    // 1. Emit updated state INSTANTLY (0ms latency UI update)
    final updatedList = List<GroupItem>.from(originalGroups);
    updatedList[groupIndex] = updatedGroup;
    state = state.copyWith(groups: updatedList);

    // 2. Perform network call in background
    try {
      final res = await ApiService.leaveGroup(groupId);
      if (res['success'] == true) {
        // Silently sync latest data in background
        fetchAllData(showLoading: false);
        return true;
      } else {
        // Rollback on failure
        state = state.copyWith(groups: originalGroups);
        return false;
      }
    } catch (e) {
      // Rollback on network error
      state = state.copyWith(groups: originalGroups);
      return false;
    }
  }

  /// INSTANT (0ms) Optimistic Group Join
  Future<bool> joinGroupOptimistic(String groupId) async {
    final originalGroups = state.groups;
    final groupIndex = originalGroups.indexWhere((g) => g.id == groupId);
    if (groupIndex == -1) return false;

    final targetGroup = originalGroups[groupIndex];
    final updatedGroup = targetGroup.copyWith(
      isJoined: true,
      memberCount: targetGroup.memberCount + 1,
    );

    // 1. Emit updated state INSTANTLY
    final updatedList = List<GroupItem>.from(originalGroups);
    updatedList[groupIndex] = updatedGroup;
    state = state.copyWith(groups: updatedList);

    // 2. Perform network call in background
    try {
      final res = await ApiService.joinGroup(groupId);
      if (res['success'] == true) {
        fetchAllData(showLoading: false);
        return true;
      } else {
        state = state.copyWith(groups: originalGroups);
        return false;
      }
    } catch (e) {
      state = state.copyWith(groups: originalGroups);
      return false;
    }
  }

  /// INSTANT (0ms) Accept Friend Request
  Future<bool> acceptFriendRequestOptimistic(String requestId, Map<String, dynamic> userDetails) async {
    final originalRequests = state.friendRequests;
    final originalFriends = state.friends;

    // Remove from pending requests instantly
    final updatedRequests = originalRequests.where((r) => (r['id'] ?? r['request_id']) != requestId).toList();
    
    // Add to friends list instantly
    final newFriend = FriendItem(
      id: userDetails['id'] ?? '',
      name: userDetails['name'] ?? 'Friend',
      avatarUrl: userDetails['avatar_url'],
      activity: 'Connected',
    );
    final updatedFriends = [newFriend, ...originalFriends];

    state = state.copyWith(friendRequests: updatedRequests, friends: updatedFriends);

    try {
      final res = await ApiService.acceptFriendRequest(requestId);
      if (res['success'] == true) {
        fetchAllData(showLoading: false);
        return true;
      } else {
        state = state.copyWith(friendRequests: originalRequests, friends: originalFriends);
        return false;
      }
    } catch (e) {
      state = state.copyWith(friendRequests: originalRequests, friends: originalFriends);
      return false;
    }
  }

  /// Add new group locally instantly after creation
  void addGroupOptimistic(GroupItem group) {
    state = state.copyWith(groups: [group, ...state.groups]);
    fetchAllData(showLoading: false);
  }
}

final groupsProvider = StateNotifierProvider<GroupsNotifier, GroupsState>((ref) {
  return GroupsNotifier();
});
