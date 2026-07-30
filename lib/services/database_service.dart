import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/models/mess_model.dart';
import 'package:mess_management/models/meal_model.dart';
import 'package:mess_management/models/log_model.dart';
import 'package:mess_management/models/request_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create Mess
  Future<String> createMess(String name, String superAdminId) async {
    String messId = _db.collection('messes').doc().id;
    String joinKey = (100000 + Random().nextInt(900000)).toString(); // Simple 6 digit key

    MessModel newMess = MessModel(
      id: messId,
      name: name,
      joinKey: joinKey,
      superAdminId: superAdminId,
    );

    await _db.collection('messes').doc(messId).set(newMess.toMap());

    // Update user role to superAdmin and set messId
    await _db.collection('users').doc(superAdminId).update({
      'role': UserRole.superAdmin.toString().split('.').last,
      'messId': messId,
    });

    return joinKey;
  }

  // Join Mess
  Future<bool> joinMess(String joinKey, String userId) async {
    var messQuery = await _db.collection('messes').where('joinKey', isEqualTo: joinKey).get();
    
    if (messQuery.docs.isNotEmpty) {
      String messId = messQuery.docs.first.id;
      await _db.collection('users').doc(userId).update({
        'messId': messId,
      });
      return true;
    }
    return false;
  }

  // Update Meal Status
  Future<void> updateMealStatus(MealModel mealModel) async {
    await _db.collection('meals').doc(mealModel.id).set(mealModel.toMap(), SetOptions(merge: true));
  }

  // Get Logs
  Stream<List<LogModel>> getLogs(String messId) {
    return _db.collection('logs')
      .where('messId', isEqualTo: messId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => LogModel.fromMap(doc.data())).toList());
  }

  // Assign Manager
  Future<void> assignManager(String messId, String managerId) async {
    await _db.collection('messes').doc(messId).update({
      'managerId': managerId,
    });
    
    await _db.collection('users').doc(managerId).update({
      'role': UserRole.manager.toString().split('.').last,
    });
  }

  // Get Mess Members
  Stream<List<UserModel>> getMessMembers(String messId) {
    return _db.collection('users')
      .where('messId', isEqualTo: messId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  // Get User Meals for a specific date
  Stream<List<MealModel>> getUserMeals(String userId, DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return _db.collection('meals')
      .where('userId', isEqualTo: userId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MealModel.fromMap(doc.data())).toList());
  }

  // Get User Meals for a specific month
  Stream<List<MealModel>> getUserMonthlyMeals(String userId, int year, int month) {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth = DateTime(year, month + 1, 0).add(const Duration(days: 1)); // End of month

    return _db.collection('meals')
      .where('userId', isEqualTo: userId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MealModel.fromMap(doc.data())).toList());
  }

  // Create Meal Request
  Future<void> createMealRequest(String userId, String messId, DateTime date, Map<String, bool> mealsRequested) async {
    String requestId = _db.collection('requests').doc().id;
    RequestModel request = RequestModel(
      id: requestId,
      userId: userId,
      messId: messId,
      date: date,
      mealsRequested: mealsRequested,
      status: RequestStatus.pending,
      timestamp: DateTime.now(),
    );
    await _db.collection('requests').doc(requestId).set(request.toMap());
  }

  // Get Pending Requests
  Stream<List<RequestModel>> getPendingRequests(String messId) {
    return _db.collection('requests')
      .where('messId', isEqualTo: messId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => RequestModel.fromMap(doc.data())).toList());
  }

  // Get User Pending Requests
  Stream<List<RequestModel>> getUserPendingRequests(String userId) {
    return _db.collection('requests')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => RequestModel.fromMap(doc.data())).toList());
  }

  // Get Mess Monthly Meals
  Stream<List<MealModel>> getMessMonthlyMeals(String messId, int year, int month) {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth = DateTime(year, month + 1, 0).add(const Duration(days: 1));

    return _db.collection('meals')
      .where('messId', isEqualTo: messId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MealModel.fromMap(doc.data())).toList());
  }

  // Save Shopping Record
  Future<void> saveShoppingRecord(String messId, DateTime date, List<Map<String, dynamic>> items) async {
    String id = _db.collection('shopping').doc().id;
    await _db.collection('shopping').doc(id).set({
      'id': id,
      'messId': messId,
      'date': Timestamp.fromDate(date),
      'items': items,
    });
    
    double total = items.fold(0.0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()));
    await addLog(messId, "manager", "Manager added shopping record for ${date.day}/${date.month}: ₹$total");
  }

  // Get Shopping History
  Stream<List<Map<String, dynamic>>> getShoppingHistory(String messId) {
    return _db.collection('shopping')
      .where('messId', isEqualTo: messId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Approve Request
  Future<void> approveRequest(String requestId, String managerId) async {
    DocumentSnapshot requestDoc = await _db.collection('requests').doc(requestId).get();
    if (requestDoc.exists) {
      RequestModel request = RequestModel.fromMap(requestDoc.data() as Map<String, dynamic>);
      
      // Update request status
      await _db.collection('requests').doc(requestId).update({'status': 'accepted'});

      // Find or create MealModel for the user and date
      DateTime startOfDay = DateTime(request.date.year, request.date.month, request.date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      var mealQuery = await _db.collection('meals')
          .where('userId', isEqualTo: request.userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      String mealId;
      if (mealQuery.docs.isNotEmpty) {
        mealId = mealQuery.docs.first.id;
      } else {
        mealId = _db.collection('meals').doc().id;
      }

      await _db.collection('meals').doc(mealId).set({
        'id': mealId,
        'userId': request.userId,
        'messId': request.messId,
        'date': Timestamp.fromDate(request.date),
        ...request.mealsRequested,
      }, SetOptions(merge: true));

      // Add log
      await addLog(request.messId, request.userId, "Manager approved meal request for ${request.date.day}/${request.date.month}");
    }
  }

  // Reject Request
  Future<void> rejectRequest(String requestId, String managerId) async {
    await _db.collection('requests').doc(requestId).update({'status': 'rejected'});
  }

  // Add Log
  Future<void> addLog(String messId, String userId, String message) async {
    String logId = _db.collection('logs').doc().id;
    LogModel log = LogModel(
      id: logId,
      messId: messId,
      userId: userId,
      message: message,
      timestamp: DateTime.now(),
    );
    await _db.collection('logs').doc(logId).set(log.toMap());
  }
}
