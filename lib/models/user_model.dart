import 'package:cloud_firestore/cloud_firestore.dart';

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
  final double deposit;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.participationRole,
    this.messId,
    this.profileImage,
    required this.status,
    this.deposit = 0.0,
    this.createdAt,
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
      'deposit': deposit,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
      deposit: (map['deposit'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
