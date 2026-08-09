import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/preferences_helper.dart';

class ProfileState {
  final String name;
  final String username;
  final int age;
  final String? profilePictureUrl;
  final int activeDays;
  final int mealsScanned;
  final String avgTarget;
  final bool isLoading;
  final bool isUploading;
  final String? error;

  const ProfileState({
    this.name = 'Guest User',
    this.username = 'guest_user',
    this.age = 25,
    this.profilePictureUrl,
    this.activeDays = 0,
    this.mealsScanned = 0,
    this.avgTarget = '0%',
    this.isLoading = false,
    this.isUploading = false,
    this.error,
  });

  ProfileState copyWith({
    String? name,
    String? username,
    int? age,
    String? profilePictureUrl,
    int? activeDays,
    int? mealsScanned,
    String? avgTarget,
    bool? isLoading,
    bool? isUploading,
    String? error,
  }) {
    return ProfileState(
      name: name ?? this.name,
      username: username ?? this.username,
      age: age ?? this.age,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      activeDays: activeDays ?? this.activeDays,
      mealsScanned: mealsScanned ?? this.mealsScanned,
      avgTarget: avgTarget ?? this.avgTarget,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
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
    String usernameTemp = await PreferencesHelper.readString('profile_username') ?? 'guest_user';
    final String? ageStr = await PreferencesHelper.readString('profile_age');
    int ageTemp = ageStr != null ? (int.tryParse(ageStr) ?? 0) : (await PreferencesHelper.readInt('profile_age') ?? 0);
    String? picTemp = await PreferencesHelper.readString('profile_pic_url');

    int mealsCount = 0;
    int activeDays = 0;

    try {
      if (ApiService.isAuthenticated) {
        final res = await ApiService.getProfile();
        if (res['success'] == true) {
          final data = res['data'];
          final String? serverName = data['name'];
          final String? serverUsername = data['username'];
          final String? serverPic = data['profile_picture_url'];

          if (serverName != null && serverName.isNotEmpty && serverName != 'Guest User') {
            nameTemp = serverName;
          }
          if (serverUsername != null && serverUsername.isNotEmpty) {
            usernameTemp = serverUsername;
          }
          if (serverPic != null && serverPic.isNotEmpty) {
            picTemp = serverPic;
          }
          ageTemp = data['age'] ?? ageTemp;

          await PreferencesHelper.saveString('profile_name', nameTemp);
          await PreferencesHelper.saveString('profile_username', usernameTemp);
          await PreferencesHelper.saveInt('profile_age', ageTemp);
          if (picTemp != null) {
            await PreferencesHelper.saveString('profile_pic_url', picTemp);
          }

          // Sync all calculation engine metrics to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('profile_bmi', (data['bmi'] as num?)?.toDouble() ?? 0.0);
          await prefs.setString('profile_bmi_category', data['bmi_category'] ?? 'Healthy');
          await prefs.setDouble('profile_bmr', (data['bmr'] as num?)?.toDouble() ?? 0.0);
          await prefs.setDouble('profile_tdee', (data['tdee'] as num?)?.toDouble() ?? 0.0);
          
          await prefs.setDouble('profile_calorie_goal', (data['target_calories'] as num?)?.toDouble() ?? 2000.0);
          await prefs.setDouble('profile_protein_goal', (data['protein_target'] as num?)?.toDouble() ?? 130.0);
          await prefs.setDouble('profile_carbs_goal', (data['carb_target'] as num?)?.toDouble() ?? 250.0);
          await prefs.setDouble('profile_fats_goal', (data['fat_target'] as num?)?.toDouble() ?? 65.0);
          await prefs.setDouble('profile_fiber_goal', (data['fiber_target'] as num?)?.toDouble() ?? 28.0);
          await prefs.setDouble('profile_water_goal', (data['water_target'] as num?)?.toDouble() ?? 2500.0);

          // Sync personal parameters to secure PreferencesHelper
          if (data['height_cm'] != null) {
            await PreferencesHelper.saveDouble('profile_height', (data['height_cm'] as num).toDouble());
          }
          if (data['current_weight'] != null) {
            await PreferencesHelper.saveDouble('profile_weight', (data['current_weight'] as num).toDouble());
          }
          if (data['target_weight'] != null) {
            await PreferencesHelper.saveDouble('profile_target_weight', (data['target_weight'] as num).toDouble());
          }
          if (data['goal'] != null) {
            await PreferencesHelper.saveString('profile_goal', data['goal']);
            await PreferencesHelper.saveString('profile_goals', data['goal']);
          }
          if (data['activity_level'] != null) {
            await PreferencesHelper.saveString('profile_activity_level', data['activity_level']);
          }
          if (data['gender'] != null) {
            await PreferencesHelper.saveString('profile_gender', data['gender']);
          }
          if (data['age'] != null) {
            await PreferencesHelper.saveString('profile_age', data['age'].toString());
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
        username: usernameTemp,
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
    state = state.copyWith(isUploading: true, error: null);
    try {
      if (ApiService.isAuthenticated) {
        final res = await ApiService.updateProfilePicture(imagePath);
        if (res['success'] == true) {
          final url = res['url'];
          state = state.copyWith(profilePictureUrl: url, isUploading: false);
          await PreferencesHelper.saveString('profile_pic_url', url);
        } else {
          throw Exception(res['error'] ?? 'Upload failed');
        }
      } else {
        state = state.copyWith(profilePictureUrl: imagePath, isUploading: false);
        await PreferencesHelper.saveString('profile_pic_url', imagePath);
      }
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      rethrow;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});
