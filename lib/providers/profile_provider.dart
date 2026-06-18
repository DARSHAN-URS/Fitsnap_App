import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/preferences_helper.dart';

class ProfileState {
  final String name;
  final int age;
  final String? profilePictureUrl;
  final int activeDays;
  final int mealsScanned;
  final String avgTarget;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.name = 'Guest User',
    this.age = 25,
    this.profilePictureUrl,
    this.activeDays = 0,
    this.mealsScanned = 0,
    this.avgTarget = '0%',
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    String? name,
    int? age,
    String? profilePictureUrl,
    int? activeDays,
    int? mealsScanned,
    String? avgTarget,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      name: name ?? this.name,
      age: age ?? this.age,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      activeDays: activeDays ?? this.activeDays,
      mealsScanned: mealsScanned ?? this.mealsScanned,
      avgTarget: avgTarget ?? this.avgTarget,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    String nameTemp = await PreferencesHelper.readString('profile_name') ?? 'Guest User';
    int ageTemp = await PreferencesHelper.readInt('profile_age') ?? 25;
    String? picTemp = await PreferencesHelper.readString('profile_pic_url');

    int mealsCount = 0;
    int activeDays = 0;

    try {
      if (ApiService.isAuthenticated) {
        final res = await ApiService.getProfile();
        if (res['success'] == true) {
          final data = res['data'];
          final String? serverName = data['name'];
          final String? serverPic = data['profile_picture_url'];

          if (serverName != null && serverName.isNotEmpty && serverName != 'Guest User') {
            nameTemp = serverName;
          }
          if (serverPic != null && serverPic.isNotEmpty) {
            picTemp = serverPic;
          }
          ageTemp = data['age'] ?? ageTemp;

          await PreferencesHelper.saveString('profile_name', nameTemp);
          await PreferencesHelper.saveInt('profile_age', ageTemp);
          if (picTemp != null) {
            await PreferencesHelper.saveString('profile_pic_url', picTemp);
          }
        }

        // Fetch meals count
        final mealsRes = await ApiService.getMeals();
        if (mealsRes['success'] == true) {
          mealsCount = (mealsRes['data'] as List).length;
        }

        // Fetch workouts count
        final workoutsRes = await ApiService.getWorkouts();
        if (workoutsRes['success'] == true) {
          final List<dynamic> workouts = workoutsRes['data'];
          final uniqueDays = workouts.map((w) {
            final dateStr = w['completed_at'] as String?;
            return dateStr != null ? dateStr.split('T')[0] : null;
          }).where((d) => d != null).toSet();
          activeDays = uniqueDays.length;
        }
      }

      if (activeDays == 0) {
        final List<String> rawWorkouts = await PreferencesHelper.readStringList('workout_history') ?? [];
        activeDays = rawWorkouts.length;
      }

      final String avgTargetVal = activeDays > 0 || mealsCount > 0 ? '90%' : '0%';

      state = ProfileState(
        name: nameTemp,
        age: ageTemp,
        profilePictureUrl: picTemp,
        activeDays: activeDays,
        mealsScanned: mealsCount,
        avgTarget: avgTargetVal,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfilePicture(String imagePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (ApiService.isAuthenticated) {
        final res = await ApiService.updateProfilePicture(imagePath);
        if (res['success'] == true) {
          final url = res['url'];
          state = state.copyWith(profilePictureUrl: url, isLoading: false);
          await PreferencesHelper.saveString('profile_pic_url', url);
        } else {
          throw Exception(res['error'] ?? 'Upload failed');
        }
      } else {
        state = state.copyWith(profilePictureUrl: imagePath, isLoading: false);
        await PreferencesHelper.saveString('profile_pic_url', imagePath);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});
