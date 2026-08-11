class MessModel {
  final String id;
  final String name;
  final String joinKey;
  final String superAdminId;
  final String? managerId;
  final double mealRate;
  final double totalDeposit;

  MessModel({
    required this.id,
    required this.name,
    required this.joinKey,
    required this.superAdminId,
    this.managerId,
    this.mealRate = 0.0,
    this.totalDeposit = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'joinKey': joinKey,
      'superAdminId': superAdminId,
      'managerId': managerId,
      'mealRate': mealRate,
      'totalDeposit': totalDeposit,
    };
  }

  factory MessModel.fromMap(Map<String, dynamic> map) {
    return MessModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      joinKey: map['joinKey'] ?? '',
      superAdminId: map['superAdminId'] ?? '',
      managerId: map['managerId'],
      mealRate: (map['mealRate'] ?? 0.0).toDouble(),
      totalDeposit: (map['totalDeposit'] ?? 0.0).toDouble(),
    );
  }
}
