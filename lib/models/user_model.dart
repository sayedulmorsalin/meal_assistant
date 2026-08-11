enum UserRole { member, manager, superAdmin }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final UserRole? participationRole; // Roles like member or manager for Super Admin
  final String? messId;
  final String? profileImage;
  final String status;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.participationRole,
    this.messId,
    this.profileImage,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'participationRole': participationRole?.toString().split('.').last,
      'messId': messId,
      'profileImage': profileImage,
      'status': status,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.member,
      ),
      participationRole: map['participationRole'] != null
          ? UserRole.values.firstWhere(
              (e) => e.toString().split('.').last == map['participationRole'],
              orElse: () => UserRole.member,
            )
          : null,
      messId: map['messId'],
      profileImage: map['profileImage'],
      status: map['status'] ?? '',
    );
  }
}
