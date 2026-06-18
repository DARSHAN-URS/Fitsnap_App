import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class BadgeState {
  final int streakDays;
  final List<String> earnedBadges;
  final List<String> activeDates;
  final String lastActiveDate;

  BadgeState({
    this.streakDays = 0,
    this.earnedBadges = const [],
    this.activeDates = const [],
    this.lastActiveDate = '',
  });

  BadgeState copyWith({
    int? streakDays,
    List<String>? earnedBadges,
    List<String>? activeDates,
    String? lastActiveDate,
  }) {
    return BadgeState(
      streakDays: streakDays ?? this.streakDays,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      activeDates: activeDates ?? this.activeDates,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }
}

class BadgeNotifier extends StateNotifier<BadgeState> {
  BadgeNotifier() : super(BadgeState()) {
    updateStreakDaily();
  }

  Future<void> updateStreakDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final lastActive = prefs.getString('last_active_date') ?? '';
    List<String> activeDates = prefs.getStringList('active_dates') ?? [];
    int currentStreak = prefs.getInt('streak_days') ?? 0;

    if (lastActive.isEmpty) {
      // First show up!
      currentStreak = 1;
      activeDates = [todayStr];
      await prefs.setString('last_active_date', todayStr);
      await prefs.setStringList('active_dates', activeDates);
      await prefs.setInt('streak_days', currentStreak);
    } else if (lastActive != todayStr) {
      final lastActiveDate = DateTime.parse(lastActive);
      final todayDate = DateTime.parse(todayStr);
      final difference = todayDate.difference(lastActiveDate).inDays;

      if (difference == 1) {
        // Active on consecutive day!
        currentStreak += 1;
        if (!activeDates.contains(todayStr)) {
          activeDates.add(todayStr);
        }
      } else if (difference > 1) {
        // Streak broken
        currentStreak = 1;
        if (!activeDates.contains(todayStr)) {
          activeDates.add(todayStr);
        }
      }
      
      await prefs.setString('last_active_date', todayStr);
      await prefs.setStringList('active_dates', activeDates);
      await prefs.setInt('streak_days', currentStreak);
    } else {
      // Same day, just ensure activeDates contains today
      if (!activeDates.contains(todayStr)) {
        activeDates.add(todayStr);
        await prefs.setStringList('active_dates', activeDates);
      }
    }

    // Load earned badges or initialize with default
    List<String> earned = prefs.getStringList('earned_badges') ?? ['First Log'];
    if (currentStreak >= 3 && !earned.contains('3 Day Streak')) {
      earned.add('3 Day Streak');
    }
    if (currentStreak >= 7 && !earned.contains('7 Day Streak')) {
      earned.add('7 Day Streak');
    }
    await prefs.setStringList('earned_badges', earned);

    // Update state
    state = BadgeState(
      streakDays: currentStreak,
      earnedBadges: earned,
      activeDates: activeDates,
      lastActiveDate: todayStr,
    );

    // Run checkRequirements to award new badges based on activity metrics
    checkRequirements();
  }

  Future<void> checkRequirements() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('home_steps') ?? 0;
    final water = prefs.getInt('home_water') ?? 0;
    
    // Check if there are logged meals
    int mealsCount = 0;
    final String? mealsJson = prefs.getString('dashboard_meals');
    if (mealsJson != null && mealsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(mealsJson);
        mealsCount = decoded.length;
      } catch (_) {}
    }

    List<String> newBadges = List.from(state.earnedBadges);
    
    // First Log
    if (!newBadges.contains('First Log')) {
      newBadges.add('First Log');
    }
    // Step Master
    if (steps >= 10000 && !newBadges.contains('Step Master')) {
      newBadges.add('Step Master');
    }
    // Hydration Hero
    if (water >= 2500 && !newBadges.contains('Hydration Hero')) {
      newBadges.add('Hydration Hero');
    }
    // Macro Maestro
    if (mealsCount > 0 && !newBadges.contains('Macro Maestro')) {
      newBadges.add('Macro Maestro');
    }
    // 3 Day Streak
    if (state.streakDays >= 3 && !newBadges.contains('3 Day Streak')) {
      newBadges.add('3 Day Streak');
    }
    // 7 Day Streak
    if (state.streakDays >= 7 && !newBadges.contains('7 Day Streak')) {
      newBadges.add('7 Day Streak');
    }

    if (newBadges.length != state.earnedBadges.length) {
      state = state.copyWith(earnedBadges: newBadges);
      await prefs.setStringList('earned_badges', newBadges);
    }
  }

  Future<void> logActivity() async {
    await updateStreakDaily();
  }
}

final badgeProvider = StateNotifierProvider<BadgeNotifier, BadgeState>((ref) {
  return BadgeNotifier();
});
