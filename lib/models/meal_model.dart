import 'package:cloud_firestore/cloud_firestore.dart';

class MealModel {
  final String id;
  final String userId;
  final String messId;
  final DateTime date;
  final bool breakfast;
  final bool lunch;
  final bool dinner;
  final int guestBreakfast;
  final int guestLunch;
  final int guestDinner;

  MealModel({
    required this.id,
    required this.userId,
    required this.messId,
    required this.date,
    this.breakfast = false,
    this.lunch = false,
    this.dinner = false,
    this.guestBreakfast = 0,
    this.guestLunch = 0,
    this.guestDinner = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'messId': messId,
      'date': Timestamp.fromDate(date),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'guestBreakfast': guestBreakfast,
      'guestLunch': guestLunch,
      'guestDinner': guestDinner,
    };
  }

  factory MealModel.fromMap(Map<String, dynamic> map) {
    return MealModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      messId: map['messId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      breakfast: map['breakfast'] ?? false,
      lunch: map['lunch'] ?? false,
      dinner: map['dinner'] ?? false,
      guestBreakfast: map['guestBreakfast'] ?? 0,
      guestLunch: map['guestLunch'] ?? 0,
      guestDinner: map['guestDinner'] ?? 0,
    );
  }
}
