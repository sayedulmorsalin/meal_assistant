import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../models/meal_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../manager/manager_home.dart';
import '../admin/admin_home.dart';
import 'history.dart';
import 'meal_planning.dart';
import 'profile.dart';
import 'shopping.dart';
import 'transaction.dart';
import '../../core/app_colors.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  final Map<int, MealModel?> _monthlyMeals = {};
  final Map<int, RequestModel?> _pendingRequests = {};
  UserModel? _user;

  final DateTime today = DateTime.now();
  List<int> selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;

  double totalDeposit = 5000.0;
  double mealRate = 50.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _user = UserModel.fromMap(doc.data()!);
          });
          _listenToMeals();
        }
      });
    }
  }

  void _listenToMeals() {
    if (_user == null || _user!.messId == null) return;
    String messId = _user!.messId!;
    
    FirebaseFirestore.instance.collection('messes').doc(messId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          totalDeposit = (doc.data()?['totalDeposit'] ?? 5000.0).toDouble();
          mealRate = (doc.data()?['mealRate'] ?? 50.0).toDouble();
        });
      }
    });

    _dbService.getUserMonthlyMeals(_user!.uid, today.year, today.month).listen((meals) {
      if (mounted) {
        setState(() {
          _monthlyMeals.clear();
          for (var meal in meals) {
            _monthlyMeals[meal.date.day] = meal;
          }
        });
      }
    });

    _dbService.getUserPendingRequests(_user!.uid).listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests.clear();
          for (var req in requests) {
            if (req.date.year == today.year && req.date.month == today.month) {
              _pendingRequests[req.date.day] = req;
            }
          }
        });
      }
    });
  }

  int get totalMeals {
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

  double get availableBalance => totalDeposit - (totalMeals * mealRate);

  void _showDateDetails(BuildContext context, [int? day]) {
    if (day == null && selectedDays.isEmpty) return;

    MealModel? initialMeal = day != null ? _monthlyMeals[day] : _monthlyMeals[selectedDays.first];
    bool breakfast = initialMeal?.breakfast ?? false;
    bool lunch = initialMeal?.lunch ?? false;
    bool dinner = initialMeal?.dinner ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: day != null
                  ? Text("Edit Day $day")
                  : Text("Edit ${selectedDays.length} Days"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMealSwitch("Breakfast", breakfast, (value) {
                    setDialogState(() => breakfast = value);
                  }),
                  _buildMealSwitch("Lunch", lunch, (value) {
                    setDialogState(() => lunch = value);
                  }),
                  _buildMealSwitch("Dinner", dinner, (value) {
                    setDialogState(() => dinner = value);
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showGuestMealDialog(context, day: day);
                        },
                        child: const Text("Add Guest Meal"),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            Map<String, bool> requested = {
                              'breakfast': breakfast,
                              'lunch': lunch,
                              'dinner': dinner,
                            };

                            if (_user != null && (_user!.role == UserRole.manager || _user!.role == UserRole.superAdmin)) {
                              for (int d in (day != null ? [day] : selectedDays)) {
                                DateTime date = DateTime(today.year, today.month, d);
                                MealModel? existing = _monthlyMeals[d];
                                MealModel newMeal = MealModel(
                                  id: existing?.id ?? FirebaseFirestore.instance.collection('meals').doc().id,
                                  userId: _user!.uid,
                                  messId: _user!.messId!,
                                  date: date,
                                  breakfast: breakfast,
                                  lunch: lunch,
                                  dinner: dinner,
                                  guestBreakfast: existing?.guestBreakfast ?? 0,
                                  guestLunch: existing?.guestLunch ?? 0,
                                  guestDinner: existing?.guestDinner ?? 0,
                                );
                                await _dbService.updateMealStatus(newMeal);
                              }
                            } else if (_user != null) {
                              for (int d in (day != null ? [day] : selectedDays)) {
                                DateTime date = DateTime(today.year, today.month, d);
                                await _dbService.createMealRequest(_user!.uid, _user!.messId!, date, requested);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent to manager")));
                              }
                            }
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          if (day == null) {
            selectedDays.clear();
            isMultiSelectMode = false;
          }
        });
      }
    });
  }

  void _showGuestMealDialog(BuildContext context, {int? day}) {
    bool isMultiSelect = selectedDays.isNotEmpty;
    if (isMultiSelect && selectedDays.isEmpty) return;

    MealModel? initialMeal = day != null ? _monthlyMeals[day] : (selectedDays.isNotEmpty ? _monthlyMeals[selectedDays.first] : null);
    int breakfastValue = initialMeal?.guestBreakfast ?? 0;
    int lunchValue = initialMeal?.guestLunch ?? 0;
    int dinnerValue = initialMeal?.guestDinner ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: isMultiSelect
                  ? Text("Add Guest Meals to ${selectedDays.length} Days")
                  : Text("Add Guest Meal to Day $day"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGuestMealDropdown("Breakfast", breakfastValue,
                          (v) => setDialogState(() => breakfastValue = v)),
                  _buildGuestMealDropdown("Lunch", lunchValue,
                          (v) => setDialogState(() => lunchValue = v)),
                  _buildGuestMealDropdown("Dinner", dinnerValue,
                          (v) => setDialogState(() => dinnerValue = v)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                           if (_user != null) {
                            for (int d in (day != null ? [day] : selectedDays)) {
                              DateTime date = DateTime(today.year, today.month, d);
                              MealModel? existing = _monthlyMeals[d];
                              MealModel newMeal = MealModel(
                                id: existing?.id ?? FirebaseFirestore.instance.collection('meals').doc().id,
                                userId: _user!.uid,
                                messId: _user!.messId!,
                                date: date,
                                breakfast: existing?.breakfast ?? false,
                                lunch: existing?.lunch ?? false,
                                dinner: existing?.dinner ?? false,
                                guestBreakfast: breakfastValue,
                                guestLunch: lunchValue,
                                guestDinner: dinnerValue,
                              );
                              await _dbService.updateMealStatus(newMeal);
                            }
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
       if (mounted) setState(() {});
    });
  }

  Widget _buildMealSwitch(
      String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMealDropdown(
      String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          DropdownButton<int>(
            value: value,
            items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text("$i"))),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
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
              icon: const Icon(Icons.edit),
              onPressed: selectedDays.isNotEmpty
                  ? () => _showDateDetails(context)
                  : null,
            )
          else
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerHome()),
                );
              },
            ),
        ],
      ),
      drawer: isMultiSelectMode ? null : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Text(
                'Meal Assistant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_user?.role == UserRole.superAdmin)
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
              leading: const Icon(Icons.list_alt),
              title: const Text('Transaction'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Transaction()),
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
                  MaterialPageRoute(builder: (context) => const MealPlanning()),
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
                  MaterialPageRoute(builder: (context) => const Shopping()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Meal History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const History()),
                );
              },
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
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
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
                    bool isSingleSelected =
                        selectedDay == day && !isMultiSelectMode;

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
                            _showDateDetails(context, day);
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMultiSelectMode && isSelected
                                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                                : isToday
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: isSingleSelected
                                ? Border.all(
                                color: Theme.of(context).colorScheme.secondary, width: 2)
                                : isToday
                                ? Border.all(
                                color: Theme.of(context).colorScheme.primary, width: 2)
                                : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$day",
                                      style: TextStyle(
                                        color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_pendingRequests.containsKey(day))
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                          color: AppColors.warning,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "P",
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (isMultiSelectMode)
                                Icon(
                                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                                        color: isSelected ? AppColors.success : Theme.of(context).colorScheme.outline,
                                        size: 14,
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  _monthlyMeals[day] == null 
                                      ? "B:0\nL:0\nD:0"
                                      : "B:${_monthlyMeals[day]!.breakfast ? '1' : '0'}${_monthlyMeals[day]!.guestBreakfast != 0 ? '(${_monthlyMeals[day]!.guestBreakfast})' : ''}\n"
                                        "L:${_monthlyMeals[day]!.lunch ? '1' : '0'}${_monthlyMeals[day]!.guestLunch != 0 ? '(${_monthlyMeals[day]!.guestLunch})' : ''}\n"
                                        "D:${_monthlyMeals[day]!.dinner ? '1' : '0'}${_monthlyMeals[day]!.guestDinner != 0 ? '(${_monthlyMeals[day]!.guestDinner})' : ''}",
                                  style: TextStyle(
                                    color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                                const Spacer(),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
                          "₹${totalDeposit.toStringAsFixed(2)}", AppColors.success),
                      _buildStatCard("Available Balance",
                          "₹${availableBalance.toStringAsFixed(2)}", Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "₹${mealRate.toStringAsFixed(2)}", AppColors.warning),
                      _buildStatCard(
                          "Total Meals", totalMeals.toString(), AppColors.info),
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
    );
  }
}
