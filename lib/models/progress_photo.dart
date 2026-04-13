class ProgressImg {
  final int id;
  final String imageUrl;
  final double? weight;
  final String? description;
  final DateTime createdAt;

  ProgressImg({
    required this.id,
    required this.imageUrl,
    this.weight,
    this.description,
    required this.createdAt,
  });

  factory ProgressImg.fromJson(Map<String, dynamic> json) {
    return ProgressImg(
      id: json['id'],
      imageUrl: json['image_url'],
      weight: json['weight'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
