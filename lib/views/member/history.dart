import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/meal_model.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  final Map<int, MealModel?> _monthlyMeals = {};
  UserModel? _user;
  final DateTime _today = DateTime.now();
  final double _totalDeposit = 5000.0;
  final double _mealRate = 50.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _user = UserModel.fromMap(doc.data()!);
        });
        _listenToMeals();
      }
    }
  }

  void _listenToMeals() {
    if (_user == null || _user!.messId == null) return;
    _dbService.getUserMonthlyMeals(_user!.uid, _today.year, _today.month).listen((meals) {
      if (mounted) {
        setState(() {
          _monthlyMeals.clear();
          for (var meal in meals) {
            _monthlyMeals[meal.date.day] = meal;
          }
        });
      }
    });
  }

  int get _totalMeals {
    int sum = 0;
    _monthlyMeals.forEach((key, meal) {
      if (meal != null) {
        if (meal.breakfast) sum += 1 + meal.guestBreakfast;
        if (meal.lunch) sum += 1 + meal.guestLunch;
        if (meal.dinner) sum += 1 + meal.guestDinner;
      }
    });
    return sum;
  }

  double get _availableBalance => _totalDeposit - (_totalMeals * _mealRate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: 31,
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    bool isToday = day == _today.day;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8.0),
                          border: isToday
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$day",
                                  style: TextStyle(
                                    color: isToday ? Colors.blue : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    _monthlyMeals[day] == null 
                                        ? "B:0\nL:0\nD:0"
                                        : "B:${_monthlyMeals[day]!.breakfast ? '1' : '0'}${_monthlyMeals[day]!.guestBreakfast != 0 ? '(+${_monthlyMeals[day]!.guestBreakfast})' : ''}\n"
                                          "L:${_monthlyMeals[day]!.lunch ? '1' : '0'}${_monthlyMeals[day]!.guestLunch != 0 ? '(+${_monthlyMeals[day]!.guestLunch})' : ''}\n"
                                          "D:${_monthlyMeals[day]!.dinner ? '1' : '0'}${_monthlyMeals[day]!.guestDinner != 0 ? '(+${_monthlyMeals[day]!.guestDinner})' : ''}",
                                    style: TextStyle(
                                      color: isToday ? Colors.blue : Colors.grey[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                    textAlign: TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Total Deposit",
                          "৳${_totalDeposit.toStringAsFixed(2)}", Colors.green),
                      _buildStatCard("Available Balance",
                          "৳${_availableBalance.toStringAsFixed(2)}", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "৳${_mealRate.toStringAsFixed(2)}", Colors.orange),
                      _buildStatCard(
                          "Total Meals", _totalMeals.toString(), Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}