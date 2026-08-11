import 'package:cloud_firestore/cloud_firestore.dart';

enum JoinRequestStatus { pending, accepted, rejected }

class JoinRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String messId;
  final String messName;
  final JoinRequestStatus status;
  final DateTime timestamp;

  JoinRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.messId,
    required this.messName,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'messId': messId,
      'messName': messName,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory JoinRequestModel.fromMap(Map<String, dynamic> map) {
    return JoinRequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      messId: map['messId'] ?? '',
      messName: map['messName'] ?? '',
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
