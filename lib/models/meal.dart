class Meal {
  final int? id;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl;
  final DateTime createdAt;
  final String status;

  Meal({
    this.id,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
    required this.createdAt,
    this.status = 'completed',
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      foodName: json['food_name'] ?? 'Analysing...',
      calories: (json['calories'] ?? 0.0).toDouble(),
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      imageUrl: json['image_url'],
      status: json['status'] ?? 'completed',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'food_name': foodName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'image_url': imageUrl,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}
