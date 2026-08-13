import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
  bool _isFullCalendarView = false;

  double _monthlyShoppingTotal = 0.0;
  List<MealModel> _allMessMeals = [];

  bool get _canAccessManagerView {
    if (_user == null) return false;
    if (_user!.role == UserRole.manager) return true;
    if (_user!.role == UserRole.superAdmin) {
      return _user!.participationRole == UserRole.manager;
    }
    return false;
  }

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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showDateDetails(BuildContext context, [int? day]) {
    if (day == null && selectedDays.isEmpty) return;

    int targetDay = day ?? (selectedDays.isNotEmpty ? selectedDays.first : 1);
    MealModel? initialMeal = _monthlyMeals[targetDay];
    RequestModel? pendingReq = _pendingRequests[targetDay];

    bool defaultOn = _isDefaultMealOn(_user, _selectedMonth, targetDay);
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
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      day != null
                          ? "Meals for Day $day"
                          : "${selectedDays.length} Days Selected",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      pendingReq != null
                          ? "You have a pending request for this day. You can update your request below:"
                          : "Toggle meals on or off. Your request will be sent to the Mess Manager for approval:",
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        _buildMealSwitch("🍳 Breakfast", breakfast, (value) {
                          setDialogState(() => breakfast = value);
                        }),
                        const Divider(height: 1),
                        _buildMealSwitch("🍛 Lunch", lunch, (value) {
                          setDialogState(() => lunch = value);
                        }),
                        const Divider(height: 1),
                        _buildMealSwitch("🍽️ Dinner", dinner, (value) {
                          setDialogState(() => dinner = value);
                        }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14.0),
                    child: Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          _showGuestMealDialog(context, day: day);
                        },
                        label: const Text("Add Guest Meals"),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Meal request sent to Mess Manager for approval!"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
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

    int targetDay = day ?? (selectedDays.isNotEmpty ? selectedDays.first : 1);
    MealModel? initialMeal = _monthlyMeals[targetDay];
    int breakfastValue = initialMeal?.guestBreakfast ?? 0;
    int lunchValue = initialMeal?.guestLunch ?? 0;
    int dinnerValue = initialMeal?.guestDinner ?? 0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people, color: AppColors.info, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMultiSelect
                          ? "Guest Meals (${selectedDays.length} Days)"
                          : "Guest Meals (Day $day)",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        _buildGuestMealDropdown("🍳 Breakfast", breakfastValue,
                                (v) => setDialogState(() => breakfastValue = v)),
                        const Divider(height: 1),
                        _buildGuestMealDropdown("🍛 Lunch", lunchValue,
                                (v) => setDialogState(() => lunchValue = v)),
                        const Divider(height: 1),
                        _buildGuestMealDropdown("🍽️ Dinner", dinnerValue,
                                (v) => setDialogState(() => dinnerValue = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Guest meal request sent to Mess Manager for approval!"),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
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

  Widget _buildMealSwitch(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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

  Widget _buildGuestMealDropdown(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(10),
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Leave Mess?"),
        content: const Text("Are you sure you want to leave this mess? You will no longer see data from this mess."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (_user?.messId != null) {
                await _dbService.leaveMess(_user!.uid, _user!.messId!);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
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

    final bool isCurrentMonth = _selectedMonth.year == today.year && _selectedMonth.month == today.month;
    final int todayDay = today.day;
    final MealModel? todayMeal = isCurrentMonth ? _monthlyMeals[todayDay] : null;
    final RequestModel? todayPending = isCurrentMonth ? _pendingRequests[todayDay] : null;
    final bool todayDefault = _isDefaultMealOn(_user, _selectedMonth, todayDay);

    final bool todayBreakfast = todayPending != null
        ? (todayPending.mealsRequested['breakfast'] ?? false)
        : (todayMeal?.breakfast ?? false);
    final bool todayLunch = todayPending != null
        ? (todayPending.mealsRequested['lunch'] ?? todayDefault)
        : (todayMeal?.lunch ?? todayDefault);
    final bool todayDinner = todayPending != null
        ? (todayPending.mealsRequested['dinner'] ?? todayDefault)
        : (todayMeal?.dinner ?? todayDefault);
    final int todayGuest = (todayMeal?.guestBreakfast ?? 0) + (todayMeal?.guestLunch ?? 0) + (todayMeal?.guestDinner ?? 0);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isMultiSelectMode
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surface,
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
        title: isMultiSelectMode
            ? Text("${selectedDays.length} Days Selected", style: const TextStyle(fontSize: 18))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.rice_bowl, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text("Meal Assistant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
        centerTitle: false,
        actions: [
          if (_canAccessManagerView)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
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
              icon: const Icon(Icons.edit_calendar),
              onPressed: selectedDays.isNotEmpty ? () => _showDateDetails(context) : null,
            )
          else
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Mess Chat',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Masseging()),
                );
              },
            ),
        ],
      ),
      drawer: isMultiSelectMode ? null : _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async {
          _listenToMeals();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canAccessManagerView)
                _buildRoleBanner(context),
              _buildGreetingHero(context),
              const SizedBox(height: 16),
              if (isCurrentMonth) ...[
                _buildTodayMealCard(
                  context,
                  breakfast: todayBreakfast,
                  lunch: todayLunch,
                  dinner: todayDinner,
                  guestTotal: todayGuest,
                  isPending: todayPending != null,
                  day: todayDay,
                ),
                const SizedBox(height: 16),
              ],
              if (_pendingRequests.isNotEmpty && !isCurrentMonth)
                _buildPendingAlert(context),
              _buildStatsGrid(context),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildScheduleSection(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHero(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${_getGreeting()},",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                Text(
                  _user?.name ?? 'Member',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Profile())),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              backgroundImage: _user?.profileImage != null && _user!.profileImage!.isNotEmpty
                  ? NetworkImage(_user!.profileImage!)
                  : null,
              child: _user?.profileImage == null || _user!.profileImage!.isEmpty
                  ? Text(
                      _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealCard(
    BuildContext context, {
    required bool breakfast,
    required bool lunch,
    required bool dinner,
    required int guestTotal,
    required bool isPending,
    required int day,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.today, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Today's Meals",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text("Pending Approval", style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMealStatusChip(context, "Breakfast", breakfast, Icons.wb_twilight),
              const SizedBox(width: 8),
              _buildMealStatusChip(context, "Lunch", lunch, Icons.wb_sunny_outlined),
              const SizedBox(width: 8),
              _buildMealStatusChip(context, "Dinner", dinner, Icons.nightlight_outlined),
            ],
          ),
          if (guestTotal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "👥 +$guestTotal Guest Meal(s) today",
                style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text("Edit Today's Meals", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showDateDetails(context, day),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text("Guest Meal", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showGuestMealDialog(context, day: day),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealStatusChip(BuildContext context, String label, bool isOn, IconData icon) {
    final color = isOn ? AppColors.success : Theme.of(context).colorScheme.outline;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isOn ? AppColors.success.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOn ? AppColors.success.withValues(alpha: 0.4) : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isOn ? AppColors.success : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isOn ? "ON" : "OFF",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isOn ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingAlert(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You have ${_pendingRequests.length} pending meal request(s).",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealRequestsScreen())),
            child: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "My Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "Days 1 - $maxElapsedDay",
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                title: "Available Balance",
                value: "৳${availableBalance.toStringAsFixed(2)}",
                subtitle: availableBalance < 0 ? "Deposit required" : "Healthy balance",
                color: availableBalance >= 0 ? AppColors.primary : AppColors.error,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                title: "Total Deposit",
                value: "৳${userDeposit.toStringAsFixed(2)}",
                subtitle: "This month",
                color: AppColors.success,
                icon: Icons.savings_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                title: "Meal Rate",
                value: "৳${mealRate.toStringAsFixed(2)}",
                subtitle: "Per mess meal",
                color: AppColors.warning,
                icon: Icons.calculate_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                title: "My Total Meals",
                value: "$totalMeals",
                subtitle: "Consumed to date",
                color: AppColors.info,
                icon: Icons.restaurant_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Shortcuts",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(
              icon: Icons.chat_bubble_outline,
              label: "Chat",
              color: AppColors.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Masseging())),
            ),
            _buildActionItem(
              icon: Icons.menu_book_outlined,
              label: "Meal Plan",
              color: AppColors.info,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealPlanning())),
            ),
            _buildActionItem(
              icon: Icons.shopping_bag_outlined,
              label: "Shopping",
              color: AppColors.success,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Shopping())),
            ),
            _buildActionItem(
              icon: Icons.assignment_outlined,
              label: "Requests",
              color: AppColors.warning,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealRequestsScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(BuildContext context) {
    final theme = Theme.of(context);
    final int daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                        _listenToMeals();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                        _listenToMeals();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isFullCalendarView ? "Monthly Grid View" : "Recent Days Strip",
                style: TextStyle(fontSize: 13, color: theme.colorScheme.outline, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  if (!isMultiSelectMode)
                    TextButton.icon(
                      icon: const Icon(Icons.checklist, size: 15),
                      label: const Text("Multi-select", style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          isMultiSelectMode = true;
                          _isFullCalendarView = true;
                        });
                      },
                    ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    icon: Icon(_isFullCalendarView ? Icons.unfold_less : Icons.calendar_view_month, size: 14),
                    label: Text(_isFullCalendarView ? "Show Less" : "Full Month", style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFullCalendarView = !_isFullCalendarView;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_isFullCalendarView)
            _buildHorizontalDaysStrip(context, daysInMonth)
          else
            _buildFullMonthCalendarGrid(context, daysInMonth),
        ],
      ),
    );
  }

  Widget _buildHorizontalDaysStrip(BuildContext context, int daysInMonth) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 95,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daysInMonth,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          int day = index + 1;
          DateTime date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          String weekday = DateFormat('E').format(date);
          bool isToday = day == today.day && _selectedMonth.year == today.year && _selectedMonth.month == today.month;
          bool isSelected = selectedDays.contains(day);
          MealModel? meal = _monthlyMeals[day];
          bool defaultOn = _isDefaultMealOn(_user, _selectedMonth, day);
          bool bOn = meal?.breakfast ?? false;
          bool lOn = meal?.lunch ?? defaultOn;
          bool dOn = meal?.dinner ?? defaultOn;
          bool hasPending = _pendingRequests.containsKey(day);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isMultiSelectMode) {
                  if (isSelected) {
                    selectedDays.remove(day);
                    if (selectedDays.isEmpty) isMultiSelectMode = false;
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
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : isToday
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                          ? AppColors.primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: isToday || isSelected ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppColors.primary : theme.colorScheme.outline,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$day",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? AppColors.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (hasPending)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMealDot(bOn, "B"),
                        const SizedBox(width: 3),
                        _buildMealDot(lOn, "L"),
                        const SizedBox(width: 3),
                        _buildMealDot(dOn, "D"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealDot(bool isOn, String label) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: isOn ? AppColors.success : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isOn ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildFullMonthCalendarGrid(BuildContext context, int daysInMonth) {
    final theme = Theme.of(context);
    final List<String> weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays
              .map((w) => SizedBox(
                    width: 32,
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6.0,
            crossAxisSpacing: 6.0,
            childAspectRatio: 0.68,
          ),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            int day = index + 1;
            bool isToday = day == today.day && _selectedMonth.year == today.year && _selectedMonth.month == today.month;
            bool isSelected = selectedDays.contains(day);
            bool isSingleSelected = selectedDay == day && !isMultiSelectMode;
            MealModel? meal = _monthlyMeals[day];
            bool defaultOn = _isDefaultMealOn(_user, _selectedMonth, day);
            bool hasPending = _pendingRequests.containsKey(day);

            bool b = meal?.breakfast ?? false;
            bool l = meal?.lunch ?? defaultOn;
            bool d = meal?.dinner ?? defaultOn;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isMultiSelectMode) {
                    if (isSelected) {
                      selectedDays.remove(day);
                      if (selectedDays.isEmpty) isMultiSelectMode = false;
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
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                      : isToday
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10.0),
                  border: isSingleSelected
                      ? Border.all(color: theme.colorScheme.secondary, width: 2)
                      : isToday
                          ? Border.all(color: theme.colorScheme.primary, width: 2)
                          : Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$day",
                            style: TextStyle(
                              color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasPending)
                            Container(
                              margin: const EdgeInsets.only(left: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                "P",
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (isMultiSelectMode)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? AppColors.success : theme.colorScheme.outline,
                                size: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMealDot(b, "B"),
                          const SizedBox(width: 2),
                          _buildMealDot(l, "L"),
                          const SizedBox(width: 2),
                          _buildMealDot(d, "D"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
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
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
            leading: const Icon(Icons.list_alt),
            title: const Text('Meal Planning'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MealPlanning()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
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
          if (_canAccessManagerView)
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
        ],
      ),
    );
  }
}
