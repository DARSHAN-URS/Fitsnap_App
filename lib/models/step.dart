class StepData {
  final int? id;
  final int stepCount;
  final double distance;
  final double caloriesBurned;
  final String date; // format: YYYY-MM-DD to match backend 'date' schema

  StepData({
    this.id,
    required this.stepCount,
    required this.distance,
    required this.caloriesBurned,
    required this.date,
  });

  factory StepData.fromJson(Map<String, dynamic> json) {
    return StepData(
      id: json['id'],
      stepCount: json['step_count'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      caloriesBurned: (json['calories_burned'] ?? 0.0).toDouble(),
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'step_count': stepCount,
    'distance': distance,
    'calories_burned': caloriesBurned,
    'date': date,
  };
}
