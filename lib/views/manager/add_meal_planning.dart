import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_plan_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class AddMealPlanning extends StatefulWidget {
  const AddMealPlanning({super.key});

  @override
  State<AddMealPlanning> createState() => _AddMealPlanningState();
}

class _AddMealPlanningState extends State<AddMealPlanning> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  final List<String> days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final Map<String, TextEditingController> _breakfastControllers = {};
  final Map<String, TextEditingController> _lunchControllers = {};
  final Map<String, TextEditingController> _dinnerControllers = {};

  @override
  void initState() {
    super.initState();
    for (var day in days) {
      _breakfastControllers[day] = TextEditingController();
      _lunchControllers[day] = TextEditingController();
      _dinnerControllers[day] = TextEditingController();
    }
    _loadData();
  }

  void _loadData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        _user = UserModel.fromMap(userDoc.data()!);
        if (_user!.messId != null) {
          final plan = await _dbService.getMealPlan(_user!.messId!).first;
          for (var dayPlan in plan) {
            _breakfastControllers[dayPlan.day]?.text = dayPlan.breakfast;
            _lunchControllers[dayPlan.day]?.text = dayPlan.lunch;
            _dinnerControllers[dayPlan.day]?.text = dayPlan.dinner;
          }
        }
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _breakfastControllers.values) {
      controller.dispose();
    }
    for (var controller in _lunchControllers.values) {
      controller.dispose();
    }
    for (var controller in _dinnerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _savePlan() async {
    if (_user == null || _user!.messId == null) return;

    List<MealPlanModel> plan = [];
    for (var day in days) {
      plan.add(MealPlanModel(
        day: day,
        breakfast: _breakfastControllers[day]!.text,
        lunch: _lunchControllers[day]!.text,
        dinner: _dinnerControllers[day]!.text,
      ));
    }

    setState(() => _isLoading = true);
    await _dbService.updateMealPlan(_user!.messId!, plan);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal plan updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Weekly Menu'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _savePlan),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                  _buildInputField("Breakfast", _breakfastControllers[day]!),
                  _buildInputField("Lunch", _lunchControllers[day]!),
                  _buildInputField("Dinner", _dinnerControllers[day]!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
