import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, accepted, rejected }

class RequestModel {
  final String id;
  final String userId;
  final String messId;
  final DateTime date;
  final Map<String, bool> mealsRequested;
  final RequestStatus status;
  final DateTime timestamp;

  RequestModel({
    required this.id,
    required this.userId,
    required this.messId,
    required this.date,
    required this.mealsRequested,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'messId': messId,
      'date': Timestamp.fromDate(date),
      'mealsRequested': mealsRequested,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    return RequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      messId: map['messId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      mealsRequested: Map<String, bool>.from(map['mealsRequested'] ?? {}),
      status: RequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
