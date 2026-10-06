import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/preferences_helper.dart';
import 'notifications_screen.dart';

class MyCoachTab extends StatefulWidget {
  const MyCoachTab({super.key});

  @override
  State<MyCoachTab> createState() => _MyCoachTabState();
}

class _MyCoachTabState extends State<MyCoachTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool _hasCoach = false;
  int _selectedCoachTabSection = 0; // 0: Search & Connect, 1: My Coaches
  bool _userInteractedWithTab = false;
  List<Map<String, dynamic>> _coaches = [];
  String? _selectedCoachId;
  Map<String, dynamic>? _coach;
  Map<String, dynamic>? _client;
  Map<String, dynamic>? _todayPlan;
  Map<String, dynamic>? _assignedProgram;
  final Set<String> _finishedMealKeys = {};
  final Set<String> _finishedWorkoutKeys = {};
  Map<String, dynamic>? _adherence;
  List<dynamic> _feedbacks = [];
  List<dynamic> _availableCoaches = [];
  List<dynamic> _recommendedCoaches = [];
  Map<String, dynamic>? _pendingInvitation;

  // SabCoach Inbox
  List<Map<String, dynamic>> _sabcoachUpdates = [];
  int _unreadCoachingCount = 0;

  // Quick-stat toggles
  bool _showDisconnectConfirm = false;
  Timer? _pollTimer;

  final TextEditingController _coachSearchController = TextEditingController();
  final TextEditingController _coachLocationController = TextEditingController();
  String _coachSearchQuery = '';
  String _coachLocationQuery = '';
  String _selectedCoachSpecialty = 'All';
  String _selectedLocationFilter = 'All';
  bool _showExploreMoreCoaches = false;
  final Map<String, String> _feedbackReactions = {};

  final Set<String> _loggedMealNames = {};
  late AnimationController _animController;
  bool _isConnecting = false;

  // Location
  bool _isLoadingLocation = false;
  bool _isLoadingCoaches = false;

  // Scroll controller to fix keyboard glitch
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _locationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _refreshAll();
    // Light background poll every 5 min so inbox badge stays fresh
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _loadSabcoachUpdates();
    });
  }

  Future<void> _refreshAll() async {
    final prefCoachId = await PreferencesHelper.readString('connected_coach_id');
    final prefClientId = await PreferencesHelper.readString('connected_client_id');
    await _loadCoachData(coachId: prefCoachId, clientId: prefClientId);
    if (mounted) {
      await _loadSabcoachUpdates();
    }
    if (mounted) {
      await _loadAvailableCoaches();
    }
  }

  Future<void> _loadAvailableCoaches({
    String? query,
    String? location,
    String? discipline,
  }) async {
    setState(() => _isLoadingCoaches = true);
    try {
      final res = await ApiService.getAvailableCoaches(
        query: query,
        location: location,
        discipline: discipline != null && discipline != 'All' ? discipline : null,
      );
      if (mounted && res['success'] == true) {
        final serverCoaches = (res['coaches'] is List)
            ? List<dynamic>.from(res['coaches'])
            : <dynamic>[];
        final serverRec = (res['recommended_coaches'] is List)
            ? List<dynamic>.from(res['recommended_coaches'])
            : <dynamic>[];
        setState(() {
          _availableCoaches = serverCoaches;
          _recommendedCoaches = serverRec;
        });
      } else if (mounted) {
        setState(() {
          _availableCoaches = [];
          _recommendedCoaches = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading available coaches: $e');
      if (mounted) {
        setState(() {
          _availableCoaches = [];
          _recommendedCoaches = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCoaches = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable in settings.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Use reverse geocoding via a simple readable coordinate string
      // We'll use city name approximation from coordinates
      final lat = position.latitude;
      final lon = position.longitude;
      // Set coordinates as location query so backend can use it
      // For now we set a user-readable label and search
      final locationLabel = 'Near Me (${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)})';

      _coachLocationController.text = locationLabel;
      setState(() => _coachLocationQuery = locationLabel);

      // Reload coaches with approximate location (pass lat/lon as location)
      await _loadAvailableCoaches(
        query: _coachSearchQuery.isNotEmpty ? _coachSearchQuery : null,
        location: '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Searching coaches near your location...'),
              ],
            ),
            backgroundColor: AppTheme.neonEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: \${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadSabcoachUpdates() async {
    try {
      final res = await ApiService.getNotifications();
      if (res['success'] == true && res['data'] != null) {
        final List<dynamic> all = res['data'];
        // Filter to coaching-related notification types only
        const coachingTypes = {
          'coaching_request',
          'coaching_accepted',
          'coaching_declined',
          'program_assigned',
          'program_shared',
          'coach_feedback',
        };
        final filtered = all
            .whereType<Map>()
            .where((n) {
              final type = n['type'] ?? n['notif_type'];
              if (!coachingTypes.contains(type)) return false;
              final extraData = (n['extra_data'] ?? n['data']) as Map? ?? {};
              final status = extraData['status']?.toString().toLowerCase();
              final bool responded = extraData['responded'] == true || status == 'accepted' || status == 'declined';
              // If it's a coaching_request that is already responded or read or if the user is already connected to coach, don't show pending invitation
              if (type == 'coaching_request' && (responded || n['is_read'] == true || _hasCoach)) {
                return false;
              }
              return true;
            })
            .map((n) => Map<String, dynamic>.from(n))
            .toList();
        if (mounted) {
          setState(() {
            _sabcoachUpdates = filtered;
            _unreadCoachingCount = filtered.where((n) => n['is_read'] != true).length;
          });
        }

        // Auto-link coach if an accepted coaching notification is present in inbox
        if (!_hasCoach && mounted) {
          final acceptedNotif = filtered.firstWhere(
            (n) {
              final t = (n['type'] ?? n['notif_type'] ?? '').toString();
              final ed = (n['extra_data'] ?? n['data']) as Map? ?? {};
              final st = (ed['status'] ?? '').toString().toLowerCase();
              final title = (n['title'] ?? '').toString().toLowerCase();
              return t == 'coaching_accepted' || st == 'accepted' || title.contains('accepted');
            },
            orElse: () => {},
          );
          if (acceptedNotif.isNotEmpty) {
            final ed = (acceptedNotif['extra_data'] ?? acceptedNotif['data']) as Map? ?? {};
            final cId = (ed['client_id'] ?? acceptedNotif['client_id'] ?? '').toString();
            final coachId = (ed['coach_id'] ?? acceptedNotif['coach_id'] ?? '').toString();
            if (cId.isNotEmpty) {
              await PreferencesHelper.saveString('connected_client_id', cId);
            }
            if (coachId.isNotEmpty) {
              await PreferencesHelper.saveString('connected_coach_id', coachId);
            }
            await _loadCoachData(
              coachId: coachId.isNotEmpty ? coachId : null,
              clientId: cId.isNotEmpty ? cId : null,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading SabCoach updates: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animController.dispose();
    _coachSearchController.dispose();
    _coachLocationController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCoachData({String? coachId, String? clientId}) async {
    setState(() => _isLoading = true);
    try {
      final effectiveCoachId = coachId ?? await PreferencesHelper.readString('connected_coach_id');
      final effectiveClientId = clientId ?? await PreferencesHelper.readString('connected_client_id');
      final res = await ApiService.getMyCoach(coachId: effectiveCoachId, clientId: effectiveClientId);
      if (res['success'] == true) {
        final List<dynamic> rawCoaches = res['coaches'] is List ? res['coaches'] : [];
        final List<Map<String, dynamic>> coachesList = rawCoaches
            .whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList();

        final bool hasCoach = res['has_coach'] == true || coachesList.isNotEmpty || res['coach'] != null;
        final targetCoachId = effectiveCoachId ??
            res['selected_coach_id']?.toString() ??
            _selectedCoachId ??
            (coachesList.isNotEmpty ? coachesList.first['coach_id']?.toString() : null);

        Map<String, dynamic>? selectedBundle;
        if (coachesList.isNotEmpty) {
          selectedBundle = coachesList.firstWhere(
            (c) => c['coach_id']?.toString() == targetCoachId,
            orElse: () => coachesList.first,
          );
        }

        setState(() {
          _hasCoach = hasCoach;
          _coaches = coachesList;
          _selectedCoachId = selectedBundle?['coach_id']?.toString() ?? targetCoachId;
          _coach = selectedBundle?['coach'] != null
              ? Map<String, dynamic>.from(selectedBundle!['coach'])
              : (res['coach'] != null ? Map<String, dynamic>.from(res['coach']) : null);
          _client = selectedBundle?['client'] != null
              ? Map<String, dynamic>.from(selectedBundle!['client'])
              : (res['client'] != null ? Map<String, dynamic>.from(res['client']) : null);
          _todayPlan = selectedBundle?['today_plan'] != null
              ? Map<String, dynamic>.from(selectedBundle!['today_plan'])
              : (res['today_plan'] != null ? Map<String, dynamic>.from(res['today_plan']) : null);
          _assignedProgram = selectedBundle?['assigned_program'] != null
              ? Map<String, dynamic>.from(selectedBundle!['assigned_program'])
              : (res['assigned_program'] != null ? Map<String, dynamic>.from(res['assigned_program']) : null);
          _adherence = selectedBundle?['adherence'] != null
              ? Map<String, dynamic>.from(selectedBundle!['adherence'])
              : (res['adherence'] != null ? Map<String, dynamic>.from(res['adherence']) : null);
          _feedbacks = selectedBundle?['feedbacks'] is List
              ? List.from(selectedBundle!['feedbacks'])
              : (res['feedbacks'] is List ? List.from(res['feedbacks']) : []);
          final rawAvail = (res['available_coaches'] is List)
              ? List.from(res['available_coaches'])
              : (_availableCoaches.isNotEmpty ? _availableCoaches : <dynamic>[]);
          final rawRec = (res['recommended_coaches'] is List)
              ? List.from(res['recommended_coaches'])
              : (_recommendedCoaches.isNotEmpty ? _recommendedCoaches : <dynamic>[]);
          _availableCoaches = rawAvail;
          _recommendedCoaches = rawRec;
          if (_hasCoach) {
            _pendingInvitation = null;
          } else {
            _pendingInvitation = res['pending_invitation'] != null ? Map<String, dynamic>.from(res['pending_invitation']) : null;
          }
          if (!_userInteractedWithTab) {
            _selectedCoachTabSection = (_hasCoach && _coaches.isNotEmpty) ? 1 : 0;
          }
          _isLoading = false;
        });

        if (_selectedCoachId != null) {
          PreferencesHelper.saveString('connected_coach_id', _selectedCoachId!);
        }
        if (_client?['id'] != null) {
          PreferencesHelper.saveString('connected_client_id', _client!['id'].toString());
        }
        _loadPresenceState();
        _animController.forward(from: 0.0);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading coach data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _switchCoach(String targetCoachId) {
    if (_selectedCoachId == targetCoachId) return;
    HapticFeedback.selectionClick();
    final matchedBundle = _coaches.firstWhere(
      (c) => c['coach_id']?.toString() == targetCoachId,
      orElse: () => {},
    );
    if (matchedBundle.isNotEmpty) {
      setState(() {
        _selectedCoachId = targetCoachId;
        _coach = matchedBundle['coach'] != null ? Map<String, dynamic>.from(matchedBundle['coach']) : null;
        _client = matchedBundle['client'] != null ? Map<String, dynamic>.from(matchedBundle['client']) : null;
        _todayPlan = matchedBundle['today_plan'] != null ? Map<String, dynamic>.from(matchedBundle['today_plan']) : null;
        _assignedProgram = matchedBundle['assigned_program'] != null ? Map<String, dynamic>.from(matchedBundle['assigned_program']) : null;
        _adherence = matchedBundle['adherence'] != null ? Map<String, dynamic>.from(matchedBundle['adherence']) : null;
        _feedbacks = matchedBundle['feedbacks'] is List ? List.from(matchedBundle['feedbacks']) : [];
      });
      PreferencesHelper.saveString('connected_coach_id', targetCoachId);
      if (matchedBundle['client_id'] != null) {
        PreferencesHelper.saveString('connected_client_id', matchedBundle['client_id'].toString());
      }
      _loadPresenceState();
    } else {
      _loadCoachData(coachId: targetCoachId);
    }
  }

  IconData _getDisciplineIcon(String discipline) {
    final d = discipline.toLowerCase();
    if (d.contains('nutrition') || d.contains('diet')) return Icons.restaurant_menu_rounded;
    if (d.contains('yoga') || d.contains('mobility') || d.contains('stretch')) return Icons.self_improvement_rounded;
    if (d.contains('cardio') || d.contains('endurance') || d.contains('run')) return Icons.directions_run_rounded;
    if (d.contains('physio') || d.contains('rehab')) return Icons.healing_rounded;
    return Icons.fitness_center_rounded;
  }

  Future<void> _loadPresenceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final cid = _client?['id']?.toString() ?? 'client';

      final savedMeals = prefs.getStringList('presence_meals_${cid}_$todayStr') ?? [];
      final savedWorkouts = prefs.getStringList('presence_workouts_${cid}_$todayStr') ?? [];

      if (mounted) {
        setState(() {
          _finishedMealKeys.clear();
          _finishedMealKeys.addAll(savedMeals);
          _finishedWorkoutKeys.clear();
          _finishedWorkoutKeys.addAll(savedWorkouts);
        });
      }

      // Sync with backend telemetry
      final remote = await ApiService.getPresence(clientId: cid, date: todayStr);
      if (remote['success'] == true) {
        final rMeals = (remote['completed_meals'] as List? ?? []).map((e) => e.toString()).toList();
        final rWorkouts = (remote['completed_workouts'] as List? ?? []).map((e) => e.toString()).toList();
        if (mounted) {
          setState(() {
            _finishedMealKeys.addAll(rMeals);
            _finishedWorkoutKeys.addAll(rWorkouts);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleMealPresence(String mealKey, Map<String, dynamic> meal) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final cid = _client?['id']?.toString() ?? 'client';

    final willFinish = !_finishedMealKeys.contains(mealKey);
    final String mealName = (meal['name'] ?? (meal['foods'] is List && (meal['foods'] as List).isNotEmpty ? meal['foods'][0]['name'] : meal['slot_name'] ?? 'Prescribed Meal')).toString();

    setState(() {
      if (willFinish) {
        _finishedMealKeys.add(mealKey);
        _loggedMealNames.add(mealName);
      } else {
        _finishedMealKeys.remove(mealKey);
      }
    });

    await prefs.setStringList('presence_meals_${cid}_$todayStr', _finishedMealKeys.toList());

    // Record presence to backend
    ApiService.recordPresence(
      clientId: cid,
      type: 'meal',
      itemKey: mealKey,
      name: mealName,
      completed: willFinish,
      date: todayStr,
    );

    if (willFinish) {
      _logPrescribedMeal(meal, silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Marked "$mealName" as completed! Presence recorded.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.neonEmerald,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  Future<void> _toggleWorkoutPresence(String workoutKey, Map<String, dynamic> workout) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final cid = _client?['id']?.toString() ?? 'client';

    final willFinish = !_finishedWorkoutKeys.contains(workoutKey);
    final String workoutTitle = (workout['name'] ?? workout['title'] ?? 'Workout Session').toString();

    setState(() {
      if (willFinish) {
        _finishedWorkoutKeys.add(workoutKey);
      } else {
        _finishedWorkoutKeys.remove(workoutKey);
      }
    });

    await prefs.setStringList('presence_workouts_${cid}_$todayStr', _finishedWorkoutKeys.toList());

    // Record presence to backend
    ApiService.recordPresence(
      clientId: cid,
      type: 'workout',
      itemKey: workoutKey,
      name: workoutTitle,
      completed: willFinish,
      date: todayStr,
    );

    if (willFinish && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Marked "$workoutTitle" as finished! Presence recorded.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _logPrescribedMeal(Map<String, dynamic> meal, {bool silent = false}) async {
    final String mealName = (meal['name'] ?? (meal['foods'] is List && (meal['foods'] as List).isNotEmpty ? meal['foods'][0]['name'] : meal['slot_name'] ?? 'Prescribed Meal')).toString();
    final int calories = ((meal['target_calories'] ?? meal['calories'] ?? 0) as num).toInt();
    final int protein = ((meal['target_protein'] ?? meal['protein'] ?? 0) as num).toInt();
    final int carbs = ((meal['target_carbs'] ?? meal['carbs'] ?? 0) as num).toInt();
    final int fats = ((meal['target_fats'] ?? meal['fats'] ?? 0) as num).toInt();

    if (!silent) HapticFeedback.mediumImpact();

    // 1. Log to backend API
    await ApiService.logMeal(
      name: mealName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      description: 'Prescribed by Coach: ${meal['slot_name'] ?? meal['slot'] ?? 'Protocol'}',
    );

    // 2. Also save to user-scoped local SharedPreferences so HomeTab immediately reflects it
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    final String? userId = await ApiService.getCurrentUserId();
    final String up = userId != null ? '${userId}_' : '';

    final int currConsumed = prefs.getInt('${up}dashboard_consumed') ?? 0;
    final int currProtein = prefs.getInt('${up}dashboard_protein') ?? 0;
    final int currCarbs = prefs.getInt('${up}dashboard_carbs') ?? 0;
    final int currFats = prefs.getInt('${up}dashboard_fats') ?? 0;

    await prefs.setInt('${up}dashboard_consumed', currConsumed + calories);
    await prefs.setInt('${up}dashboard_protein', currProtein + protein);
    await prefs.setInt('${up}dashboard_carbs', currCarbs + carbs);
    await prefs.setInt('${up}dashboard_fats', currFats + fats);

    await prefs.setInt('${up}dashboard_consumed_$todayStr', currConsumed + calories);
    await prefs.setInt('${up}dashboard_protein_$todayStr', currProtein + protein);
    await prefs.setInt('${up}dashboard_carbs_$todayStr', currCarbs + carbs);
    await prefs.setInt('${up}dashboard_fats_$todayStr', currFats + fats);

    // Append to local meals list
    final String? existingMealsJson = prefs.getString('${up}dashboard_meals');
    List<dynamic> mealsList = [];
    if (existingMealsJson != null) {
      try {
        mealsList = jsonDecode(existingMealsJson);
      } catch (_) {}
    }

    final newMealObj = {
      'name': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'time': meal['time'] ?? 'Today',
      'slot': meal['slot_name'] ?? meal['slot'] ?? 'Meal',
      'tagColor': AppTheme.accent.value,
      'is_coach_prescribed': true,
      'food_items': [
        {
          'food_name': mealName,
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fats,
        }
      ]
    };
    mealsList.add(newMealObj);

    await prefs.setString('${up}dashboard_meals', jsonEncode(mealsList));
    await prefs.setString('${up}dashboard_meals_$todayStr', jsonEncode(mealsList));

    if (mounted) {
      setState(() {
        _loggedMealNames.add(mealName);
      });
    }

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Logged "$mealName" to your daily diary! (+$calories kcal)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.neonEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      // Reload adherence live
      _loadCoachData();
    }
  }

  Future<void> _connectToCoach(String coachId, {String? coachName}) async {
    final cleanId = coachId.trim();
    if (cleanId.isEmpty) return;

    setState(() => _isConnecting = true);
    final res = await ApiService.connectCoach(
      coachId: cleanId,
    );
    setState(() => _isConnecting = false);

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res['message'] ?? 'Successfully connected to ${coachName ?? "coach"}!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.neonEmerald,
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadCoachData(coachId: cleanId);
      await _loadSabcoachUpdates();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Connection failed'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _showInviteCodeDialog() async {
    final TextEditingController inviteController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Enter Coach Invite Code',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.primary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect directly to your coach using their unique SAB invite code.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: inviteController,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppTheme.primary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. SAB-SUNIL',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400, letterSpacing: 0),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = inviteController.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          final res = await ApiService.connectCoach(inviteCode: code);
                          setDialogState(() => isSubmitting = false);
                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                          if (res['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Successfully connected to coach!'),
                                backgroundColor: AppTheme.neonEmerald,
                              ),
                            );
                            await _refreshAll();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['error'] ?? 'Invalid invite code or coach not found'),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Connect', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _respondToPendingInvite(bool accept) async {
    if (_pendingInvitation == null) return;
    final clientId = _pendingInvitation!['id'] ?? '';
    if (clientId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _pendingInvitation = null;
    });
    final res = await ApiService.respondCoachingRequest(
      clientId: clientId,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final coachId = (res['coach']?['id'] ?? res['client']?['coach_id'] ?? '').toString();
      if (accept) {
        if (coachId.isNotEmpty) {
          await PreferencesHelper.saveString('connected_coach_id', coachId);
        }
        await PreferencesHelper.saveString('connected_client_id', clientId);
        if (mounted) {
          setState(() {
            _hasCoach = true;
            if (coachId.isNotEmpty) _selectedCoachId = coachId;
            if (res['coach'] != null) _coach = Map<String, dynamic>.from(res['coach']);
            if (res['client'] != null) _client = Map<String, dynamic>.from(res['client']);
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Coaching request accepted! Connected.' : 'Coaching request declined.'),
            backgroundColor: accept ? AppTheme.neonEmerald : Colors.grey.shade800,
          ),
        );
      }
      await _loadCoachData(coachId: coachId.isNotEmpty ? coachId : null, clientId: clientId);
      if (mounted) await _loadSabcoachUpdates();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Action failed')),
        );
      }
    }
  }

  void _openChatModal() {
    final TextEditingController msgCtrl = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final screenH = MediaQuery.of(context).size.height;
            final double modalHeight = (screenH * 0.75).clamp(300.0, (screenH - bottomInset - 40).clamp(260.0, screenH));
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                height: modalHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Handle & Header
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(
                              _coach?['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _coach?['name'] ?? 'My Coach',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.neonEmerald,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Direct SabCoach Channel',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Chat messages list
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: ApiService.getCoachMessages(
                          coachId: _coach?['id'],
                          clientId: _client?['id'],
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                          }
                          final list = (snapshot.data?['data'] as List?) ?? [];
                          if (list.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.forum_outlined, size: 48, color: AppTheme.accent.withOpacity(0.4)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Start a Conversation',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ask questions about your prescribed diet plan, form execution, or workout intensity.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final item = list[i];
                              final isClient = item['sender'] == 'client';
                              return Align(
                                alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    color: isClient ? AppTheme.accent : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isClient ? 16 : 4),
                                      bottomRight: Radius.circular(isClient ? 4 : 16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['text'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: isClient ? Colors.white : AppTheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isClient ? 'You' : (_coach?['name'] ?? 'Coach'),
                                        style: GoogleFonts.inter(
                                          color: isClient ? Colors.white70 : Colors.black45,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -3)),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: msgCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Message coach...',
                                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            isSending
                                ? const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                                      onPressed: () async {
                                        final txt = msgCtrl.text.trim();
                                        if (txt.isEmpty) return;
                                        setModalState(() => isSending = true);
                                        await ApiService.sendCoachMessage(
                                          text: txt,
                                          coachId: _coach?['id'],
                                          clientId: _client?['id'],
                                        );
                                        msgCtrl.clear();
                                        setModalState(() => isSending = false);
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSectionSwitcher(),
            const SizedBox(height: 18),
            if (_selectedCoachTabSection == 0) ...[
              _buildSearchAndConnectSection(),
            ] else ...[
              _buildConnectedCoachesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Section 1: Search & Connect
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _userInteractedWithTab = true;
                  _selectedCoachTabSection = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedCoachTabSection == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedCoachTabSection == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: _selectedCoachTabSection == 0 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Search & Connect',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedCoachTabSection == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedCoachTabSection == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section 2: Connected Coaches
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _userInteractedWithTab = true;
                  _selectedCoachTabSection = 1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedCoachTabSection == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedCoachTabSection == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: _selectedCoachTabSection == 1 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Coaches',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedCoachTabSection == 1 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedCoachTabSection == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    if (_coaches.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedCoachTabSection == 1 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_coaches.length}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndConnectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Action: Enter Coach Code
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a Coach Invite Code?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    Text(
                      'Connect directly to your coach using their SAB code',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showInviteCodeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Enter Code', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        // Live Directory & Search
        _buildCoachSearchAndFilterSection(),
      ],
    );
  }

  Widget _buildConnectedCoachesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SabCoach Inbox — coaching invitations + updates
        if (_pendingInvitation != null || _sabcoachUpdates.isNotEmpty) ...[
          _buildSabcoachInbox(),
          const SizedBox(height: 20),
        ],
        if (_hasCoach && _coaches.isNotEmpty) ...[
          _buildCoachesSelector(),
          const SizedBox(height: 16),
          _buildCoachProfileCard(),
          const SizedBox(height: 16),
          _buildQuickStatsStrip(),
          const SizedBox(height: 16),

          // Overview banner if no plans sent at all
          if (!_hasNutritionPlan && !_hasWorkoutPlan) ...[
            _buildNoPlansSentBanner(),
            const SizedBox(height: 16),
          ],

          // ── SECTION 1: NUTRITION PLAN (MEALS) ──────────────────────────
          if (_hasNutritionPlan) ...[
            _buildTodayPrescribedPlanCard(),
          ] else ...[
            _buildNoNutritionPlanCard(),
          ],
          const SizedBox(height: 16),

          // ── SECTION 2: WORKOUT PLAN (WORKOUTS & EXERCISES) ──────────────
          if (_hasWorkoutPlan) ...[
            _buildAssignedProgramCard(),
          ] else ...[
            _buildNoWorkoutPlanCard(),
          ],
          const SizedBox(height: 16),

          _buildAdherenceTelemetryCard(),
          const SizedBox(height: 16),
          _buildCoachFeedbackCard(),
          const SizedBox(height: 16),
          _buildDisconnectSection(),
        ] else ...[
          _buildNoConnectedCoachesCard(),
        ],
      ],
    );
  }

  Widget _buildNoPlansSentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF475569), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No plans sent yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your coach has not dispatched today\'s nutrition or workout protocols yet.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoNutritionPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Nutrition Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Prescribed Meals & Timing',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.no_meals_rounded, color: Color(0xFFD97706), size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'No plans sent yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No nutrition plan sent yet by your coach. When your coach prescribes your daily meals and macros, they will appear right here for you to tick.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFFB45309),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWorkoutPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Workout Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Training Routine & Exercises',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_gymnastics_rounded, color: Color(0xFF6366F1), size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'No plans sent yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3730A3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No workout plan sent yet by your coach. Once your coach creates and assigns a training program, your workouts will appear right here for you to tick.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF4338CA),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConnectedCoachesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_rounded, color: Color(0xFF6366F1), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'No Coaches Connected Yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t linked a coach yet. Explore certified specialists in the Search & Connect tab or enter your coach\'s invite code to start streaming telemetry and receiving custom programs.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showInviteCodeDialog,
                  icon: const Icon(Icons.vpn_key_rounded, size: 16),
                  label: Text('Invite Code', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _userInteractedWithTab = true;
                      _selectedCoachTabSection = 0;
                    });
                  },
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text('Find Coaches', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Loading Skeleton ────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmer(width: 130, height: 32, radius: 10),
                  const SizedBox(height: 8),
                  _shimmer(width: 200, height: 14, radius: 7),
                ],
              ),
              _shimmer(width: 44, height: 44, radius: 14),
            ],
          ),
          const SizedBox(height: 24),
          _shimmer(width: double.infinity, height: 140, radius: 22),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmer(width: double.infinity, height: 72, radius: 16)),
          ]),
          const SizedBox(height: 14),
          _shimmer(width: double.infinity, height: 170, radius: 22),
          const SizedBox(height: 14),
          _shimmer(width: double.infinity, height: 220, radius: 22),
        ],
      ),
    );
  }

  Widget _shimmer({required double width, required double height, required double radius}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF1F5F9), value),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Coach',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hasCoach ? AppTheme.neonEmerald : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _hasCoach ? 'SabCoach Live Telemetry Synced' : 'Ready to Connect',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _hasCoach ? AppTheme.neonEmerald : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Notification bell with unread badge (filtered to SabCoach)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen(coachOnly: true)),
                ).then((_) => _refreshAll());
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  if (_unreadCoachingCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          _unreadCoachingCount > 9 ? '9+' : '$_unreadCoachingCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_hasCoach) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openChatModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Chat',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── SabCoach Inbox ──────────────────────────────────────────────────────────
  Widget _buildSabcoachInbox() {
    final items = <Widget>[];

    // 1. Pending coaching invitation from getMyCoach()
    if (_pendingInvitation != null) {
      final inv = _pendingInvitation!;
      final coachName = inv['coach_name'] ?? 'Your Coach';
      final program = inv['program_name'] ?? 'Coaching Protocol';
      final clientId = (inv['id'] ?? '').toString();
      final coachId = (inv['coach_id'] ?? '').toString();
      items.add(_buildInboxItem(
        icon: Icons.mail_outline_rounded,
        color: const Color(0xFF6366F1),
        title: 'Coaching Invitation',
        subtitle: 'From $coachName · $program',
        body: 'Accept to stream live meals, workouts & biometrics to SabCoach and receive personalized protocols.',
        isUnread: true,
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  if (clientId.isNotEmpty) {
                    setState(() {
                      _isLoading = true;
                      _pendingInvitation = null;
                    });
                    await ApiService.respondCoachingRequest(clientId: clientId, accept: false);
                    await _refreshAll();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (clientId.isNotEmpty) {
                    setState(() {
                      _isLoading = true;
                      _pendingInvitation = null;
                    });
                    final res = await ApiService.respondCoachingRequest(
                      clientId: clientId,
                      accept: true,
                      coachId: coachId.isNotEmpty ? coachId : null,
                    );
                    if (res['success'] == true) {
                      if (coachId.isNotEmpty) {
                        await PreferencesHelper.saveString('connected_coach_id', coachId);
                      }
                      await PreferencesHelper.saveString('connected_client_id', clientId);
                      if (mounted) {
                        setState(() {
                          _hasCoach = true;
                          if (coachId.isNotEmpty) _selectedCoachId = coachId;
                          if (res['client'] != null) _client = Map<String, dynamic>.from(res['client']);
                        });
                      }
                    }
                    await _loadCoachData(coachId: coachId.isNotEmpty ? coachId : null, clientId: clientId);
                    if (mounted) await _loadSabcoachUpdates();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Connected! Live telemetry is now streaming to your coach.'),
                          backgroundColor: AppTheme.neonEmerald,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('Accept & Link', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ));
    }

    // 2. Coaching-related notifications from the notification feed
    for (int i = 0; i < _sabcoachUpdates.length; i++) {
      final n = _sabcoachUpdates[i];
      final type = n['type'] as String? ?? '';
      final isUnread = n['is_read'] != true;
      final notifId = (n['id'] ?? '').toString();
      Map<String, dynamic> extraData = {};
      final rawExtra = n['extra_data'] ?? n['data'];
      if (rawExtra is Map) {
        extraData = Map<String, dynamic>.from(rawExtra);
      } else if (rawExtra is String && rawExtra.isNotEmpty) {
        try {
          extraData = Map<String, dynamic>.from(jsonDecode(rawExtra));
        } catch (_) {}
      }
      final clientId = (extraData['client_id'] ?? n['client_id'] ?? '').toString();
      final coachId = (extraData['coach_id'] ?? n['coach_id'] ?? '').toString();
      final coachName = (extraData['coach_name'] ?? n['coach_name'] ?? 'Your Coach').toString();

      Color itemColor;
      IconData itemIcon;
      switch (type) {
        case 'coaching_request':
          itemColor = const Color(0xFF6366F1);
          itemIcon = Icons.sports_rounded;
          break;
        case 'coaching_accepted':
          itemColor = AppTheme.neonEmerald;
          itemIcon = Icons.verified_user_rounded;
          break;
        case 'coaching_declined':
          itemColor = const Color(0xFF94A3B8);
          itemIcon = Icons.cancel_outlined;
          break;
        case 'program_assigned':
        case 'program_shared':
          itemColor = const Color(0xFF10B981);
          itemIcon = Icons.fitness_center_rounded;
          break;
        case 'coach_feedback':
          itemColor = const Color(0xFF06B6D4);
          itemIcon = Icons.rate_review_rounded;
          break;
        default:
          itemColor = AppTheme.accent;
          itemIcon = Icons.notifications_rounded;
      }

      Widget? actionWidget;
      if (type == 'coaching_request' && clientId.isNotEmpty) {
        actionWidget = Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  setState(() {
                    _sabcoachUpdates.removeAt(i);
                    _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
                  });
                  await ApiService.respondCoachingRequest(
                    clientId: clientId,
                    accept: false,
                    coachId: coachId.isNotEmpty ? coachId : null,
                  );
                  if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);
                  await _refreshAll();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _pendingInvitation = null;
                    _sabcoachUpdates.removeAt(i);
                    _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
                  });
                  final res = await ApiService.respondCoachingRequest(
                    clientId: clientId,
                    accept: true,
                    coachId: coachId.isNotEmpty ? coachId : null,
                  );
                  if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);

                  final resolvedCoachId = coachId.isNotEmpty
                      ? coachId
                      : (res['coach']?['id'] ?? res['client']?['coach_id'] ?? '').toString();
                  if (resolvedCoachId.isNotEmpty) {
                    await PreferencesHelper.saveString('connected_coach_id', resolvedCoachId);
                  }
                  await PreferencesHelper.saveString('connected_client_id', clientId);
                  if (mounted) {
                    setState(() {
                      _hasCoach = true;
                      if (resolvedCoachId.isNotEmpty) _selectedCoachId = resolvedCoachId;
                      if (res['coach'] != null) _coach = Map<String, dynamic>.from(res['coach']);
                      if (res['client'] != null) _client = Map<String, dynamic>.from(res['client']);
                    });
                  }

                  await _loadCoachData(coachId: resolvedCoachId.isNotEmpty ? resolvedCoachId : null, clientId: clientId);
                  if (mounted) await _loadSabcoachUpdates();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Connected with $coachName! SabCoach telemetry link is live.'),
                        backgroundColor: AppTheme.neonEmerald,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: Text('Accept & Connect', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ],
        );
      } else if (type == 'coaching_accepted' || extraData['status'] == 'accepted' || (n['title'] ?? '').toString().contains('Accepted')) {
        actionWidget = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (clientId.isNotEmpty) {
                await PreferencesHelper.saveString('connected_client_id', clientId);
              }
              if (coachId.isNotEmpty) {
                await PreferencesHelper.saveString('connected_coach_id', coachId);
              }
              if (notifId.isNotEmpty) {
                await ApiService.markNotificationRead(notifId);
              }
              setState(() {
                _hasCoach = true;
                if (coachId.isNotEmpty) _selectedCoachId = coachId;
              });
              await _loadCoachData(coachId: coachId.isNotEmpty ? coachId : null, clientId: clientId.isNotEmpty ? clientId : null);
              if (mounted) {
                _openChatModal();
              }
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
            label: Text('Open Coach & Start Chat', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonEmerald,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      } else if (type == 'program_assigned' || type == 'program_shared') {
        actionWidget = SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (notifId.isNotEmpty) await ApiService.markNotificationRead(notifId);
              _loadSabcoachUpdates();
            },
            icon: const Icon(Icons.fitness_center_rounded, size: 15),
            label: Text('View in My Coach', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }

      items.add(_buildInboxItem(
        icon: itemIcon,
        color: itemColor,
        title: n['title'] ?? 'SabCoach Update',
        subtitle: type == 'coach_feedback'
            ? 'Coach Feedback'
            : type == 'coaching_accepted'
                ? 'Request Accepted'
                : type == 'coaching_declined'
                    ? 'Request Declined'
                    : type.replaceAll('_', ' ').toUpperCase(),
        body: n['body'] ?? '',
        isUnread: isUnread,
        actions: actionWidget,
        onTap: () async {
          if (isUnread && notifId.isNotEmpty) {
            await ApiService.markNotificationRead(notifId);
            setState(() {
              _sabcoachUpdates[i]['is_read'] = true;
              _unreadCoachingCount = _sabcoachUpdates.where((x) => x['is_read'] != true).length;
            });
          }
          if (type == 'coaching_accepted' || extraData['status'] == 'accepted' || (n['title'] ?? '').toString().contains('Accepted')) {
            if (clientId.isNotEmpty) await PreferencesHelper.saveString('connected_client_id', clientId);
            if (coachId.isNotEmpty) await PreferencesHelper.saveString('connected_coach_id', coachId);
            setState(() => _hasCoach = true);
            await _loadCoachData(coachId: coachId.isNotEmpty ? coachId : null, clientId: clientId.isNotEmpty ? clientId : null);
            if (mounted) _openChatModal();
          }
        },
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inbox_rounded, color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'SabCoach Inbox',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
                if (_unreadCoachingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_unreadCoachingCount new',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen(coachOnly: true)),
                ).then((_) => _refreshAll());
              },
              child: Text(
                'See All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildInboxItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String body,
    required bool isUnread,
    Widget? actions,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnread ? color.withOpacity(0.28) : const Color(0xFFE2E8F0),
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ],
            if (actions != null) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvitationCard() {
    final inv = _pendingInvitation!;
    final coachName = inv['coach_name'] ?? 'Your Coach';
    final program = inv['program_name'] ?? 'Coaching Protocol';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coaching Invitation Received!',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'From $coachName • $program',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Accept this invitation to stream live meals, workouts, and biometrics to SabCoach and receive custom daily nutrition protocols.',
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToPendingInvite(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToPendingInvite(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Accept & Link', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasAssignedProgram {
    final progName = _client?['program_name']?.toString() ?? _assignedProgram?['name']?.toString();
    return progName != null &&
        progName.isNotEmpty &&
        progName != 'Not Assigned' &&
        progName != 'Standard Protocol' &&
        progName != 'None' &&
        progName != 'null';
  }

  bool get _hasNutritionPlan {
    if (_todayPlan == null) return false;
    final meals = _todayPlan!['meals'];
    if (meals is List && meals.isNotEmpty) return true;
    final cals = _todayPlan!['total_calories'] ?? _todayPlan!['calories'];
    return cals != null && (cals as num) > 0;
  }

  bool get _hasWorkoutPlan => _hasAssignedProgram;

  // ── Quick Stats Strip ──────────────────────────────────────────────────────
  Widget _buildQuickStatsStrip() {
    final adh = _adherence ?? {};
    final double score = ((adh['adherence_percentage'] ?? 92.0) as num).toDouble();
    final int streak = ((adh['streak_days'] ?? _client?['streak_days'] ?? 0) as num).toInt();
    final int sessions = ((adh['sessions_this_week'] ?? _client?['sessions_this_week'] ?? 0) as num).toInt();

    return Row(
      children: [
        _buildStatTile('${score.toInt()}%', 'Adherence', Icons.bolt_rounded, const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        _buildStatTile('${streak}d', 'Streak', Icons.local_fire_department_rounded, const Color(0xFFF97316)),
        const SizedBox(width: 10),
        _buildStatTile('$sessions', 'Sessions', Icons.fitness_center_rounded, AppTheme.neonEmerald),
      ],
    );
  }

  Widget _buildStatTile(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedProgramCard() {
    final progName = _client?['program_name'] ?? _assignedProgram?['name'] ?? 'Training Protocol';
    final progDetail = (_client?['program_detail'] as Map?) ?? (_assignedProgram?['detail'] as Map?) ?? {};
    final weekCurrent = progDetail['weekCurrent'] ?? 1;
    final weekTotal = progDetail['weekTotal'] ?? 12;
    final workoutsThisWeek = progDetail['workoutsThisWeek'] ?? '4 sessions/week';
    final targetSummary = progDetail['targetSummary'] ?? 'Periodized progressive overload program.';

    List<dynamic> progWorkouts = (_assignedProgram?['workouts'] as List?) ?? (progDetail['workouts'] as List?) ?? [];

    if (progWorkouts.isEmpty) {
      // Standard prescribed sessions for the active program
      progWorkouts = [
        {
          'id': 'wo_1',
          'name': 'Day 1: Upper Body Push & Core',
          'category': 'Chest & Shoulders',
          'duration': '50 min',
          'exercises': [
            {'name': 'Incline Dumbbell Press', 'sets': 4, 'reps': '8-10', 'weight': '32 kg'},
            {'name': 'Overhead Shoulder Press', 'sets': 3, 'reps': '10-12', 'weight': '24 kg'},
            {'name': 'Tricep Cable Pushdowns', 'sets': 3, 'reps': '12-15', 'weight': '25 kg'},
            {'name': 'Hanging Knee Raises', 'sets': 3, 'reps': '15 reps', 'weight': 'Bodyweight'},
          ]
        },
        {
          'id': 'wo_2',
          'name': 'Day 2: Lower Body Power & Hips',
          'category': 'Quads & Glutes',
          'duration': '55 min',
          'exercises': [
            {'name': 'Barbell Back Squat', 'sets': 4, 'reps': '6-8', 'weight': '85 kg'},
            {'name': 'Romanian Deadlift', 'sets': 3, 'reps': '8-10', 'weight': '70 kg'},
            {'name': 'Walking Lunges', 'sets': 3, 'reps': '12 / leg', 'weight': '16 kg dumbbells'},
            {'name': 'Standing Calf Raises', 'sets': 4, 'reps': '15 reps', 'weight': '50 kg'},
          ]
        },
        {
          'id': 'wo_3',
          'name': 'Day 3: Upper Body Pull & Posterior Chain',
          'category': 'Back & Biceps',
          'duration': '45 min',
          'exercises': [
            {'name': 'Neutral Grip Pull-ups', 'sets': 4, 'reps': '8-10', 'weight': 'Bodyweight'},
            {'name': 'Chest-Supported Row', 'sets': 3, 'reps': '10-12', 'weight': '30 kg'},
            {'name': 'Face Pulls', 'sets': 3, 'reps': '15 reps', 'weight': '17.5 kg'},
            {'name': 'Incline Dumbbell Curls', 'sets': 3, 'reps': '10-12', 'weight': '14 kg'},
          ]
        },
        {
          'id': 'wo_4',
          'name': 'Day 4: Functional Conditioning & Engine',
          'category': 'Full Body & Core',
          'duration': '40 min',
          'exercises': [
            {'name': 'Kettlebell Swings', 'sets': 4, 'reps': '20 reps', 'weight': '24 kg'},
            {'name': 'Rowing Intervals', 'sets': 5, 'reps': '500m sprint', 'weight': 'Level 6'},
            {'name': 'Plank to Push-up', 'sets': 3, 'reps': '12 reps', 'weight': 'Bodyweight'},
          ]
        },
      ];
    }

    int completedCount = 0;
    for (int i = 0; i < progWorkouts.length; i++) {
      final w = progWorkouts[i] is Map ? progWorkouts[i] : {};
      final wKey = 'wo_${w['id'] ?? i}_${w['name'] ?? ''}';
      if (_finishedWorkoutKeys.contains(wKey)) {
        completedCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Gradient
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.fitness_center_rounded, color: AppTheme.neonEmerald, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Workout Plan',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              progName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neonEmerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.neonEmerald.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Week $weekCurrent of $weekTotal',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonEmerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppTheme.neonCyan, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$workoutsThisWeek • $targetSummary',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Workout routines header with finished counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prescribed Routines & Exercises',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: completedCount > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$completedCount of ${progWorkouts.length} Finished',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: completedCount > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // List of workout cards with presence check
          ...progWorkouts.asMap().entries.map((entry) {
            final int idx = entry.key;
            final Map<String, dynamic> w = Map<String, dynamic>.from(entry.value is Map ? entry.value : {});
            final String wName = (w['name'] ?? w['title'] ?? 'Workout ${idx + 1}').toString();
            final String wCategory = (w['category'] ?? w['day'] ?? 'Training').toString();
            final String wDuration = (w['duration'] ?? '45 min').toString();
            final List<dynamic> wExercises = (w['exercises'] as List?) ?? [];
            final String wKey = 'wo_${w['id'] ?? idx}_$wName';
            final bool isFinished = _finishedWorkoutKeys.contains(wKey);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFinished ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFinished ? AppTheme.neonEmerald.withOpacity(0.5) : const Color(0xFFE2E8F0),
                  width: isFinished ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                wCategory.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              wDuration,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      // Presence Tick Button
                      InkWell(
                        onTap: () => _toggleWorkoutPresence(wKey, w),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isFinished ? const Color(0xFFD1FAE5) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFinished ? AppTheme.neonEmerald : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFinished ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isFinished ? AppTheme.neonEmerald : const Color(0xFF94A3B8),
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFinished ? 'Finished ✓' : 'Mark Finished',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isFinished ? const Color(0xFF065F46) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppTheme.primary,
                      decoration: isFinished ? TextDecoration.lineThrough : null,
                    ),
                  ),

                  // Exercises breakdown
                  if (wExercises.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...wExercises.map((ex) {
                      final exMap = ex is Map ? ex : {};
                      final exName = exMap['name'] ?? 'Exercise';
                      final sets = exMap['sets'] != null ? '${exMap['sets']} sets' : '';
                      final reps = exMap['reps'] != null ? '${exMap['reps']}' : '';
                      final weight = exMap['weight'] != null ? '• ${exMap['weight']}' : '';
                      final spec = [sets, reps, weight].where((s) => s.isNotEmpty).join(' ');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isFinished ? AppTheme.neonEmerald : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                exName,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            if (spec.isNotEmpty)
                              Text(
                                spec,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
          // Coach Workout Notes / Instructions banner if provided
          Builder(
            builder: (context) {
              final progNotes = (progDetail['notes'] ??
                      progDetail['instructions'] ??
                      progDetail['coach_notes'] ??
                      _assignedProgram?['notes'] ??
                      _assignedProgram?['instructions'] ??
                      '')
                  .toString()
                  .trim();
              if (progNotes.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coach Workout Notes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: const Color(0xFF3730A3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progNotes,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF4338CA),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Multiple Coaches Selector ─────────────────────────────────────────────
  Widget _buildCoachesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Color(0xFF6366F1), size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'YOUR COACHING TEAM',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_coaches.length} Active',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showAddCoachModal,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Add Coach',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _coaches.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == _coaches.length) {
                return GestureDetector(
                  onTap: _showAddCoachModal,
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+ Add Coach',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = _coaches[index];
              final coachObj = (item['coach'] as Map?) ?? {};
              final coachId = (item['coach_id'] ?? coachObj['id'] ?? '').toString();
              final coachName = coachObj['name'] ?? 'Coach';
              final discipline = (item['discipline'] ?? coachObj['specialty'] ?? 'Coaching').toString();
              final avatar = coachObj['avatar']?.toString() ?? '';
              final isSelected = _selectedCoachId == coachId;

              return GestureDetector(
                onTap: () => _switchCoach(coachId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 185,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : const Color(0xFFE2E8F0),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.black.withOpacity(0.02),
                        blurRadius: isSelected ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isSelected ? AppTheme.accent.withOpacity(0.3) : const Color(0xFFF1F5F9),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Icon(
                                    _getDisciplineIcon(discipline),
                                    size: 18,
                                    color: isSelected ? Colors.white : AppTheme.accent,
                                  )
                                : null,
                          ),
                          if (isSelected)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppTheme.neonEmerald,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              coachName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppTheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              discipline,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppTheme.neonCyan : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddCoachModal() {
    bool modalConnecting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Another Coach',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  'Connect a Nutritionist, Physio, or Trainer',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Certified Specialists Directory',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect in real-time to start streaming biometrics and receive programs',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            if (_availableCoaches.isNotEmpty)
                              ..._availableCoaches.map((c) {
                                final cMap = Map<String, dynamic>.from(c as Map);
                                final cId = (cMap['id'] ?? '').toString();
                                final cName = (cMap['name'] ?? 'Coach').toString();
                                final cSpec = (cMap['specialty'] ?? cMap['discipline'] ?? 'Specialist').toString();
                                final cLoc = (cMap['location'] ?? 'Remote').toString();
                                final cRating = (cMap['rating'] ?? 4.9).toDouble();
                                final cAvatar = (cMap['avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200').toString();
                                final alreadyAdded = _coaches.any((x) => x['coach_id'] == cId);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage: NetworkImage(cAvatar),
                                        backgroundColor: AppTheme.accent.withOpacity(0.1),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    cName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF3B82F6)),
                                              ],
                                            ),
                                            Text(
                                              cSpec,
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.accent,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFFE11D48)),
                                                const SizedBox(width: 2),
                                                Text(cLoc, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 2),
                                                Text(cRating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: alreadyAdded || modalConnecting
                                            ? null
                                            : () async {
                                                setModalState(() => modalConnecting = true);
                                                final res = await ApiService.connectCoach(coachId: cId);
                                                setModalState(() => modalConnecting = false);
                                                if (res['success'] == true) {
                                                  if (ctx.mounted) Navigator.pop(ctx);
                                                  await _refreshAll();
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: alreadyAdded ? Colors.grey.shade400 : AppTheme.accent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Text(
                                          alreadyAdded ? 'Linked' : 'Connect',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No coaches currently available.'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoachProfileCard() {
    final name = _coach?['name'] ?? 'Coach';
    final title = _coach?['title'] ?? 'Performance & Nutrition Coach';
    final specialty = _coach?['specialty'] ?? 'Hypertrophy & Metabolic Health';
    final avatar = _coach?['avatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';
    final rating = (_coach?['rating'] ?? 4.95).toString();
    final certs = (_coach?['certifications'] as List?) ?? ['ISSA Master Trainer', 'Nutrition Specialist'];
    final since = _client?['created_at'] != null
        ? (() {
            try {
              final dt = DateTime.parse(_client!['created_at'].toString());
              return 'Since ${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {
              return 'Active';
            }
          })()
        : 'Active';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Gradient hero banner
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.35), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.neonEmerald,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          specialty,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFCD34D)),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _openChatModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'Chat',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Certs + since row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'Connected · $since',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: certs.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          c.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disconnect Section ──────────────────────────────────────────────────────
  Widget _buildDisconnectSection() {
    if (!_showDisconnectConfirm) {
      return GestureDetector(
        onTap: () => setState(() => _showDisconnectConfirm = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                'Disconnect from Coach',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Text(
            'Are you sure you want to disconnect?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF991B1B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Your coach will lose access to your live telemetry stream.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFFB91C1C),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDisconnectConfirm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final currentCoachId = _selectedCoachId;
                    setState(() {
                      _coaches.removeWhere((c) => c['coach_id']?.toString() == currentCoachId);
                      if (_coaches.isNotEmpty) {
                        final nextCoach = _coaches.first;
                        _selectedCoachId = nextCoach['coach_id']?.toString();
                        _coach = nextCoach['coach'] != null ? Map<String, dynamic>.from(nextCoach['coach']) : null;
                        _client = nextCoach['client'] != null ? Map<String, dynamic>.from(nextCoach['client']) : null;
                        _todayPlan = nextCoach['today_plan'] != null ? Map<String, dynamic>.from(nextCoach['today_plan']) : null;
                        _adherence = nextCoach['adherence'] != null ? Map<String, dynamic>.from(nextCoach['adherence']) : null;
                        _feedbacks = nextCoach['feedbacks'] is List ? List.from(nextCoach['feedbacks']) : [];
                      } else {
                        _hasCoach = false;
                        _coach = null;
                        _client = null;
                        _todayPlan = null;
                        _feedbacks = [];
                        _selectedCoachId = null;
                      }
                      _showDisconnectConfirm = false;
                    });
                    if (_selectedCoachId != null) {
                      await PreferencesHelper.saveString('connected_coach_id', _selectedCoachId!);
                    } else {
                      await PreferencesHelper.delete('connected_coach_id');
                      await PreferencesHelper.delete('connected_client_id');
                    }
                    await _loadCoachData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text('Disconnect', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceTelemetryCard() {
    final adh = _adherence ?? {};
    final double adherenceScore = ((adh['adherence_percentage'] ?? 92.0) as num).toDouble();
    final String status = adh['status'] ?? 'Optimal Adherence';
    final prescribed = adh['prescribed'] as Map? ?? {};
    final actual = adh['actual'] as Map? ?? {};

    final int targetCal = ((prescribed['calories'] ?? _todayPlan?['total_calories'] ?? 2250) as num).toInt();
    final int actualCal = ((actual['calories'] ?? 0) as num).toInt();
    final double targetProt = ((prescribed['protein'] ?? _todayPlan?['protein_g'] ?? 165.0) as num).toDouble();
    final double actualProt = ((actual['protein'] ?? 0.0) as num).toDouble();
    final double targetCarbs = ((prescribed['carbs'] ?? _todayPlan?['carbs_g'] ?? 240.0) as num).toDouble();
    final double actualCarbs = ((actual['carbs'] ?? 0.0) as num).toDouble();
    final double targetFats = ((prescribed['fats'] ?? _todayPlan?['fats_g'] ?? 65.0) as num).toDouble();
    final double actualFats = ((actual['fats'] ?? 0.0) as num).toDouble();

    double pct(double a, double t) => t > 0 ? (a / t).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1A2744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.neonCyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.neonCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Live Telemetry',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.neonEmerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonEmerald.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.neonEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: GoogleFonts.inter(
                        color: AppTheme.neonEmerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Score ring + calorie info
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: pct(adherenceScore, 100),
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${adherenceScore.toInt()}%',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Score',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calorie Compliance',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$actualCal kcal',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'of $targetCal',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct(actualCal.toDouble(), targetCal.toDouble()),
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Macro progress bars
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMacroBar('Protein', actualProt, targetProt, const Color(0xFF818CF8)),
                const SizedBox(height: 10),
                _buildMacroBar('Carbs', actualCarbs, targetCarbs, AppTheme.neonCyan),
                const SizedBox(height: 10),
                _buildMacroBar('Fats', actualFats, targetFats, const Color(0xFFF472B6)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Your coach monitors every logged plate in real time to fine-tune your macro targets.',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, double actual, double target, Color color) {
    final pct = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;
    final over = actual > target && target > 0;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(over ? const Color(0xFFFBBF24) : color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${actual.toInt()}/${target.toInt()}g',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: over ? const Color(0xFFFBBF24) : Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayPrescribedPlanCard() {
    final plan = _todayPlan ?? {};
    final title = plan['title'] ?? 'Prescribed Daily Protocol';
    final desc = plan['description'] ?? 'Target nutrition designed for optimal recomposition.';
    final meals = (plan['meals'] as List?) ?? [];
    final supps = (plan['supplements'] as List?) ?? [];
    final instructions = (plan['instructions'] ?? plan['notes'] ?? plan['coach_notes'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Prescribed Protocol',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plan['total_calories'] ?? 2250} kcal',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Dispatched for ${plan['target_date'] ?? 'Today'} · Live from SabCoach',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 16),
          // Macro goals row
          _buildMacroSummaryRow(plan),
          const SizedBox(height: 20),
          // Prescribed Meals with Finished Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prescribed Meals & Timing',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Builder(
                builder: (context) {
                  int completedMealCount = 0;
                  for (int i = 0; i < meals.length; i++) {
                    final m = meals[i] is Map ? meals[i] : {};
                    final mFoods = (m['foods'] as List?) ?? [];
                    final mName = (m['name'] ?? (mFoods.isNotEmpty && mFoods[0] is Map ? mFoods[0]['name'] : m['slot_name'] ?? '')).toString();
                    final mKey = 'meal_${m['id'] ?? i}_${m['slot_name'] ?? m['slot'] ?? ''}_$mName';
                    if (_finishedMealKeys.contains(mKey) || _loggedMealNames.contains(mName)) {
                      completedMealCount++;
                    }
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedMealCount > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: completedMealCount > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      '$completedMealCount of ${meals.length} Finished',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: completedMealCount > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (meals.isEmpty)
            Text(
              'No specific meal slots prescribed for today yet.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            )
          else
            ...meals.asMap().entries.map((entry) => _buildMealSlotItem(Map<String, dynamic>.from(entry.value as Map), index: entry.key)),
          
          if (supps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Prescribed Supplements',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: supps.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.neonEmerald, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coach Instructions',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instructions,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF78350F),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroSummaryRow(Map<String, dynamic> plan) {
    final protein = (plan['protein_g'] ?? 165) as num;
    final carbs = (plan['carbs_g'] ?? 240) as num;
    final fats = (plan['fats_g'] ?? 65) as num;
    final water = (plan['water_liters'] ?? 3.5) as num;

    final targets = [
      _MacroGoal('Protein', '${protein.toInt()}g', const Color(0xFF818CF8), Icons.egg_outlined),
      _MacroGoal('Carbs', '${carbs.toInt()}g', const Color(0xFF06B6D4), Icons.rice_bowl_outlined),
      _MacroGoal('Fats', '${fats.toInt()}g', const Color(0xFFF472B6), Icons.opacity_rounded),
      _MacroGoal('Water', '${water}L', const Color(0xFF10B981), Icons.water_drop_outlined),
    ];

    return Row(
      children: targets.asMap().entries.map((e) {
        final t = e.value;
        final isLast = e.key == targets.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(t.icon, color: t.color, size: 18),
                const SizedBox(height: 6),
                Text(
                  t.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: t.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMealSlotItem(Map<String, dynamic> meal, {int index = 0}) {
    final foods = (meal['foods'] as List?) ?? [];
    final name = (meal['name'] ?? (foods.isNotEmpty && foods[0] is Map ? foods[0]['name'] : meal['slot_name'] ?? 'Prescribed Meal')).toString();
    final slot = (meal['slot_name'] ?? meal['slot'] ?? 'Meal').toString();
    final time = (meal['time'] ?? '').toString();
    final cals = ((meal['target_calories'] ?? meal['calories'] ?? 0) as num).toInt();
    final prot = ((meal['target_protein'] ?? meal['protein'] ?? 0) as num).toDouble();
    final ingredients = (meal['ingredients'] ?? '').toString();
    final notes = (meal['instructions'] ?? meal['notes'] ?? '').toString();

    final mealKey = 'meal_${meal['id'] ?? index}_${slot}_$name';
    final isTicked = _finishedMealKeys.contains(mealKey) || _loggedMealNames.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTicked ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTicked ? AppTheme.neonEmerald.withOpacity(0.5) : const Color(0xFFE2E8F0),
          width: isTicked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      slot.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
              // Presence Tick Button
              InkWell(
                onTap: () => _toggleMealPresence(mealKey, meal),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isTicked ? const Color(0xFFD1FAE5) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isTicked ? AppTheme.neonEmerald : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTicked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTicked ? AppTheme.neonEmerald : const Color(0xFF94A3B8),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isTicked ? 'Finished ✓' : 'Mark Finished',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isTicked ? const Color(0xFF065F46) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppTheme.primary,
                    decoration: isTicked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                '$cals kcal${prot > 0 ? ' • ${prot.toInt()}g P' : ''}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...foods.map((f) {
              final fMap = f is Map ? f : {};
              final fName = fMap['name'] ?? '';
              final fPortion = fMap['portion'] ?? '';
              final fCals = fMap['calories'];
              if (fName.toString().isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$fName${fPortion.toString().isNotEmpty ? ' (${fPortion.toString()})' : ''}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                      ),
                    ),
                    if (fCals != null)
                      Text(
                        '$fCals kcal',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              );
            }),
          ] else if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ingredients,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Coach note: $notes',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF0369A1),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoachFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFF06B6D4), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Coach Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              if (_feedbacks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_feedbacks.length} notes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0891B2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_feedbacks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFCBD5E1), size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Awaiting Coach Feedback',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep logging your meals & workouts. Your coach will review your data and leave feedback soon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
                  ),
                ],
              ),
            )
          else
            ..._feedbacks.map((fb) {
              final text = (fb['feedback_text'] ?? fb['text'] ?? '').toString();
              final rating = (fb['rating'] ?? 'great').toString().toLowerCase();
              final date = (fb['date'] ?? 'Today').toString();
              final ratingColor = rating == 'great'
                  ? const Color(0xFF059669)
                  : rating == 'needs_work'
                      ? const Color(0xFFD97706)
                      : const Color(0xFF0891B2);
              final ratingBg = rating == 'great'
                  ? const Color(0xFFECFDF5)
                  : rating == 'needs_work'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0F7FA);
              final ratingIcon = rating == 'great'
                  ? Icons.thumb_up_rounded
                  : rating == 'needs_work'
                      ? Icons.trending_up_rounded
                      : Icons.info_outline_rounded;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ratingBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ratingColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ratingIcon, color: ratingColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          rating.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: ratingColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          date,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildReactionChip(fb, '💪 Thanks!'),
                        const SizedBox(width: 6),
                        _buildReactionChip(fb, '🔥 On it!'),
                        const Spacer(),
                        InkWell(
                          onTap: _openChatModal,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReactionChip(dynamic fb, String label) {
    final key = (fb['id'] ?? fb['feedback_text'] ?? '').toString();
    final isSelected = _feedbackReactions[key] == label;
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _feedbackReactions.remove(key);
          } else {
            _feedbackReactions[key] = label;
          }
        });
        if (!isSelected) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reaction "$label" sent to your coach!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.white.withOpacity(0.6),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingInvitation != null) ...[
          _buildPendingInvitationCard(),
          const SizedBox(height: 20),
        ],
        // Hero banner - Compact, sleek & low vertical footprint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'SABCOACH ECOSYSTEM',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.white60,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE SYNC',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Real-Time Coach Accountability',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Meals, workouts & biometrics stream live to your coach.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Action: Enter Coach Code
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a Coach Invite Code?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
                    ),
                    Text(
                      'Link your personal coach profile instantly',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showInviteCodeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Enter Code', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 Suggested Coaches of different types
        _buildRecommendedCoachesSection(),
        const SizedBox(height: 24),

        // Search Tab with location, name/specialty, and filters
        _buildCoachSearchAndFilterSection(),
      ],
    );
  }

  // ── 3 Recommended Coaches of Different Types ──────────────────────────────
  Widget _buildRecommendedCoachesSection() {
    final top3 = _getTop3RecommendedCoaches();
    if (top3.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested Coaches',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      '3 Top Specialists of Distinct Disciplines',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text(
                    'CURATED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...top3.asMap().entries.map((entry) {
          final idx = entry.key;
          final coach = entry.value;
          return _buildRecommendedCoachCard(coach, rank: idx + 1);
        }),
      ],
    );
  }

  Widget _buildRecommendedCoachCard(Map<String, dynamic> coach, {required int rank}) {
    final name = (coach['name'] ?? 'Coach').toString();
    final title = (coach['title'] ?? 'Performance Specialist').toString();
    final specialty = (coach['specialty'] ?? coach['discipline'] ?? 'Coaching').toString();
    final location = (coach['location'] ?? 'Remote / Online').toString();
    final locationType = (coach['location_type'] ?? '').toString();
    final bio = (coach['bio'] ?? '').toString();
    final avatar = (coach['avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400').toString();
    final rating = (coach['rating'] ?? 4.9).toDouble();
    final reviewCount = coach['review_count'] ?? 45;
    final activeClients = coach['active_clients'] ?? 15;
    final hourlyRate = (coach['hourly_rate'] ?? '').toString();
    final certs = coach['certifications'] is List ? List<String>.from(coach['certifications']) : <String>[];
    final coachId = (coach['id'] ?? '').toString();
    final alreadyConnected = _coaches.any((c) => c['coach_id'] == coachId);

    final Color badgeColor;
    final IconData badgeIcon;
    final String disciplineTag;

    final norm = _normalizeDiscipline(specialty);
    if (norm == 'Nutrition & Dietetics') {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.restaurant_menu_rounded;
      disciplineTag = 'NUTRITION & METABOLISM';
    } else if (norm == 'Yoga & Mobility') {
      badgeColor = const Color(0xFF8B5CF6);
      badgeIcon = Icons.self_improvement_rounded;
      disciplineTag = 'YOGA & MOBILITY';
    } else if (norm == 'Cardio & Endurance') {
      badgeColor = const Color(0xFFF97316);
      badgeIcon = Icons.directions_run_rounded;
      disciplineTag = 'CARDIO & ENDURANCE';
    } else if (norm == 'Physio & Rehab') {
      badgeColor = const Color(0xFF06B6D4);
      badgeIcon = Icons.healing_rounded;
      disciplineTag = 'PHYSIO & REHAB';
    } else {
      badgeColor = const Color(0xFF4F46E5);
      badgeIcon = Icons.fitness_center_rounded;
      disciplineTag = 'STRENGTH & CONDITIONING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badgeColor.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openCoachDetailsModal(coach),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: badgeColor, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            disciplineTag,
                            style: GoogleFonts.inter(
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hourlyRate.isNotEmpty)
                      Text(
                        hourlyRate,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Coach Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF3B82F6)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(2),
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.people_alt_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '$activeClients athletes',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFE11D48)),
                      const SizedBox(width: 5),
                      Text(
                        locationType.isNotEmpty ? '$location • $locationType' : location,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ],
                if (certs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: certs.take(2).map((cert) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cert,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => _openCoachDetailsModal(coach),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: Text(
                          'View Profile',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: alreadyConnected || _isConnecting
                            ? null
                            : () => _connectToCoach(coachId, coachName: name),
                        icon: Icon(alreadyConnected ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 16),
                        label: Text(
                          alreadyConnected ? 'Connected' : 'Connect Coach',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alreadyConnected ? Colors.grey.shade400 : badgeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
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

  // ── Search & Filter Coaches Directory ──────────────────────────────────────
  Widget _buildCoachSearchAndFilterSection() {
    final filtered = _filteredCoaches;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search & Filter Coaches',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Filter by location, discipline, or keyword',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filtered.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Keyword / Name Search
          TextField(
            controller: _coachSearchController,
            focusNode: _searchFocusNode,
            onChanged: (val) {
              setState(() => _coachSearchQuery = val);
            },
            onSubmitted: (val) {
              _locationFocusNode.requestFocus();
            },
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search coach name, specialty (e.g. Strength, Diet)...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6366F1)),
              suffixIcon: _coachSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _coachSearchController.clear();
                        setState(() => _coachSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Location Search Bar with Use Current Location button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coachLocationController,
                  focusNode: _locationFocusNode,
                  onChanged: (val) => setState(() => _coachLocationQuery = val),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: GoogleFonts.inter(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'City, State or "Remote"...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFFE11D48)),
                    suffixIcon: _coachLocationQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _coachLocationController.clear();
                              setState(() => _coachLocationQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Use Current Location Button
              Tooltip(
                message: 'Use current location',
                child: Material(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isLoadingLocation ? null : _getCurrentLocation,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Location Type Quick Chips (All / Remote / In-Person & Hybrid)
          Row(
            children: [
              Text('Format:', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Remote', 'In-Person / Hybrid'].map((locType) {
                      final isSel = _selectedLocationFilter == locType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            locType,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFFE11D48),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          onSelected: (_) => setState(() => _selectedLocationFilter = locType),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Discipline / Type Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                'Strength & Conditioning',
                'Nutrition & Dietetics',
                'Yoga & Mobility',
                'Cardio & Endurance',
                'Physio & Rehab'
              ].map((tag) {
                final isSel = _selectedCoachSpecialty == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      tag,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: isSel ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                    ),
                    onSelected: (_) => setState(() => _selectedCoachSpecialty = tag),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Active filter indicator / reset
          if (_coachSearchQuery.isNotEmpty || _coachLocationQuery.isNotEmpty || _selectedCoachSpecialty != 'All' || _selectedLocationFilter != 'All')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters applied: ${filtered.length} matches',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                  ),
                  GestureDetector(
                    onTap: () {
                      _coachSearchController.clear();
                      _coachLocationController.clear();
                      setState(() {
                        _coachSearchQuery = '';
                        _coachLocationQuery = '';
                        _selectedCoachSpecialty = 'All';
                        _selectedLocationFilter = 'All';
                      });
                    },
                    child: Text(
                      'Reset All',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48)),
                    ),
                  ),
                ],
              ),
            ),

          // List of filtered coaches
          if (_isLoadingCoaches)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_search_rounded, size: 36, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Coaches Found',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try adjusting your search query, location, or discipline filter.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _loadAvailableCoaches(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('Reload Directory', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showInviteCodeDialog,
                        icon: const Icon(Icons.vpn_key_rounded, size: 16),
                        label: Text('Enter Invite Code', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ...filtered.map((c) => _buildAvailableCoachCard(c)),
        ],
      ),
    );
  }

  // ── Explore More Coaches Section (Shown when already connected) ─────────────
  Widget _buildExploreMoreCoachesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _showExploreMoreCoaches = !_showExploreMoreCoaches),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.explore_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore More Specialists',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            'Link a Nutritionist, Mobility, or Rehab Coach',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showExploreMoreCoaches ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showExploreMoreCoaches) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildRecommendedCoachesSection(),
                  const SizedBox(height: 18),
                  _buildCoachSearchAndFilterSection(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableCoachCard(Map<String, dynamic> coach) {
    final name = (coach['name'] ?? 'Coach').toString();
    final title = (coach['title'] ?? 'Performance Coach').toString();
    final specialty = (coach['specialty'] ?? coach['discipline'] ?? 'General Fitness').toString();
    final location = (coach['location'] ?? 'Remote').toString();
    final locationType = (coach['location_type'] ?? '').toString();
    final bio = (coach['bio'] ?? '').toString();
    final avatar = (coach['avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400').toString();
    final rating = (coach['rating'] ?? 4.9).toDouble();
    final reviewCount = coach['review_count'] ?? 30;
    final coachId = (coach['id'] ?? '').toString();
    final alreadyConnected = _coaches.any((c) => c['coach_id'] == coachId);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openCoachDetailsModal(coach),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundImage: NetworkImage(avatar),
                      backgroundColor: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF3B82F6)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            specialty,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFE11D48)),
                    const SizedBox(width: 4),
                    Text(
                      locationType.isNotEmpty ? '$location ($locationType)' : location,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                    const Spacer(),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(2),
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '($reviewCount)',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.3),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openCoachDetailsModal(coach),
                      icon: const Icon(Icons.info_outline_rounded, size: 14),
                      label: Text('Full Profile', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: alreadyConnected || _isConnecting
                          ? null
                          : () => _connectToCoach(coachId, coachName: name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alreadyConnected ? Colors.grey.shade400 : AppTheme.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        alreadyConnected ? 'Connected' : 'Connect Coach',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
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

  void _openCoachDetailsModal(Map<String, dynamic> coach) {
    final name = (coach['name'] ?? 'Coach').toString();
    final title = (coach['title'] ?? 'Performance Coach').toString();
    final specialty = (coach['specialty'] ?? coach['discipline'] ?? '').toString();
    final location = (coach['location'] ?? 'Remote').toString();
    final locationType = (coach['location_type'] ?? '').toString();
    final bio = (coach['bio'] ?? '').toString();
    final avatar = (coach['avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400').toString();
    final rating = (coach['rating'] ?? 4.9).toDouble();
    final reviewCount = coach['review_count'] ?? 40;
    final activeClients = coach['active_clients'] ?? 15;
    final expYears = coach['experience_years'] ?? 8;
    final hourlyRate = (coach['hourly_rate'] ?? '').toString();
    final certs = coach['certifications'] is List ? List<String>.from(coach['certifications']) : <String>[];
    final coachId = (coach['id'] ?? '').toString();
    final alreadyConnected = _coaches.any((c) => c['coach_id'] == coachId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: NetworkImage(avatar),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF3B82F6)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating.toStringAsFixed(2),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($reviewCount reviews)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Quick info stats
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _modalQuickStat('Discipline', specialty),
                            Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                            _modalQuickStat('Experience', '$expYears+ Years'),
                            Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                            _modalQuickStat('Active Athletes', '$activeClients'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Location & Pricing info
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE11D48)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      locationType.isNotEmpty ? '$location ($locationType)' : location,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hourlyRate.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                hourlyRate,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),

                      // About / Bio
                      Text(
                        'About Coach',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bio.isNotEmpty ? bio : 'Certified fitness and health professional on SabCoach ecosystem.',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.45),
                      ),
                      const SizedBox(height: 18),

                      // Certifications
                      if (certs.isNotEmpty) ...[
                        Text(
                          'Certifications & Credentials',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: certs.map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF6366F1)),
                                  const SizedBox(width: 6),
                                  Text(
                                    c,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4338CA),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Connect button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: alreadyConnected || _isConnecting
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _connectToCoach(coachId, coachName: name);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: alreadyConnected ? Colors.grey.shade400 : AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            alreadyConnected ? 'Already Connected' : 'Connect with Coach',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modalQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }


  // ── Helper: 3 Top Distinct Discipline Coaches ──────────────────────────────
  List<Map<String, dynamic>> _getTop3RecommendedCoaches() {
    if (_recommendedCoaches.isNotEmpty) {
      return _recommendedCoaches
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .take(3)
          .toList();
    }
    // Fallback: pick distinct disciplines from available coaches
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final raw in _availableCoaches) {
      if (raw is! Map) continue;
      final c = Map<String, dynamic>.from(raw);
      final disc = _normalizeDiscipline((c['discipline'] ?? c['specialty'] ?? c['title'] ?? '').toString());
      if (!seen.contains(disc)) {
        seen.add(disc);
        result.add(c);
        if (result.length >= 3) break;
      }
    }
    if (result.length < 3) {
      for (final raw in _availableCoaches) {
        if (raw is! Map) continue;
        final c = Map<String, dynamic>.from(raw);
        if (!result.any((x) => x['id'] == c['id'])) {
          result.add(c);
          if (result.length >= 3) break;
        }
      }
    }
    return result;
  }

  String _normalizeDiscipline(String val) {
    final v = val.toLowerCase();
    if (v.contains('nutrition') || v.contains('diet') || v.contains('metabol')) return 'Nutrition & Dietetics';
    if (v.contains('yoga') || v.contains('mobility') || v.contains('stretch')) return 'Yoga & Mobility';
    if (v.contains('cardio') || v.contains('endurance') || v.contains('run')) return 'Cardio & Endurance';
    if (v.contains('physio') || v.contains('rehab') || v.contains('therapy')) return 'Physio & Rehab';
    return 'Strength & Conditioning';
  }

  List<Map<String, dynamic>> get _filteredCoaches {
    return _availableCoaches.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final spec = (c['specialty'] ?? c['title'] ?? c['discipline'] ?? '').toString().toLowerCase();
      final bio = (c['bio'] ?? '').toString().toLowerCase();
      final loc = (c['location'] ?? '').toString().toLowerCase();
      final locType = (c['location_type'] ?? '').toString().toLowerCase();

      final q = _coachSearchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || spec.contains(q) || bio.contains(q);

      final locQ = _coachLocationQuery.trim().toLowerCase();
      final matchesLocQuery = locQ.isEmpty || loc.contains(locQ) || locType.contains(locQ);

      final matchesLocTypeChip = _selectedLocationFilter == 'All' ||
          (_selectedLocationFilter == 'Remote' && (locType.contains('online') || locType.contains('remote') || loc.contains('remote'))) ||
          (_selectedLocationFilter == 'In-Person / Hybrid' && (locType.contains('hybrid') || locType.contains('in-person') || locType.contains('telehealth')));

      final matchesSpec = _selectedCoachSpecialty == 'All' ||
          spec.contains(_selectedCoachSpecialty.toLowerCase()) ||
          (c['discipline'] ?? '').toString().toLowerCase().contains(_selectedCoachSpecialty.toLowerCase());

      return matchesQuery && matchesLocQuery && matchesLocTypeChip && matchesSpec;
    }).toList();
  }
}

// Helper model for macro goal display
class _MacroGoal {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MacroGoal(this.label, this.value, this.color, this.icon);
}
