import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'add_meal_planning.dart';
import 'add_shopping.dart';
import 'manager_messaging.dart';
import 'meal_member.dart';

import '../admin/admin_home.dart';
import '../member/profile.dart';
import '../member/meal_requests.dart';
import '../member/user_home.dart';
import '../../core/app_colors.dart';

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
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<int> selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;
  double totalShoppingCost = 0.0;

  List<UserModel> _members = [];
  List<RequestModel> _pendingRequests = [];
  final Map<int, List<MealModel>> _monthlyMeals = {};

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

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

    _dbService.getMonthlyShoppingTotal(messId, _selectedMonth.year, _selectedMonth.month).listen((shoppingTotal) {
      if (mounted) setState(() => totalShoppingCost = shoppingTotal);
    });

    _dbService.getPendingRequests(messId).listen((requests) {
      if (mounted) setState(() => _pendingRequests = requests);
    });

    FirebaseFirestore.instance.collection('meals')
        .where('messId', isEqualTo: messId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(_selectedMonth.year, _selectedMonth.month, 1)))
        .where('date', isLessThan: Timestamp.fromDate(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)))
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

  bool _isDefaultMealOn(UserModel? user, DateTime selectedMonth, int day) {
    DateTime now = DateTime.now();
    DateTime joinDate = user?.createdAt ?? DateTime(now.year, now.month, 1);
    
    if (selectedMonth.year < joinDate.year || 
       (selectedMonth.year == joinDate.year && selectedMonth.month < joinDate.month)) {
      return false;
    }
    
    if (selectedMonth.year > now.year || 
       (selectedMonth.year == now.year && selectedMonth.month > now.month)) {
      return false;
    }
    
    if (selectedMonth.year == joinDate.year && selectedMonth.month == joinDate.month) {
      if (day < joinDate.day) {
        return false;
      }
    }
    
    return true;
  }

  int get maxElapsedDay {
    if (_selectedMonth.year < today.year || 
       (_selectedMonth.year == today.year && _selectedMonth.month < today.month)) {
      return DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    } else if (_selectedMonth.year == today.year && _selectedMonth.month == today.month) {
      return today.day;
    } else {
      return 0;
    }
  }

  int get totalElapsedMeals {
    int sum = 0;
    int limit = maxElapsedDay;
    for (int d = 1; d <= limit; d++) {
      final dayMeals = _monthlyMeals[d] ?? [];
      for (var member in _members) {
        bool defaultOn = _isDefaultMealOn(member, _selectedMonth, d);
        final meal = dayMeals.firstWhere(
          (m) => m.userId == member.uid,
          orElse: () => MealModel(
            id: "", userId: member.uid, messId: "",
            date: DateTime(_selectedMonth.year, _selectedMonth.month, d),
            breakfast: false, lunch: defaultOn, dinner: defaultOn,
          ),
        );
        if (meal.breakfast) sum += 1;
        sum += meal.guestBreakfast;
        if (meal.lunch) sum += 1;
        sum += meal.guestLunch;
        if (meal.dinner) sum += 1;
        sum += meal.guestDinner;
      }
    }
    return sum;
  }

  int get totalMeals => totalElapsedMeals;

  double get totalDeposit => _members.fold(0.0, (totalSum, m) => totalSum + m.deposit);
  double get mealRate => totalElapsedMeals > 0 ? (totalShoppingCost / totalElapsedMeals) : 0.0;
  double get availableBalance => totalDeposit - totalShoppingCost;

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
                      orElse: () => MealModel(
                        id: "", userId: member.uid, messId: "", 
                        date: DateTime(_selectedMonth.year, _selectedMonth.month, day),
                        breakfast: false, lunch: true, dinner: true,
                      )
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
                          Text('Breakfast: $totalBreakfast ($totalGuestBreakfast guests)'),
                          Text('Lunch: $totalLunch ($totalGuestLunch guests)'),
                          Text('Dinner: $totalDinner ($totalGuestDinner guests)'),
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
                              icon: const Icon(Icons.check, color: AppColors.success), 
                              onPressed: () async {
                                if (_manager != null) {
                                  await _dbService.approveRequest(req.id, _manager!.uid);
                                }
                              }
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.error), 
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
        backgroundColor: isMultiSelectMode 
            ? Theme.of(context).colorScheme.secondaryContainer 
            : Theme.of(context).colorScheme.primaryContainer,
        leading: isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
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
        ),
        centerTitle: true,
        actions: [
          if (isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: selectedDays.isNotEmpty
                  ? () => _showMultiDayUsers(context)
                  : null,
            )
          else ...[
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => _showRequestsDialog(context),
                ),
                if (_pendingRequests.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
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
              icon: const Icon(Icons.person_pin),
              tooltip: 'My Personal Meals',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserHome()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message),
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
            UserAccountsDrawerHeader(
              accountName: Text(
                _manager?.name ?? 'Manager',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              accountEmail: Text(
                _manager?.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                child: Text(
                  _manager?.name.isNotEmpty == true ? _manager!.name[0].toUpperCase() : 'M',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_pin, color: AppColors.primary),
              title: const Text('My Personal Meals'),
              subtitle: const Text('View & edit your personal meals as a member'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserHome()),
                );
              },
            ),
            const Divider(),
            if (_manager?.role == UserRole.superAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                title: const Text('Super Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminHome()),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Profile()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Members & Deposits'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MealMember()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Meal planning'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddMealPlanning()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shop),
              title: const Text('Shopping'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddShopping()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Meal Requests History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MealRequestsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                        _listenToData();
                      });
                    },
                  ),
                  Text(
                    "${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                        _listenToData();
                      });
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Mess Meals: $totalElapsedMeals (Days 1 - $maxElapsedDay)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person, size: 14),
                    label: const Text("My Personal Meals", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserHome()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month),
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    bool isToday = day == today.day && _selectedMonth.year == today.year && _selectedMonth.month == today.month;
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
                                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                                    : isToday
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8.0),
                                border: isSingleSelected
                                    ? Border.all(color: Theme.of(context).colorScheme.secondary, width: 2)
                                    : isToday
                                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                    : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$day",
                                        style: TextStyle(
                                          color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                          fontSize: 16,
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
                                            if (_members.isNotEmpty) {
                                              for (var member in _members) {
                                                bool defaultOn = _isDefaultMealOn(member, _selectedMonth, day);
                                                final meal = dayMeals.firstWhere(
                                                  (m) => m.userId == member.uid,
                                                  orElse: () => MealModel(
                                                    id: "", userId: member.uid, messId: "",
                                                    date: DateTime(_selectedMonth.year, _selectedMonth.month, day),
                                                    breakfast: false, lunch: defaultOn, dinner: defaultOn,
                                                  ),
                                                );
                                                if (meal.breakfast) b++;
                                                gb += meal.guestBreakfast;
                                                if (meal.lunch) l++;
                                                gl += meal.guestLunch;
                                                if (meal.dinner) d++;
                                                gd += meal.guestDinner;
                                              }
                                            } else {
                                              for (var meal in dayMeals) {
                                                if (meal.breakfast) { b++; gb += meal.guestBreakfast; }
                                                if (meal.lunch) { l++; gl += meal.guestLunch; }
                                                if (meal.dinner) { d++; gd += meal.guestDinner; }
                                              }
                                            }
                                            int totalDayMeals = (b + gb) + (l + gl) + (d + gd);
                                            return "Total: $totalDayMeals\n"
                                                   "B: ${b + gb}\n"
                                                   "L: ${l + gl}\n"
                                                   "D: ${d + gd}";
                                          }(),
                                          style: TextStyle(
                                            color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w800,
                                            height: 1.15,
                                          ),
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 5,
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
                                  color: isSelected ? AppColors.success : Theme.of(context).colorScheme.outline,
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
                      _buildStatCard("Total Deposit", "৳${totalDeposit.toStringAsFixed(2)}", AppColors.success, onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MealMember()));
                      }),
                      _buildStatCard("Available Balance", "৳${availableBalance.toStringAsFixed(2)}", Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate", "৳${mealRate.toStringAsFixed(2)}", AppColors.warning),
                      _buildStatCard("Total Meals", totalMeals.toString(), AppColors.info),
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

  Widget _buildStatCard(String title, String value, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
                    color: Theme.of(context).colorScheme.outline,
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
      ),
    );
  }
}
