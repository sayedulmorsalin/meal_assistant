import 'package:cloud_firestore/cloud_firestore.dart';

class LogModel {
  final String id;
  final String messId;
  final String userId;
  final String message;
  final DateTime timestamp;

  LogModel({
    required this.id,
    required this.messId,
    required this.userId,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'messId': messId,
      'userId': userId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['id'] ?? '',
      messId: map['messId'] ?? '',
      userId: map['userId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
