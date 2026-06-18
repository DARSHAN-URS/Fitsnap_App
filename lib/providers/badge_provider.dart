import 'package:flutter_riverpod/flutter_riverpod.dart';

class BadgeState {
  final int streakDays;
  final List<String> earnedBadges;

  BadgeState({this.streakDays = 0, this.earnedBadges = const []});

  BadgeState copyWith({int? streakDays, List<String>? earnedBadges}) {
    return BadgeState(
      streakDays: streakDays ?? this.streakDays,
      earnedBadges: earnedBadges ?? this.earnedBadges,
    );
  }
}

class BadgeNotifier extends StateNotifier<BadgeState> {
  BadgeNotifier() : super(BadgeState()) {
    _loadBadges();
  }

  void _loadBadges() async {
    // In a real app, this would load from a local db or backend
    state = BadgeState(
      streakDays: 3,
      earnedBadges: ['First Log', '3 Day Streak'],
    );
  }

  void logActivity() {
    // Increment streak logic, add badges logic
    int newStreak = state.streakDays + 1;
    List<String> newBadges = List.from(state.earnedBadges);
    if (newStreak == 7 && !newBadges.contains('7 Day Streak')) {
      newBadges.add('7 Day Streak');
    }
    state = state.copyWith(streakDays: newStreak, earnedBadges: newBadges);
  }
}

final badgeProvider = StateNotifierProvider<BadgeNotifier, BadgeState>((ref) {
  return BadgeNotifier();
});
