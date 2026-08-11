import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/models/meal_model.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';
import '../../core/app_colors.dart';

class MealMember extends StatefulWidget {
  const MealMember({super.key});

  @override
  State<MealMember> createState() => _MealMemberState();
}

class _MealMemberState extends State<MealMember> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  List<UserModel> _members = [];
  List<MealModel> _allMeals = [];
  
  double _monthlyShoppingTotal = 0.0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() => _currentUser = UserModel.fromMap(doc.data()!));
        _listenToData();
      }
    }
  }

  void _listenToData() {
    if (_currentUser == null || _currentUser!.messId == null) return;
    String messId = _currentUser!.messId!;
    DateTime now = DateTime.now();

    _dbService.getMonthlyShoppingTotal(messId, now.year, now.month).listen((shoppingTotal) {
      if (mounted) setState(() => _monthlyShoppingTotal = shoppingTotal);
    });

    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    _dbService.getMessMonthlyMeals(messId, now.year, now.month).listen((meals) {
      if (mounted) setState(() => _allMeals = meals);
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

  int get _maxElapsedDay {
    DateTime now = DateTime.now();
    return now.day;
  }

  int get _totalMessElapsedMeals {
    DateTime now = DateTime.now();
    int limit = _maxElapsedDay;
    int sum = 0;
    for (int d = 1; d <= limit; d++) {
      if (_members.isNotEmpty) {
        for (var member in _members) {
          bool defaultOn = _isDefaultMealOn(member, now, d);
          final meal = _allMeals.firstWhere(
            (m) => m.userId == member.uid && m.date.day == d,
            orElse: () => MealModel(
              id: "", userId: member.uid, messId: "",
              date: DateTime(now.year, now.month, d),
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
        for (var meal in _allMeals) {
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

  int _calculateMemberElapsedMeals(UserModel member) {
    DateTime now = DateTime.now();
    int limit = _maxElapsedDay;
    int sum = 0;

    for (int d = 1; d <= limit; d++) {
      bool defaultOn = _isDefaultMealOn(member, now, d);
      final meal = _allMeals.firstWhere(
        (m) => m.userId == member.uid && m.date.day == d,
        orElse: () => MealModel(
          id: "", userId: member.uid, messId: "",
          date: DateTime(now.year, now.month, d),
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
    return sum;
  }

  double get _mealRate => _totalMessElapsedMeals > 0 ? (_monthlyShoppingTotal / _totalMessElapsedMeals) : 0.0;

  void _addDeposit(UserModel member) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Deposit for ${member.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Deposit: ৳${member.deposit.toStringAsFixed(2)}",
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Deposit Amount",
                  hintText: "Enter amount (e.g. 500)",
                  prefixText: "৳ ",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty && _currentUser != null) {
                  double amount = double.tryParse(controller.text) ?? 0;
                  if (amount > 0) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    await _dbService.addMemberDeposit(
                      _currentUser!.messId!,
                      member.uid,
                      member.name,
                      amount,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("৳${amount.toStringAsFixed(2)} added to ${member.name}'s deposit"),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    nav.pop();
                  } else {
                    Navigator.pop(context);
                  }
                }
              }, 
              child: const Text("Add Deposit"),
            ),
          ],
        );
      },
    );
  }

  void _showGeneralAddDepositDialog() {
    if (_members.isEmpty) return;
    UserModel selectedMember = _members.first;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Member Deposit"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Member:"),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedMember,
                    items: _members.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMember = val);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Deposit Amount",
                      hintText: "Enter amount (e.g. 1000)",
                      prefixText: "৳ ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.isNotEmpty && _currentUser != null) {
                      double amount = double.tryParse(controller.text) ?? 0;
                      if (amount > 0) {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(context);
                        await _dbService.addMemberDeposit(
                          _currentUser!.messId!,
                          selectedMember.uid,
                          selectedMember.name,
                          amount,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text("৳${amount.toStringAsFixed(2)} added to ${selectedMember.name}'s deposit"),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        nav.pop();
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  }, 
                  child: const Text("Add Deposit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRemoveMember(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove ${member.name} from the mess?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (_currentUser?.messId != null) {
                await _dbService.removeMember(member.uid, _currentUser!.messId!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${member.name} has been removed from the mess."),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isManager = _currentUser!.role == UserRole.manager || _currentUser!.role == UserRole.superAdmin;
    final filteredMembers = _members.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members & Deposits'),
      ),
      floatingActionButton: isManager && _members.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showGeneralAddDepositDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add Deposit"),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search member by name...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ) 
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: filteredMembers.isEmpty 
              ? const Center(child: Text("No members found"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    int totalMeal = _calculateMemberElapsedMeals(member);
                    double totalCost = totalMeal * _mealRate;
                    double balance = member.deposit - totalCost;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  backgroundImage: member.profileImage != null && member.profileImage!.isNotEmpty
                                      ? NetworkImage(member.profileImage!)
                                      : null,
                                  child: member.profileImage == null || member.profileImage!.isEmpty
                                      ? Text(
                                          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      Text(
                                        member.email,
                                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                 if (isManager) ...[
                                   ElevatedButton.icon(
                                     onPressed: () => _addDeposit(member),
                                     icon: const Icon(Icons.account_balance_wallet, size: 16),
                                     label: const Text("Add Deposit"),
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.success,
                                       foregroundColor: Colors.white,
                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                     ),
                                   ),
                                   if (member.uid != _currentUser?.uid)
                                     IconButton(
                                       icon: const Icon(Icons.person_remove, color: AppColors.error, size: 20),
                                       onPressed: () => _confirmRemoveMember(member),
                                       tooltip: "Remove from mess",
                                     ),
                                 ],
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Meals: $totalMeal", style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text("Cost: ৳${totalCost.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Deposit: ৳${member.deposit.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      "Balance: ৳${balance.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: balance >= 0 ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
