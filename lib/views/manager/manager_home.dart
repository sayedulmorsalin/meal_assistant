import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  List<int> selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;
  double totalShoppingCost = 0.0;
  bool _isFullCalendarView = false;

  List<UserModel> _members = [];
  List<RequestModel> _pendingRequests = [];
  final Map<int, List<MealModel>> _monthlyMeals = {};

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  bool get _canAccessManagerView {
    if (_manager == null) return false;
    if (_manager!.role == UserRole.manager) return true;
    if (_manager!.role == UserRole.superAdmin) {
      return _manager!.participationRole == UserRole.manager;
    }
    return false;
  }

  void _loadManagerData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          UserModel user = UserModel.fromMap(doc.data()!);
          bool canAccess = user.role == UserRole.manager ||
              (user.role == UserRole.superAdmin && user.participationRole == UserRole.manager);

          if (!canAccess) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UserHome()),
              );
            }
            return;
          }

          setState(() {
            _manager = user;
          });
          if (_members.isEmpty) {
            _listenToData();
          }
        }
      });
    }
  }

  void _listenToData() {
    if (_manager == null || _manager!.messId == null) return;
    String messId = _manager!.messId!;

    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    _dbService
        .getMonthlyShoppingTotal(
          messId,
          _selectedMonth.year,
          _selectedMonth.month,
        )
        .listen((shoppingTotal) {
          if (mounted) setState(() => totalShoppingCost = shoppingTotal);
        });

    _dbService.getPendingRequests(messId).listen((requests) {
      if (mounted) setState(() => _pendingRequests = requests);
    });

    FirebaseFirestore.instance
        .collection('meals')
        .where('messId', isEqualTo: messId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(_selectedMonth.year, _selectedMonth.month, 1),
          ),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(
            DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1),
          ),
        )
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
        (selectedMonth.year == joinDate.year &&
            selectedMonth.month < joinDate.month)) {
      return false;
    }

    if (selectedMonth.year > now.year ||
        (selectedMonth.year == now.year && selectedMonth.month > now.month)) {
      return false;
    }

    if (selectedMonth.year == joinDate.year &&
        selectedMonth.month == joinDate.month) {
      if (day < joinDate.day) {
        return false;
      }
    }

    return true;
  }

  int get maxElapsedDay {
    if (_selectedMonth.year < today.year ||
        (_selectedMonth.year == today.year &&
            _selectedMonth.month < today.month)) {
      return DateUtils.getDaysInMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
    } else if (_selectedMonth.year == today.year &&
        _selectedMonth.month == today.month) {
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
          orElse:
              () => MealModel(
                id: "",
                userId: member.uid,
                messId: "",
                date: DateTime(_selectedMonth.year, _selectedMonth.month, d),
                breakfast: false,
                lunch: defaultOn,
                dinner: defaultOn,
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

  double get totalDeposit =>
      _members.fold(0.0, (totalSum, m) => totalSum + m.deposit);
  double get mealRate =>
      totalElapsedMeals > 0 ? (totalShoppingCost / totalElapsedMeals) : 0.0;
  double get availableBalance => totalDeposit - totalShoppingCost;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Map<String, int> _getDayMealCounts(int day) {
    final dayMeals = _monthlyMeals[day] ?? [];
    int b = 0, l = 0, d = 0;
    int gb = 0, gl = 0, gd = 0;
    if (_members.isNotEmpty) {
      for (var member in _members) {
        bool defaultOn = _isDefaultMealOn(member, _selectedMonth, day);
        final meal = dayMeals.firstWhere(
          (m) => m.userId == member.uid,
          orElse:
              () => MealModel(
                id: "",
                userId: member.uid,
                messId: "",
                date: DateTime(_selectedMonth.year, _selectedMonth.month, day),
                breakfast: false,
                lunch: defaultOn,
                dinner: defaultOn,
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
        if (meal.breakfast) {
          b++;
          gb += meal.guestBreakfast;
        }
        if (meal.lunch) {
          l++;
          gl += meal.guestLunch;
        }
        if (meal.dinner) {
          d++;
          gd += meal.guestDinner;
        }
      }
    }
    return {
      'breakfast': b + gb,
      'lunch': l + gl,
      'dinner': d + gd,
      'total': (b + gb) + (l + gl) + (d + gd),
    };
  }

  void _showSingleDayUsers(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final dayMeals = _monthlyMeals[day] ?? [];
        final counts = _getDayMealCounts(day);

        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members on Day $day',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Total: ${counts['total']} meals",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Breakfast: ${counts['breakfast']} | Lunch: ${counts['lunch']} | Dinner: ${counts['dinner']}",
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final meal = dayMeals.firstWhere(
                      (m) => m.userId == member.uid,
                      orElse:
                          () => MealModel(
                            id: "",
                            userId: member.uid,
                            messId: "",
                            date: DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month,
                              day,
                            ),
                            breakfast: false,
                            lunch: true,
                            dinner: true,
                          ),
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          _buildMealMiniBadge("B", meal.breakfast, meal.guestBreakfast),
                          const SizedBox(width: 6),
                          _buildMealMiniBadge("L", meal.lunch, meal.guestLunch),
                          const SizedBox(width: 6),
                          _buildMealMiniBadge("D", meal.dinner, meal.guestDinner),
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

  Widget _buildMealMiniBadge(String label, bool isOn, int guest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOn ? AppColors.success.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOn ? AppColors.success.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Text(
        "$label: ${isOn ? 1 : 0}${guest > 0 ? ' (+$guest)' : ''}",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOn ? AppColors.success : Colors.grey[600],
        ),
      ),
    );
  }

  void _showMultiDayUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meal Breakdown (${selectedDays.length} Days Selected)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
                        orElse:
                            () => MealModel(
                              id: "",
                              userId: member.uid,
                              messId: "",
                              date: DateTime.now(),
                            ),
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
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Breakfast: $totalBreakfast (+$totalGuestBreakfast guests) | '
                        'Lunch: $totalLunch (+$totalGuestLunch guests) | '
                        'Dinner: $totalDinner (+$totalGuestDinner guests)',
                        style: const TextStyle(fontSize: 12),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.pending_actions, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text("Pending Requests (${_pendingRequests.length})"),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child:
                    _pendingRequests.isEmpty
                        ? const Center(child: Text("No pending meal requests"))
                        : ListView.separated(
                          itemCount: _pendingRequests.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final req = _pendingRequests[index];
                            final user = _members.firstWhere(
                              (m) => m.uid == req.userId,
                              orElse:
                                  () => UserModel(
                                    uid: "",
                                    name: "Unknown",
                                    email: "",
                                    role: UserRole.member,
                                    status: "",
                                  ),
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "${user.name} • ${req.date.day}/${req.date.month}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                req.mealsRequested.entries
                                    .where((e) => e.value)
                                    .map((e) => e.key.toUpperCase())
                                    .join(", "),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    ),
                                    onPressed: () async {
                                      if (_manager != null) {
                                        await _dbService.approveRequest(
                                          req.id,
                                          _manager!.uid,
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () async {
                                      if (_manager != null) {
                                        await _dbService.rejectRequest(
                                          req.id,
                                          _manager!.uid,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_manager == null || !_canAccessManagerView) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isCurrentMonth = _selectedMonth.year == today.year && _selectedMonth.month == today.month;
    final int todayDay = today.day;
    final Map<String, int> todayCounts = isCurrentMonth ? _getDayMealCounts(todayDay) : {};

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isMultiSelectMode
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surface,
        leading:
            isMultiSelectMode
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
                    child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text("Manager Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
        centerTitle: false,
        actions: [
          if (isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed:
                  selectedDays.isNotEmpty
                      ? () => _showMultiDayUsers(context)
                      : null,
            )
          else ...[
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Meal Requests',
                  onPressed: () => _showRequestsDialog(context),
                ),
                if (_pendingRequests.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Mess Chat',
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManagerMessaging(),
                    ),
                  ),
            ),
          ],
        ],
      ),
      drawer: isMultiSelectMode ? null : _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async {
          _listenToData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManagerHero(context),
              const SizedBox(height: 16),
              if (_pendingRequests.isNotEmpty) ...[
                _buildPendingRequestsBanner(context),
                const SizedBox(height: 16),
              ],
              if (isCurrentMonth) ...[
                _buildTodayMessOverviewCard(context, todayCounts, todayDay),
                const SizedBox(height: 16),
              ],
              _buildFinancialStatsGrid(context),
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

  Widget _buildManagerHero(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              OutlinedButton.icon(
                icon: const Icon(Icons.person_pin, size: 14, color: Colors.white),
                label: const Text("My Personal Meals", style: TextStyle(fontSize: 11, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  side: const BorderSide(color: Colors.white70),
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
          const SizedBox(height: 10),
          Text(
            "${_getGreeting()},",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          Text(
            _manager?.name ?? 'Manager',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: AppColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_pendingRequests.length} Pending Meal Requests",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Members submitted changes awaiting approval",
                  style: TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showRequestsDialog(context),
            child: const Text("Review", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMessOverviewCard(BuildContext context, Map<String, int> counts, int day) {
    final theme = Theme.of(context);
    final total = counts['total'] ?? 0;
    final b = counts['breakfast'] ?? 0;
    final l = counts['lunch'] ?? 0;
    final d = counts['dinner'] ?? 0;

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
                  Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text("Today's Mess Meals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$total Total Servings",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMealCountPill(context, "Breakfast", b, Icons.wb_twilight),
              const SizedBox(width: 8),
              _buildMealCountPill(context, "Lunch", l, Icons.wb_sunny_outlined),
              const SizedBox(width: 8),
              _buildMealCountPill(context, "Dinner", d, Icons.nightlight_outlined),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.people_outline, size: 16),
              label: const Text("View Member List for Today", style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showSingleDayUsers(context, day),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCountPill(BuildContext context, String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "$count",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialStatsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Mess Performance Summary",
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
                title: "Total Deposit",
                value: "৳${totalDeposit.toStringAsFixed(2)}",
                subtitle: "${_members.length} active members",
                color: AppColors.success,
                icon: Icons.savings_outlined,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MealMember()));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                title: "Available Balance",
                value: "৳${availableBalance.toStringAsFixed(2)}",
                subtitle: availableBalance < 0 ? "Deficit" : "Surplus",
                color: availableBalance >= 0 ? AppColors.primary : AppColors.error,
                icon: Icons.account_balance_wallet_outlined,
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
                title: "Total Mess Meals",
                value: "$totalElapsedMeals",
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
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Management Shortcuts",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(
              icon: Icons.people_alt_outlined,
              label: "Members",
              color: AppColors.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealMember())),
            ),
            _buildActionItem(
              icon: Icons.shopping_bag_outlined,
              label: "Add Expense",
              color: AppColors.success,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddShopping())),
            ),
            _buildActionItem(
              icon: Icons.menu_book_outlined,
              label: "Meal Plan",
              color: AppColors.info,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMealPlanning())),
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
                        _listenToData();
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
                        _listenToData();
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
                _isFullCalendarView ? "Monthly Breakdown" : "Recent Days Strip",
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
          final counts = _getDayMealCounts(day);
          int totalDayMeals = counts['total'] ?? 0;

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
            child: Container(
              width: 70,
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
                  Text(
                    "$day",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$totalDayMeals meals",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
            childAspectRatio: 0.70,
          ),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            int day = index + 1;
            bool isToday = day == today.day && _selectedMonth.year == today.year && _selectedMonth.month == today.month;
            bool isSelected = selectedDays.contains(day);
            bool isSingleSelected = selectedDay == day && !isMultiSelectMode;
            final counts = _getDayMealCounts(day);
            int total = counts['total'] ?? 0;
            int b = counts['breakfast'] ?? 0;
            int l = counts['lunch'] ?? 0;
            int d = counts['dinner'] ?? 0;

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
                      child: Text(
                        "Tot: $total",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "B:$b L:$l D:$d",
                        style: TextStyle(
                          fontSize: 8,
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
            leading: const Icon(Icons.list_alt),
            title: const Text('Meal Planning'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMealPlanning()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Shopping Expenses'),
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
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Mess Chat'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManagerMessaging()),
              );
            },
          ),
        ],
      ),
    );
  }
}
