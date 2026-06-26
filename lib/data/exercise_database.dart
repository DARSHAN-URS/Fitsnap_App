enum MeasurementType {
  weightReps,
  bodyweightReps,
  time,
}

class Exercise {
  final String id;
  final String name;
  final String category;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final String equipment;
  final MeasurementType measurementType;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.measurementType,
  });
}

class ExerciseDatabase {
  static const List<Exercise> exercises = [
    // WEIGHT EXERCISES
    Exercise(
      id: 'w1', name: 'Bench Press', category: 'Weight', primaryMuscle: 'Chest', secondaryMuscles: ['Triceps', 'Shoulders'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w2', name: 'Incline Bench Press', category: 'Weight', primaryMuscle: 'Upper Chest', secondaryMuscles: ['Triceps', 'Shoulders'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w3', name: 'Decline Bench Press', category: 'Weight', primaryMuscle: 'Lower Chest', secondaryMuscles: ['Triceps'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w4', name: 'Barbell Squat', category: 'Weight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Hamstrings'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w5', name: 'Front Squat', category: 'Weight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Core'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w6', name: 'Hack Squat', category: 'Weight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes'], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w7', name: 'Deadlift', category: 'Weight', primaryMuscle: 'Hamstrings', secondaryMuscles: ['Glutes', 'Lower Back'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w8', name: 'Romanian Deadlift', category: 'Weight', primaryMuscle: 'Hamstrings', secondaryMuscles: ['Glutes'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w9', name: 'Shoulder Press', category: 'Weight', primaryMuscle: 'Shoulders', secondaryMuscles: ['Triceps'], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w10', name: 'Arnold Press', category: 'Weight', primaryMuscle: 'Shoulders', secondaryMuscles: ['Triceps'], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w11', name: 'Lateral Raise', category: 'Weight', primaryMuscle: 'Side Delts', secondaryMuscles: [], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w12', name: 'Cable Fly', category: 'Weight', primaryMuscle: 'Chest', secondaryMuscles: [], equipment: 'Cable', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w13', name: 'Chest Press Machine', category: 'Weight', primaryMuscle: 'Chest', secondaryMuscles: ['Triceps'], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w14', name: 'Lat Pulldown', category: 'Weight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps'], equipment: 'Cable', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w15', name: 'Seated Cable Row', category: 'Weight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps', 'Rhomboids'], equipment: 'Cable', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w16', name: 'Bent Over Row', category: 'Weight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps', 'Lower Back'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w17', name: 'Barbell Curl', category: 'Weight', primaryMuscle: 'Biceps', secondaryMuscles: ['Forearms'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w18', name: 'Hammer Curl', category: 'Weight', primaryMuscle: 'Biceps', secondaryMuscles: ['Forearms'], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w19', name: 'Tricep Pushdown', category: 'Weight', primaryMuscle: 'Triceps', secondaryMuscles: [], equipment: 'Cable', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w20', name: 'Leg Extension', category: 'Weight', primaryMuscle: 'Quads', secondaryMuscles: [], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w21', name: 'Leg Curl', category: 'Weight', primaryMuscle: 'Hamstrings', secondaryMuscles: [], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w22', name: 'Calf Raise', category: 'Weight', primaryMuscle: 'Calves', secondaryMuscles: [], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w23', name: 'Hip Thrust', category: 'Weight', primaryMuscle: 'Glutes', secondaryMuscles: ['Hamstrings'], equipment: 'Barbell', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w24', name: 'Leg Press', category: 'Weight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Hamstrings'], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w25', name: 'Machine Row', category: 'Weight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps', 'Rhomboids'], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w26', name: 'Pec Deck', category: 'Weight', primaryMuscle: 'Chest', secondaryMuscles: [], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w27', name: 'Rear Delt Fly', category: 'Weight', primaryMuscle: 'Rear Delts', secondaryMuscles: [], equipment: 'Machine', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w28', name: 'Shrugs', category: 'Weight', primaryMuscle: 'Traps', secondaryMuscles: [], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),
    Exercise(
      id: 'w29', name: 'Farmer Walk', category: 'Weight', primaryMuscle: 'Forearms', secondaryMuscles: ['Core', 'Traps'], equipment: 'Dumbbells', measurementType: MeasurementType.weightReps,
    ),

    // BODYWEIGHT EXERCISES
    Exercise(
      id: 'bw1', name: 'Push Ups', category: 'Bodyweight', primaryMuscle: 'Chest', secondaryMuscles: ['Triceps', 'Shoulders'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw2', name: 'Diamond Push Ups', category: 'Bodyweight', primaryMuscle: 'Triceps', secondaryMuscles: ['Chest'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw3', name: 'Incline Push Ups', category: 'Bodyweight', primaryMuscle: 'Lower Chest', secondaryMuscles: ['Triceps'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw4', name: 'Decline Push Ups', category: 'Bodyweight', primaryMuscle: 'Upper Chest', secondaryMuscles: ['Triceps'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw5', name: 'Pull Ups', category: 'Bodyweight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw6', name: 'Chin Ups', category: 'Bodyweight', primaryMuscle: 'Lats', secondaryMuscles: ['Biceps'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw7', name: 'Dips', category: 'Bodyweight', primaryMuscle: 'Triceps', secondaryMuscles: ['Chest', 'Shoulders'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw8', name: 'Bodyweight Squats', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw9', name: 'Walking Lunges', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Hamstrings'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw10', name: 'Bulgarian Split Squat', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw11', name: 'Jump Squats', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Calves'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw12', name: 'Burpees', category: 'Bodyweight', primaryMuscle: 'Full Body', secondaryMuscles: ['Cardio'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw13', name: 'Mountain Climbers', category: 'Bodyweight', primaryMuscle: 'Core', secondaryMuscles: ['Cardio', 'Shoulders'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw14', name: 'Step Ups', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw15', name: 'Glute Bridge', category: 'Bodyweight', primaryMuscle: 'Glutes', secondaryMuscles: ['Hamstrings'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw16', name: 'Single Leg Glute Bridge', category: 'Bodyweight', primaryMuscle: 'Glutes', secondaryMuscles: ['Hamstrings'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw17', name: 'Superman', category: 'Bodyweight', primaryMuscle: 'Lower Back', secondaryMuscles: ['Glutes'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw18', name: 'Bird Dog', category: 'Bodyweight', primaryMuscle: 'Core', secondaryMuscles: ['Lower Back'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw19', name: 'Pistol Squat', category: 'Bodyweight', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes', 'Core'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw20', name: 'Jumping Jacks', category: 'Bodyweight', primaryMuscle: 'Full Body', secondaryMuscles: ['Cardio'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),
    Exercise(
      id: 'bw21', name: 'High Knees', category: 'Bodyweight', primaryMuscle: 'Full Body', secondaryMuscles: ['Cardio'], equipment: 'Bodyweight', measurementType: MeasurementType.bodyweightReps,
    ),

    // TIMED EXERCISES
    Exercise(
      id: 't1', name: 'Plank', category: 'Timed', primaryMuscle: 'Core', secondaryMuscles: ['Shoulders'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't2', name: 'Side Plank', category: 'Timed', primaryMuscle: 'Obliques', secondaryMuscles: ['Core'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't3', name: 'Shoulder Plank', category: 'Timed', primaryMuscle: 'Shoulders', secondaryMuscles: ['Core'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't4', name: 'Wall Sit', category: 'Timed', primaryMuscle: 'Quads', secondaryMuscles: ['Glutes'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't5', name: 'Dead Hang', category: 'Timed', primaryMuscle: 'Forearms', secondaryMuscles: ['Lats'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't6', name: 'Hollow Hold', category: 'Timed', primaryMuscle: 'Core', secondaryMuscles: [], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't7', name: 'L-Sit', category: 'Timed', primaryMuscle: 'Core', secondaryMuscles: ['Triceps'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't8', name: 'Russian Twist Timer', category: 'Timed', primaryMuscle: 'Obliques', secondaryMuscles: ['Core'], equipment: 'Bodyweight', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't9', name: 'Battle Rope', category: 'Timed', primaryMuscle: 'Full Body', secondaryMuscles: ['Cardio', 'Shoulders'], equipment: 'Battle Ropes', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't10', name: 'Jump Rope', category: 'Timed', primaryMuscle: 'Cardio', secondaryMuscles: ['Calves'], equipment: 'Jump Rope', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't11', name: 'Stretch Hold', category: 'Timed', primaryMuscle: 'Flexibility', secondaryMuscles: [], equipment: 'None', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't12', name: 'Yoga Pose', category: 'Timed', primaryMuscle: 'Flexibility', secondaryMuscles: ['Balance'], equipment: 'None', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't13', name: 'Meditation', category: 'Timed', primaryMuscle: 'Mind', secondaryMuscles: [], equipment: 'None', measurementType: MeasurementType.time,
    ),
    Exercise(
      id: 't14', name: 'Breathing Exercise', category: 'Timed', primaryMuscle: 'Lungs', secondaryMuscles: [], equipment: 'None', measurementType: MeasurementType.time,
    ),
  ];

  static List<Exercise> searchExercises(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return exercises.where((e) => e.name.toLowerCase().contains(lowerQuery)).toList();
  }
}
