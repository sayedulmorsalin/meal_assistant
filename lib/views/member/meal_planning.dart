import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_plan_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class MealPlanning extends StatefulWidget {
  const MealPlanning({super.key});

  @override
  State<MealPlanning> createState() => _MealPlanningState();
}

class _MealPlanningState extends State<MealPlanning> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _user = UserModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_user == null || _user!.messId == null) return const Scaffold(body: Center(child: Text("Error: Not in a mess")));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Menu'),
      ),
      body: StreamBuilder<List<MealPlanModel>>(
        stream: _dbService.getMealPlan(_user!.messId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No menu set yet."));
          }

          final plan = snapshot.data!;
          // Sort plan to ensure consistent order (Monday to Sunday)
          const daysOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          plan.sort((a, b) => daysOrder.indexOf(a.day).compareTo(daysOrder.indexOf(b.day)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plan.length,
            itemBuilder: (context, index) {
              final dayPlan = plan[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayPlan.day,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Divider(),
                      _buildMealRow('Breakfast', dayPlan.breakfast),
                      _buildMealRow('Lunch', dayPlan.lunch),
                      _buildMealRow('Dinner', dayPlan.dinner),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMealRow(String mealType, String mealName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              mealType,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              mealName.isEmpty ? 'Not set' : mealName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
