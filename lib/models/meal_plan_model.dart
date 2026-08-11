class MealPlanModel {
  final String day; // Monday, Tuesday, etc.
  final String breakfast;
  final String lunch;
  final String dinner;

  MealPlanModel({
    required this.day,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
    };
  }

  factory MealPlanModel.fromMap(Map<String, dynamic> map) {
    return MealPlanModel(
      day: map['day'] ?? '',
      breakfast: map['breakfast'] ?? '',
      lunch: map['lunch'] ?? '',
      dinner: map['dinner'] ?? '',
    );
  }
}
