import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../admin/admin_home.dart';
import 'masseging.dart';
import 'meal_planning.dart';
import 'profile.dart';
import 'shopping.dart';
import 'meal_requests.dart';
import '../manager/manager_home.dart';
import '../../main.dart';
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
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<int> selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;

  double _monthlyShoppingTotal = 0.0;
  List<MealModel> _allMessMeals = [];

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<UserModel> _messMembers = [];

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
    
    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _messMembers = members);
    });

    _dbService.getMonthlyShoppingTotal(messId, _selectedMonth.year, _selectedMonth.month).listen((shoppingTotal) {
      if (mounted) setState(() => _monthlyShoppingTotal = shoppingTotal);
    });

    _dbService.getMessMonthlyMeals(messId, _selectedMonth.year, _selectedMonth.month).listen((messMeals) {
      if (mounted) setState(() => _allMessMeals = messMeals);
    });

    _dbService.getUserMonthlyMeals(_user!.uid, messId, _selectedMonth.year, _selectedMonth.month).listen((meals) {
      if (mounted) {
        setState(() {
          _monthlyMeals.clear();
          for (var meal in meals) {
            _monthlyMeals[meal.date.day] = meal;
          }
        });
      }
    });

    _dbService.getUserPendingRequests(_user!.uid, messId).listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests.clear();
          for (var req in requests) {
            if (req.date.year == _selectedMonth.year && req.date.month == _selectedMonth.month) {
              _pendingRequests[req.date.day] = req;
            }
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

  int get totalMessElapsedMeals {
    int sum = 0;
    int limit = maxElapsedDay;
    for (int d = 1; d <= limit; d++) {
      if (_messMembers.isNotEmpty) {
        for (var member in _messMembers) {
          bool defaultOn = _isDefaultMealOn(member, _selectedMonth, d);
          final meal = _allMessMeals.firstWhere(
            (m) => m.userId == member.uid && m.date.day == d,
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
      } else {
        for (var meal in _allMessMeals) {
          if (meal.date.day == d) {
            if (meal.breakfast) sum += 1 + meal.guestBreakfast;
            if (meal.lunch) sum += 1 + meal.guestLunch;
            if (meal.dinner) sum += 1 + meal.guestDinner;
          }
        }
      }
    }
    return sum;
  }

  int get userElapsedMeals {
    int sum = 0;
    int limit = maxElapsedDay;
    for (int d = 1; d <= limit; d++) {
      final meal = _monthlyMeals[d];
      if (meal != null) {
        if (meal.breakfast) sum += 1;
        sum += meal.guestBreakfast;
        if (meal.lunch) sum += 1;
        sum += meal.guestLunch;
        if (meal.dinner) sum += 1;
        sum += meal.guestDinner;
      } else {
        if (_isDefaultMealOn(_user, _selectedMonth, d)) {
          sum += 2;
        }
      }
    }
    return sum;
  }

  int get totalMeals => userElapsedMeals;

  double get mealRate => totalMessElapsedMeals > 0 ? (_monthlyShoppingTotal / totalMessElapsedMeals) : 0.0;
  double get userDeposit => _user?.deposit ?? 0.0;
  double get availableBalance => userDeposit - (userElapsedMeals * mealRate);

  void _showDateDetails(BuildContext context, [int? day]) {
    if (day == null && selectedDays.isEmpty) return;

    MealModel? initialMeal = day != null ? _monthlyMeals[day] : (selectedDays.isNotEmpty ? _monthlyMeals[selectedDays.first] : null);
    RequestModel? pendingReq = day != null ? _pendingRequests[day] : null;

    bool defaultOn = _isDefaultMealOn(_user, _selectedMonth, day ?? (selectedDays.isNotEmpty ? selectedDays.first : 1));
    bool breakfast = pendingReq != null 
        ? (pendingReq.mealsRequested['breakfast'] ?? false)
        : (initialMeal?.breakfast ?? false);
    bool lunch = pendingReq != null 
        ? (pendingReq.mealsRequested['lunch'] ?? defaultOn)
        : (initialMeal?.lunch ?? defaultOn);
    bool dinner = pendingReq != null 
        ? (pendingReq.mealsRequested['dinner'] ?? defaultOn)
        : (initialMeal?.dinner ?? defaultOn);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: day != null
                  ? Text("Request Meal Change for Day $day")
                  : Text("Request Meal Change for ${selectedDays.length} Days"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      pendingReq != null 
                          ? "You have a pending request for this day. You can update your request below:"
                          : "Toggle meals to turn ON or OFF. Your request will be sent to your Mess Manager for approval:",
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
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
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.person_add, size: 16),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showGuestMealDialog(context, day: day);
                        },
                        label: const Text("Add Guest Meal"),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Map<String, bool> requested = {
                            'breakfast': breakfast,
                            'lunch': lunch,
                            'dinner': dinner,
                          };

                          if (_user != null) {
                            for (int d in (day != null ? [day] : selectedDays)) {
                              DateTime date = DateTime(_selectedMonth.year, _selectedMonth.month, d);
                              await _dbService.createMealRequest(
                                _user!.uid, 
                                _user!.name, 
                                _user!.messId!, 
                                date, 
                                requested,
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Meal request sent to Mess Manager for approval!"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        label: const Text("Send Request"),
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
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (_user != null) {
                            for (int d in (day != null ? [day] : selectedDays)) {
                              DateTime date = DateTime(_selectedMonth.year, _selectedMonth.month, d);
                              MealModel? existing = _monthlyMeals[d];
                              Map<String, bool> requested = {
                                'breakfast': existing?.breakfast ?? false,
                                'lunch': existing?.lunch ?? false,
                                'dinner': existing?.dinner ?? false,
                              };
                              Map<String, int> guestRequested = {
                                'breakfast': breakfastValue,
                                'lunch': lunchValue,
                                'dinner': dinnerValue,
                              };
                              await _dbService.createMealRequest(
                                _user!.uid,
                                _user!.name,
                                _user!.messId!,
                                date,
                                requested,
                                guestMealsRequested: guestRequested,
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Guest meal request sent to Mess Manager for approval!"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        label: const Text("Send Request"),
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

  void _confirmLeaveMess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Mess?"),
        content: const Text("Are you sure you want to leave this mess? You will no longer see data from this mess."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (_user?.messId != null) {
                await _dbService.leaveMess(_user!.uid, _user!.messId!);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                    (route) => false,
                  );
                }
              }
            },
            child: const Text("Leave Mess", style: TextStyle(color: Colors.red)),
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
          if (_user?.role == UserRole.manager || _user?.role == UserRole.superAdmin)
            IconButton(
              icon: const Icon(Icons.dashboard),
              tooltip: 'Switch to Manager View',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ManagerHome()),
                  );
                }
              },
            ),
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
                  MaterialPageRoute(builder: (context) => const Masseging()),
                );
              },
            ),
        ],
      ),
      drawer: isMultiSelectMode ? null : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                _user?.name ?? 'Member',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              accountEmail: Text(
                _user?.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundImage: _user?.profileImage != null && _user!.profileImage!.isNotEmpty
                    ? NetworkImage(_user!.profileImage!)
                    : null,
                child: _user?.profileImage == null || _user!.profileImage!.isEmpty
                    ? Text(
                        _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
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
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Mess Chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Masseging()),
                );
              },
            ),
            if (_user?.role == UserRole.manager || _user?.role == UserRole.superAdmin)
              ListTile(
                leading: const Icon(Icons.dashboard, color: AppColors.primary),
                title: const Text('Manager Dashboard'),
                subtitle: const Text('Switch back to Manager view'),
                onTap: () {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ManagerHome()),
                    );
                  }
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: AppColors.error),
              title: const Text('Leave Mess', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _confirmLeaveMess();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await _authService.signOut();
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            if (_user?.role == UserRole.manager || _user?.role == UserRole.superAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Personal Member View",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.dashboard, size: 14),
                      label: const Text("Manager View", style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const ManagerHome()),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
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
                        _listenToMeals();
                      });
                    },
                  ),
                  Text(
                    "${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} (Days 1 - $maxElapsedDay)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                        _listenToMeals();
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month),
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    bool isToday = day == today.day && _selectedMonth.year == today.year && _selectedMonth.month == today.month;
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
                                        fontSize: 16,
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
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                                      ? (_isDefaultMealOn(_user, _selectedMonth, day) ? "B: 0\nL: 1\nD: 1" : "B: 0\nL: 0\nD: 0")
                                      : "B: ${_monthlyMeals[day]!.breakfast ? '1' : '0'}${_monthlyMeals[day]!.guestBreakfast != 0 ? '(${_monthlyMeals[day]!.guestBreakfast})' : ''}\n"
                                        "L: ${_monthlyMeals[day]!.lunch ? '1' : '0'}${_monthlyMeals[day]!.guestLunch != 0 ? '(${_monthlyMeals[day]!.guestLunch})' : ''}\n"
                                        "D: ${_monthlyMeals[day]!.dinner ? '1' : '0'}${_monthlyMeals[day]!.guestDinner != 0 ? '(${_monthlyMeals[day]!.guestDinner})' : ''}",
                                  style: TextStyle(
                                    color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
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
                          "৳${userDeposit.toStringAsFixed(2)}", AppColors.success),
                      _buildStatCard("Available Balance",
                          "৳${availableBalance.toStringAsFixed(2)}", Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "৳${mealRate.toStringAsFixed(2)}", AppColors.warning),
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
