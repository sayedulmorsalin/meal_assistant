import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../core/app_colors.dart';

class HistoryAdmin extends StatefulWidget {
  const HistoryAdmin({super.key});

  @override
  State<HistoryAdmin> createState() => _HistoryAdminState();
}

class _HistoryAdminState extends State<HistoryAdmin> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  UserModel? _user;
  bool _isLoading = true;
  final DateTime _today = DateTime.now();
  
  double _totalDeposit = 5000.0;
  double _mealRate = 50.0;
  
  List<UserModel> _members = [];
  final Map<int, List<MealModel>> _monthlyMeals = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _user = UserModel.fromMap(doc.data()!));
        _listenToData();
      }
    }
  }

  void _listenToData() {
    if (_user == null || _user!.messId == null) return;
    String messId = _user!.messId!;

    FirebaseFirestore.instance.collection('messes').doc(messId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _totalDeposit = (doc.data()?['totalDeposit'] ?? 5000.0).toDouble();
          _mealRate = (doc.data()?['mealRate'] ?? 50.0).toDouble();
        });
      }
    });

    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    _dbService.getMessMonthlyMeals(messId, _today.year, _today.month).listen((meals) {
      if (mounted) {
        setState(() {
          _monthlyMeals.clear();
          for (var meal in meals) {
            _monthlyMeals.putIfAbsent(meal.date.day, () => []).add(meal);
          }
          _isLoading = false;
        });
      }
    });
  }

  int get _totalMeals {
    int sum = 0;
    _monthlyMeals.forEach((day, meals) {
      for (var meal in meals) {
        if (meal.breakfast) sum += 1 + meal.guestBreakfast;
        if (meal.lunch) sum += 1 + meal.guestLunch;
        if (meal.dinner) sum += 1 + meal.guestDinner;
      }
    });
    return sum;
  }

  double get _availableBalance => _totalDeposit - (_totalMeals * _mealRate);

  void _showDayDetails(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final dayMeals = _monthlyMeals[day] ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Meal Details for Day $day',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final meal = dayMeals.firstWhere(
                      (m) => m.userId == member.uid,
                      orElse: () => MealModel(id: "", userId: member.uid, messId: "", date: DateTime.now()),
                    );
                    return ListTile(
                      title: Text(member.name),
                      subtitle: Text(
                        'B: ${meal.breakfast ? 1 : 0}(+${meal.guestBreakfast}), '
                        'L: ${meal.lunch ? 1 : 0}(+${meal.guestLunch}), '
                        'D: ${meal.dinner ? 1 : 0}(+${meal.guestDinner})',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess History (Monthly)'),
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
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
                    final dayMeals = _monthlyMeals[day] ?? [];

                    int b = 0, l = 0, d = 0;
                    int gb = 0, gl = 0, gd = 0;
                    for (var meal in dayMeals) {
                      if (meal.breakfast) { b++; gb += meal.guestBreakfast; }
                      if (meal.lunch) { l++; gl += meal.guestLunch; }
                      if (meal.dinner) { d++; gd += meal.guestDinner; }
                    }

                    return GestureDetector(
                      onTap: () => _showDayDetails(context, day),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isToday
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: isToday
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                                      color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      "B:$b${gb > 0 ? '($gb)' : ''}\nL:$l${gl > 0 ? '($gl)' : ''}\nD:$d${gd > 0 ? '($gd)' : ''}",
                                      style: TextStyle(
                                        color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
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
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
                          "₹${_totalDeposit.toStringAsFixed(2)}", AppColors.success),
                      _buildStatCard("Available Balance",
                          "₹${_availableBalance.toStringAsFixed(2)}", Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "₹${_mealRate.toStringAsFixed(2)}", AppColors.warning),
                      _buildStatCard(
                          "Total Meals", _totalMeals.toString(), AppColors.info),
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
        color: color.withValues(alpha: 0.1),
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
                  color: Theme.of(context).colorScheme.outline,
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
