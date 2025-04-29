import 'package:flutter/material.dart';

class AddMealPlanning extends StatefulWidget {
  const AddMealPlanning({super.key});

  @override
  State<AddMealPlanning> createState() => _AddMealPlanningState();
}

class _AddMealPlanningState extends State<AddMealPlanning> {
  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  late Map<String, Map<String, String>> meals;

  @override
  void initState() {
    super.initState();
    initializeMeals();
  }

  void initializeMeals() {
    meals = {};
    for (var day in days) {
      meals[day] = {
        'breakfast': '',
        'lunch': '',
        'dinner': '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planning'),
      ),
      body: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMealButton(day, 'breakfast'),
                      _buildMealButton(day, 'lunch'),
                      _buildMealButton(day, 'dinner'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealButton(String day, String mealType) {
    final mealText = meals[day]![mealType]!;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue,
          ),
          onPressed: () => _editMeal(context, day, mealType),
          child: Text(
            mealText.isEmpty ? 'Edit $mealType' : mealText,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _editMeal(BuildContext context, String day, String mealType) async {
    final currentMeal = meals[day]![mealType]!;
    final newMeal = await showDialog<String>(
      context: context,
      builder: (context) => MealEditDialog(initialMeal: currentMeal),
    );

    if (newMeal != null && newMeal != currentMeal) {
      setState(() {
        meals[day]![mealType] = newMeal;
      });
    }
  }
}

class MealEditDialog extends StatefulWidget {
  final String initialMeal;

  const MealEditDialog({super.key, required this.initialMeal});

  @override
  State<MealEditDialog> createState() => _MealEditDialogState();
}

class _MealEditDialogState extends State<MealEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMeal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Meal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Enter your meal',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSpecialMealButton('Oatmeal'),
              _buildSpecialMealButton('Salad'),
              _buildSpecialMealButton('Pizza'),
              _buildSpecialMealButton('Grilled Chicken'),
              _buildSpecialMealButton('Pasta'),
              _buildSpecialMealButton('Sandwich'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSpecialMealButton(String meal) {
    return OutlinedButton(
      onPressed: () {
        _controller.text = meal;
      },
      child: Text(meal),
    );
  }
}