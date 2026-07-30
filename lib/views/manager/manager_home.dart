import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../models/meal_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'add_meal_planning.dart';
import 'add_shopping.dart';
import 'manager_messaging.dart';
import 'meal_member.dart';
import '../member/history.dart';
import '../member/profile.dart';
import '../member/transaction.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  UserModel? _manager;
  final DateTime today = DateTime.now();
  List<int> selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;
  double totalDeposit = 5000.0;
  double mealRate = 50.0;

  List<UserModel> _members = [];
  List<RequestModel> _pendingRequests = [];
  final Map<int, List<MealModel>> _monthlyMeals = {};

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  void _loadManagerData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _manager = UserModel.fromMap(doc.data()!);
        });
        _listenToData();
      }
    }
  }

  void _listenToData() {
    if (_manager == null || _manager!.messId == null) return;
    String messId = _manager!.messId!;

    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    FirebaseFirestore.instance.collection('messes').doc(messId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          totalDeposit = (doc.data()?['totalDeposit'] ?? 5000.0).toDouble();
          mealRate = (doc.data()?['mealRate'] ?? 50.0).toDouble();
        });
      }
    });

    _dbService.getPendingRequests(messId).listen((requests) {
      if (mounted) setState(() => _pendingRequests = requests);
    });

    FirebaseFirestore.instance.collection('meals')
        .where('messId', isEqualTo: messId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(today.year, today.month, 1)))
        .where('date', isLessThan: Timestamp.fromDate(DateTime(today.year, today.month + 1, 1)))
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _monthlyMeals.clear();
          for (var doc in snapshot.docs) {
            MealModel meal = MealModel.fromMap(doc.data());
            _monthlyMeals.putIfAbsent(meal.date.day, () => []).add(meal);
          }
        });
      }
    });
  }

  int get totalMeals {
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

  double get availableBalance => totalDeposit - (totalMeals * mealRate);

  void _showSingleDayUsers(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final dayMeals = _monthlyMeals[day] ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Users for Day $day',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final meal = dayMeals.firstWhere(
                      (m) => m.userId == member.uid, 
                      orElse: () => MealModel(id: "", userId: member.uid, messId: "", date: DateTime.now())
                    );
                    return ListTile(
                      title: Text(member.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Breakfast: ${meal.breakfast ? 1 : 0} (${meal.guestBreakfast} guest)'),
                          Text('Lunch: ${meal.lunch ? 1 : 0} (${meal.guestLunch} guest)'),
                          Text('Dinner: ${meal.dinner ? 1 : 0} (${meal.guestDinner} guest)'),
                        ],
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

  void _showMultiDayUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Meal Details for Selected Days (${selectedDays.join(', ')})',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    int totalBreakfast = 0;
                    int totalLunch = 0;
                    int totalDinner = 0;
                    int totalGuestBreakfast = 0;
                    int totalGuestLunch = 0;
                    int totalGuestDinner = 0;

                    for (var day in selectedDays) {
                      final dayMeals = _monthlyMeals[day] ?? [];
                      final meal = dayMeals.firstWhere(
                        (m) => m.userId == member.uid, 
                        orElse: () => MealModel(id: "", userId: member.uid, messId: "", date: DateTime.now())
                      );
                      if (meal.id.isNotEmpty) {
                        totalBreakfast += meal.breakfast ? 1 : 0;
                        totalLunch += meal.lunch ? 1 : 0;
                        totalDinner += meal.dinner ? 1 : 0;
                        totalGuestBreakfast += meal.guestBreakfast;
                        totalGuestLunch += meal.guestLunch;
                        totalGuestDinner += meal.guestDinner;
                      }
                    }

                    return ListTile(
                      title: Text(member.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Breakfast: $totalBreakfast (${totalGuestBreakfast} guests)'),
                          Text('Lunch: $totalLunch (${totalGuestLunch} guests)'),
                          Text('Dinner: $totalDinner (${totalGuestDinner} guests)'),
                        ],
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

  void _showRequestsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Pending Requests"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: _pendingRequests.isEmpty 
                  ? const Center(child: Text("No pending requests"))
                  : ListView.builder(
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final req = _pendingRequests[index];
                      final user = _members.firstWhere(
                        (m) => m.uid == req.userId, 
                        orElse: () => UserModel(uid: "", name: "Unknown", email: "", role: UserRole.member, status: "")
                      );
                      return ListTile(
                        title: Text("${user.name} - ${req.date.day}/${req.date.month}"),
                        subtitle: Text(req.mealsRequested.entries.where((e) => e.value).map((e) => e.key).join(", ")),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green), 
                              onPressed: () async {
                                if (_manager != null) {
                                  await _dbService.approveRequest(req.id, _manager!.uid);
                                }
                              }
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red), 
                              onPressed: () async {
                                if (_manager != null) {
                                  await _dbService.rejectRequest(req.id, _manager!.uid);
                                }
                              }
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_manager == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isMultiSelectMode ? Colors.green[100] : Colors.yellow[100],
        leading: isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () {
                  setState(() {
                    isMultiSelectMode = false;
                    selectedDays.clear();
                  });
                },
              )
            : null,
        title: Text(
          isMultiSelectMode ? "${selectedDays.length} Selected" : "Meal Assistant",
          style: const TextStyle(
              color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black),
              onPressed: selectedDays.isNotEmpty
                  ? () => _showMultiDayUsers(context)
                  : null,
            )
          else ...[
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.black),
                  onPressed: () => _showRequestsDialog(context),
                ),
                if (_pendingRequests.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.message, color: Colors.black),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManagerMessaging()),
              ),
            ),
          ],
        ],
      ),
      drawer: isMultiSelectMode ? null : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.yellow[100],
              ),
              child: const Text(
                'Meal Assistant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Profile()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Meal member'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MealMember()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Transaction'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Transaction()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Meal planning'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMealPlanning()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shop),
              title: const Text('Shopping'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddShopping()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Meal History'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const History()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/user home.jpeg"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, 0,
              0, 1, 0, 0, 0,
              0, 0, 1, 0, 0,
              0, 0, 0, 0.5, 0,
            ]),
          ),
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
                    bool isToday = day == today.day;
                    bool isSelected = selectedDays.contains(day);
                    bool isSingleSelected = selectedDay == day && !isMultiSelectMode;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isMultiSelectMode) {
                            if (isSelected) {
                              selectedDays.remove(day);
                              if (selectedDays.isEmpty) {
                                isMultiSelectMode = false;
                              }
                            } else {
                              selectedDays.add(day);
                            }
                          } else {
                            selectedDay = day;
                            _showSingleDayUsers(context, day);
                          }
                        });
                      },
                      onLongPress: () {
                        if (!isMultiSelectMode) {
                          setState(() {
                            isMultiSelectMode = true;
                            selectedDays.add(day);
                          });
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isMultiSelectMode && isSelected
                                    ? Colors.green.withValues(alpha: 0.8)
                                    : isToday
                                    ? Colors.blue.withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8.0),
                                border: isSingleSelected
                                    ? Border.all(color: Colors.greenAccent, width: 2)
                                    : isToday
                                    ? Border.all(color: Colors.blueAccent, width: 2)
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
                                          color: (isMultiSelectMode && isSelected) || isToday
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    () {
                                      final dayMeals = _monthlyMeals[day] ?? [];
                                      int b = 0, l = 0, d = 0;
                                      int gb = 0, gl = 0, gd = 0;
                                      for (var meal in dayMeals) {
                                        if (meal.breakfast) { b++; gb += meal.guestBreakfast; }
                                        if (meal.lunch) { l++; gl += meal.guestLunch; }
                                        if (meal.dinner) { d++; gd += meal.guestDinner; }
                                      }
                                      return "B:$b${gb > 0 ? '($gb)' : ''}\n"
                                             "L:$l${gl > 0 ? '($gl)' : ''}\n"
                                             "D:$d${gd > 0 ? '($gd)' : ''}";
                                    }(),
                                    style: TextStyle(
                                      color: (isMultiSelectMode && isSelected) || isToday
                                          ? Colors.white
                                          : Colors.grey[800],
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
                            if (isMultiSelectMode)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? Colors.white : Colors.white70,
                                  size: 16,
                                ),
                              ),
                          ],
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
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
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
                      _buildStatCard("Total Deposit", "₹${totalDeposit.toStringAsFixed(2)}", Colors.green),
                      _buildStatCard("Available Balance", "₹${availableBalance.toStringAsFixed(2)}", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate", "₹${mealRate.toStringAsFixed(2)}", Colors.orange),
                      _buildStatCard("Total Meals", totalMeals.toString(), Colors.purple),
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
        color: color.withValues(alpha: 0.2),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
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
