class Measurement {
  final int? id;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? neck;
  final double? shoulders;
  final double? leftBicep;
  final double? rightBicep;
  final double? leftThigh;
  final double? rightThigh;
  final double? leftCalf;
  final double? rightCalf;
  final DateTime createdAt;

  Measurement({
    this.id,
    this.chest,
    this.waist,
    this.hips,
    this.neck,
    this.shoulders,
    this.leftBicep,
    this.rightBicep,
    this.leftThigh,
    this.rightThigh,
    this.leftCalf,
    this.rightCalf,
    required this.createdAt,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'],
      chest: json['chest']?.toDouble(),
      waist: json['waist']?.toDouble(),
      hips: json['hips']?.toDouble(),
      neck: json['neck']?.toDouble(),
      shoulders: json['shoulders']?.toDouble(),
      leftBicep: json['left_bicep']?.toDouble(),
      rightBicep: json['right_bicep']?.toDouble(),
      leftThigh: json['left_thigh']?.toDouble(),
      rightThigh: json['right_thigh']?.toDouble(),
      leftCalf: json['left_calf']?.toDouble(),
      rightCalf: json['right_calf']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'neck': neck,
      'shoulders': shoulders,
      'left_bicep': leftBicep,
      'right_bicep': rightBicep,
      'left_thigh': leftThigh,
      'right_thigh': rightThigh,
      'left_calf': leftCalf,
      'right_calf': rightCalf,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
