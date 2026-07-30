class MessModel {
  final String id;
  final String name;
  final String joinKey;
  final String superAdminId;
  final String? managerId;

  MessModel({
    required this.id,
    required this.name,
    required this.joinKey,
    required this.superAdminId,
    this.managerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'joinKey': joinKey,
      'superAdminId': superAdminId,
      'managerId': managerId,
    };
  }

  factory MessModel.fromMap(Map<String, dynamic> map) {
    return MessModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      joinKey: map['joinKey'] ?? '',
      superAdminId: map['superAdminId'] ?? '',
      managerId: map['managerId'],
    );
  }
}
