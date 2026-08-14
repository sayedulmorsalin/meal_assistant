import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meal_assistant/models/join_request_model.dart';
import 'dart:math';
import 'package:meal_assistant/models/user_model.dart';
import 'package:meal_assistant/models/mess_model.dart';
import 'package:meal_assistant/models/meal_model.dart';
import 'package:meal_assistant/models/log_model.dart';
import 'package:meal_assistant/models/request_model.dart';
import 'package:meal_assistant/models/message_model.dart';
import 'package:meal_assistant/models/meal_plan_model.dart';

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

    // Update user role to superAdmin and set messId and participationRole
    await _db.collection('users').doc(superAdminId).update({
      'role': UserRole.superAdmin.toString().split('.').last,
      'participationRole': UserRole.member.toString().split('.').last,
      'messId': messId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await initializeDefaultMealsForUser(superAdminId, messId, DateTime.now());

    return joinKey;
  }

  // Initialize Default Meals for user from join day to month end in Firestore
  Future<void> initializeDefaultMealsForUser(String userId, String messId, DateTime joinDate) async {
    WriteBatch batch = _db.batch();
    int daysInMonth = DateUtils.getDaysInMonth(joinDate.year, joinDate.month);
    
    for (int day = joinDate.day; day <= daysInMonth; day++) {
      DateTime date = DateTime(joinDate.year, joinDate.month, day);
      String docId = "${messId}_${userId}_${date.year}_${date.month}_$day";
      DocumentReference ref = _db.collection('meals').doc(docId);
      batch.set(ref, {
        'id': docId,
        'userId': userId,
        'messId': messId,
        'date': Timestamp.fromDate(date),
        'breakfast': false,
        'lunch': true,
        'dinner': true,
        'guestBreakfast': 0,
        'guestLunch': 0,
        'guestDinner': 0,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Send Join Request
  Future<String?> sendJoinRequest(String userId, String userName, String joinKey) async {
    try {
      var messQuery = await _db.collection('messes').where('joinKey', isEqualTo: joinKey).get();
      if (messQuery.docs.isEmpty) return "Invalid Join Key";

      var messDoc = messQuery.docs.first;
      String messId = messDoc.id;
      String messName = messDoc.data()['name'] ?? 'Unknown Mess';

      // Check if user is already in this mess or has a pending request
      var existingRequest = await _db.collection('join_requests')
          .where('userId', isEqualTo: userId)
          .where('messId', isEqualTo: messId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (existingRequest.docs.isNotEmpty) return "You already have a pending request for this mess.";

      String requestId = _db.collection('join_requests').doc().id;
      JoinRequestModel request = JoinRequestModel(
        id: requestId,
        userId: userId,
        userName: userName,
        messId: messId,
        messName: messName,
        status: JoinRequestStatus.pending,
        timestamp: DateTime.now(),
      );

      await _db.collection('join_requests').doc(requestId).set(request.toMap());
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Get Pending Join Requests
  Stream<List<JoinRequestModel>> getPendingJoinRequests(String messId) {
    return _db.collection('join_requests')
        .where('messId', isEqualTo: messId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JoinRequestModel.fromMap(doc.data())).toList());
  }

  // Accept Join Request
  Future<void> acceptJoinRequest(JoinRequestModel request) async {
    // Update request status
    await _db.collection('join_requests').doc(request.id).update({'status': 'accepted'});

    // Set messId and createdAt for the user
    await _db.collection('users').doc(request.userId).update({
      'messId': request.messId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Initialize default meals in Firestore for user from join day to month end
    await initializeDefaultMealsForUser(request.userId, request.messId, DateTime.now());
  }

  // Reject Join Request
  Future<void> rejectJoinRequest(String requestId) async {
    await _db.collection('join_requests').doc(requestId).update({'status': 'rejected'});
  }

  // Remove Member
  Future<void> removeMember(String userId, String messId) async {
    await _db.collection('users').doc(userId).update({
      'messId': null,
      'role': UserRole.member.toString().split('.').last,
    });
    
    // Also remove from mess managerId if they were the manager
    var messDoc = await _db.collection('messes').doc(messId).get();
    if (messDoc.exists && messDoc.data()?['managerId'] == userId) {
      await _db.collection('messes').doc(messId).update({'managerId': null});
    }
  }

  // Leave Mess
  Future<void> leaveMess(String userId, String messId) async {
    await _db.collection('users').doc(userId).update({
      'messId': null,
      'role': UserRole.member.toString().split('.').last,
      'participationRole': null,
      'deposit': 0.0,
    });
    
    // Also remove from mess managerId if they were the manager
    var messDoc = await _db.collection('messes').doc(messId).get();
    if (messDoc.exists && messDoc.data()?['managerId'] == userId) {
      await _db.collection('messes').doc(messId).update({'managerId': null});
    }

    await addLog(messId, userId, "User left the mess.");
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

  // Assign Manager (and demote old manager back to member)
  Future<void> assignManager(String messId, String managerId) async {
    // Find existing manager and demote them
    final messDoc = await _db.collection('messes').doc(messId).get();
    final oldManagerId = messDoc.data()?['managerId'] as String?;
    if (oldManagerId != null && oldManagerId != managerId) {
      await _db.collection('users').doc(oldManagerId).update({
        'role': UserRole.member.toString().split('.').last,
      });
    }

    await _db.collection('messes').doc(messId).update({
      'managerId': managerId,
    });

    await _db.collection('users').doc(managerId).update({
      'role': UserRole.manager.toString().split('.').last,
    });
  }

  // Update Mess Financials (meal rate, total deposit)
  Future<void> updateMessFinancials(String messId, {double? mealRate, double? totalDeposit}) async {
    final Map<String, dynamic> updates = {};
    if (mealRate != null) updates['mealRate'] = mealRate;
    if (totalDeposit != null) updates['totalDeposit'] = totalDeposit;
    if (updates.isNotEmpty) {
      await _db.collection('messes').doc(messId).update(updates);
    }
  }

  // Update Mess Name
  Future<void> updateMessName(String messId, String newName, String userId) async {
    await _db.collection('messes').doc(messId).update({
      'name': newName,
    });
    await addLog(messId, userId, "Mess name updated to '$newName'");
  }


  // Add Member Deposit — increments totalDeposit in the mess doc, updates user deposit, and logs
  Future<void> addMemberDeposit(String messId, String userId, String userName, double amount) async {
    await _db.collection('messes').doc(messId).update({
      'totalDeposit': FieldValue.increment(amount),
    });
    await _db.collection('users').doc(userId).update({
      'deposit': FieldValue.increment(amount),
    });
    await addLog(messId, userId, "Deposit added: ৳${amount.toStringAsFixed(2)} for $userName");
  }

  // Get Mess Details
  Stream<MessModel> getMessDetails(String messId) {
    return _db.collection('messes').doc(messId).snapshots().map((doc) => MessModel.fromMap(doc.data() as Map<String, dynamic>));
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
  Stream<List<MealModel>> getUserMonthlyMeals(String userId, String messId, int year, int month) {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth = DateTime(year, month + 1, 0).add(const Duration(days: 1)); // End of month

    return _db.collection('meals')
      .where('userId', isEqualTo: userId)
      .where('messId', isEqualTo: messId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MealModel.fromMap(doc.data())).toList());
  }

  // Create Meal Request
  Future<void> createMealRequest(
    String userId, 
    String userName, 
    String messId, 
    DateTime date, 
    Map<String, bool> mealsRequested,
    {Map<String, int>? guestMealsRequested}
  ) async {
    String requestId = _db.collection('requests').doc().id;
    RequestModel request = RequestModel(
      id: requestId,
      userId: userId,
      userName: userName,
      messId: messId,
      date: date,
      mealsRequested: mealsRequested,
      guestMealsRequested: guestMealsRequested,
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

  // Get All Requests (Audit History for all members)
  Stream<List<RequestModel>> getAllMealRequests(String messId) {
    return _db.collection('requests')
      .where('messId', isEqualTo: messId)
      .snapshots()
      .map((snapshot) {
        List<RequestModel> list = snapshot.docs.map((doc) => RequestModel.fromMap(doc.data())).toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      });
  }

  // Get User Pending Requests
  Stream<List<RequestModel>> getUserPendingRequests(String userId, String messId) {
    return _db.collection('requests')
      .where('userId', isEqualTo: userId)
      .where('messId', isEqualTo: messId)
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
    
    double total = items.fold(0.0, (totalSum, item) => totalSum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()));
    await addLog(messId, "manager", "Manager added shopping record for ${date.day}/${date.month}: ৳$total");
  }

  // Get Shopping History
  Stream<List<Map<String, dynamic>>> getShoppingHistory(String messId) {
    return _db.collection('shopping')
      .where('messId', isEqualTo: messId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Get Monthly Shopping Total
  Stream<double> getMonthlyShoppingTotal(String messId, int year, int month) {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth = DateTime(year, month + 1, 0).add(const Duration(days: 1));

    return _db.collection('shopping')
      .where('messId', isEqualTo: messId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
      .snapshots()
      .map((snapshot) {
        double total = 0.0;
        for (var doc in snapshot.docs) {
          final items = (doc.data()['items'] as List? ?? []);
          for (var item in items) {
            total += ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt());
          }
        }
        return total;
      });
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

      Map<String, dynamic> mealData = {
        'id': mealId,
        'userId': request.userId,
        'messId': request.messId,
        'date': Timestamp.fromDate(request.date),
        ...request.mealsRequested,
      };
      if (request.guestMealsRequested != null) {
        mealData['guestBreakfast'] = request.guestMealsRequested!['breakfast'] ?? 0;
        mealData['guestLunch'] = request.guestMealsRequested!['lunch'] ?? 0;
        mealData['guestDinner'] = request.guestMealsRequested!['dinner'] ?? 0;
      }

      await _db.collection('meals').doc(mealId).set(mealData, SetOptions(merge: true));

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

  // Messaging (Chat)
  Future<void> sendMessage(String messId, MessageModel message) async {
    await _db.collection('messes').doc(messId).collection('messages').doc(message.id).set(message.toMap());
  }

  Stream<List<MessageModel>> getMessages(String messId) {
    return _db.collection('messes')
        .doc(messId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromMap(doc.data())).toList());
  }

  // Meal Planning
  Future<void> updateMealPlan(String messId, List<MealPlanModel> plan) async {
    final batch = _db.batch();
    final planCollection = _db.collection('messes').doc(messId).collection('meal_plan');
    
    // Clear existing or just overwrite by day id
    for (var dayPlan in plan) {
      batch.set(planCollection.doc(dayPlan.day), dayPlan.toMap());
    }
    await batch.commit();
  }

  Stream<List<MealPlanModel>> getMealPlan(String messId) {
    return _db.collection('messes')
        .doc(messId)
        .collection('meal_plan')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MealPlanModel.fromMap(doc.data())).toList());
  }

  // Firebase Storage Uploads
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    final ref = FirebaseStorage.instance.ref().child('profile_images').child('$userId.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<String> uploadChatImage(File imageFile, String messId) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('chat_images').child(messId).child('$fileName.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // Delete Mess and all associated data (Cascading Delete)
  Future<void> deleteMess(String messId) async {
    // 1. Delete all meals docs for this messId
    final mealsQuery = await _db.collection('meals').where('messId', isEqualTo: messId).get();
    for (var doc in mealsQuery.docs) {
      await doc.reference.delete();
    }

    // 2. Delete all shopping docs for this messId
    final shoppingQuery = await _db.collection('shopping').where('messId', isEqualTo: messId).get();
    for (var doc in shoppingQuery.docs) {
      await doc.reference.delete();
    }

    // 3. Delete all requests docs for this messId
    final requestsQuery = await _db.collection('requests').where('messId', isEqualTo: messId).get();
    for (var doc in requestsQuery.docs) {
      await doc.reference.delete();
    }

    // 4. Delete all join_requests docs for this messId
    final joinRequestsQuery = await _db.collection('join_requests').where('messId', isEqualTo: messId).get();
    for (var doc in joinRequestsQuery.docs) {
      await doc.reference.delete();
    }

    // 5. Delete all logs docs for this messId
    final logsQuery = await _db.collection('logs').where('messId', isEqualTo: messId).get();
    for (var doc in logsQuery.docs) {
      await doc.reference.delete();
    }

    // 6. Delete chat messages subcollection
    final messagesQuery = await _db.collection('messes').doc(messId).collection('messages').get();
    for (var doc in messagesQuery.docs) {
      await doc.reference.delete();
    }

    // 7. Delete meal_plan subcollection
    final mealPlanQuery = await _db.collection('messes').doc(messId).collection('meal_plan').get();
    for (var doc in mealPlanQuery.docs) {
      await doc.reference.delete();
    }

    // 8. Reset all users affiliated with this messId back to member and clear messId
    final usersQuery = await _db.collection('users').where('messId', isEqualTo: messId).get();
    for (var doc in usersQuery.docs) {
      await doc.reference.update({
        'messId': null,
        'role': UserRole.member.toString().split('.').last,
        'participationRole': null,
        'deposit': 0.0,
      });
    }

    // 9. Delete the mess document itself
    await _db.collection('messes').doc(messId).delete();
  }
}
