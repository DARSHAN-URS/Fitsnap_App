class MedicalHistory {
  final int? id;
  final bool isDiabetic;
  final bool hasHypertension;
  final bool hasAllergies;
  final List<String>? allergiesList;
  final String? otherConditions;
  final String? medications;
  final String? bloodGroup;

  MedicalHistory({
    this.id,
    this.isDiabetic = false,
    this.hasHypertension = false,
    this.hasAllergies = false,
    this.allergiesList,
    this.otherConditions,
    this.medications,
    this.bloodGroup,
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      id: json['id'],
      isDiabetic: json['is_diabetic'] ?? false,
      hasHypertension: json['has_hypertension'] ?? false,
      hasAllergies: json['has_allergies'] ?? false,
      allergiesList: json['allergies_list'] != null ? List<String>.from(json['allergies_list']) : null,
      otherConditions: json['other_conditions'],
      medications: json['medications'],
      bloodGroup: json['blood_group'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_diabetic': isDiabetic,
      'has_hypertension': hasHypertension,
      'has_allergies': hasAllergies,
      'allergies_list': allergiesList,
      'other_conditions': otherConditions,
      'medications': medications,
      'blood_group': bloodGroup,
    };
  }
}
