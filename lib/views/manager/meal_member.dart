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
  
  final double _mealRate = 50.0;
  final double _defaultDeposit = 2000.0;

  @override
  void initState() {
    super.initState();
    _loadData();
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

    _dbService.getMessMembers(messId).listen((members) {
      if (mounted) setState(() => _members = members);
    });

    _dbService.getMessMonthlyMeals(messId, now.year, now.month).listen((meals) {
      if (mounted) setState(() => _allMeals = meals);
    });
  }

  int _calculateMemberMeals(String userId) {
    int sum = 0;
    for (var meal in _allMeals) {
      if (meal.userId == userId) {
        if (meal.breakfast) sum += 1 + meal.guestBreakfast;
        if (meal.lunch) sum += 1 + meal.guestLunch;
        if (meal.dinner) sum += 1 + meal.guestDinner;
      }
    }
    return sum;
  }

  void _addDeposit(UserModel member) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text("Add Deposit for ${member.name}"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Amount"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty && _currentUser != null) {
                  double amount = double.tryParse(controller.text) ?? 0;
                  await _dbService.addLog(
                    _currentUser!.messId!, 
                    member.uid, 
                    "Manager added deposit: ₹$amount for ${member.name}"
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              }, 
              child: const Text("Add")
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Members'),
      ),
      body: _members.isEmpty 
        ? const Center(child: Text("No members found"))
        : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          int totalMeal = _calculateMemberMeals(member.uid);
          double balance = _defaultDeposit - (totalMeal * _mealRate);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                member.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deposit: ₹$_defaultDeposit'),
                      Text('Meals: $totalMeal'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Balance: ₹${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: balance >= 0 ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: _currentUser!.role == UserRole.manager || _currentUser!.role == UserRole.superAdmin
                ? IconButton(
                    icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _addDeposit(member),
                  )
                : null,
            ),
          );
        },
      ),
    );
  }
}
