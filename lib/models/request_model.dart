import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, accepted, rejected }

class RequestModel {
  final String id;
  final String userId;
  final String userName;
  final String messId;
  final DateTime date;
  final Map<String, bool> mealsRequested;
  final Map<String, int>? guestMealsRequested;
  final RequestStatus status;
  final DateTime timestamp;

  RequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.messId,
    required this.date,
    required this.mealsRequested,
    this.guestMealsRequested,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'messId': messId,
      'date': Timestamp.fromDate(date),
      'mealsRequested': mealsRequested,
      'guestMealsRequested': guestMealsRequested,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    return RequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Member',
      messId: map['messId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      mealsRequested: Map<String, bool>.from(map['mealsRequested'] ?? {}),
      guestMealsRequested: map['guestMealsRequested'] != null 
          ? Map<String, int>.from(map['guestMealsRequested']) 
          : null,
      status: RequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
