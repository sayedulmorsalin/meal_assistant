import 'package:flutter/material.dart';

class MealPlanning extends StatefulWidget {
  const MealPlanning({super.key});

  @override
  State<MealPlanning> createState() => _MealPlanningState();
}

class _MealPlanningState extends State<MealPlanning> {
  final Map<String, Map<String, String>> mealData = {};

  @override
  void initState() {
    super.initState();
    _initMealData();
  }

  void _initMealData() {
    // Sample data - will be replaced with database data
    mealData.addAll({
      'Monday': {
        'breakfast': 'Oatmeal with Fruits',
        'lunch': 'Grilled Chicken Salad',
        'dinner': 'Vegetable Stir-Fry'
      },
      'Tuesday': {
        'breakfast': 'Avocado Toast',
        'lunch': 'Quinoa Bowl',
        'dinner': 'Salmon with Asparagus'
      },
      'Wednesday': {
        'breakfast': 'Greek Yogurt Parfait',
        'lunch': 'Turkey Sandwich',
        'dinner': 'Pasta Primavera'
      },
      'Thursday': {
        'breakfast': 'Smoothie Bowl',
        'lunch': 'Caesar Salad',
        'dinner': 'Beef Tacos'
      },
      'Friday': {
        'breakfast': 'Pancakes',
        'lunch': 'Sushi Platter',
        'dinner': 'Margherita Pizza'
      },
      'Saturday': {
        'breakfast': 'Eggs Benedict',
        'lunch': 'BBQ Burger',
        'dinner': 'Lasagna'
      },
      'Sunday': {
        'breakfast': 'French Toast',
        'lunch': 'Roast Chicken',
        'dinner': 'Seafood Paella'
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Plan'),
        centerTitle: true,
      ),
      body: ListView(
        children: _buildDayCards(),
      ),
    );
  }

  List<Widget> _buildDayCards() {
    return mealData.entries.map((entry) {
      final day = entry.key;
      final meals = entry.value;

      return Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Divider(),
              _buildMealRow('Breakfast', meals['breakfast']!),
              _buildMealRow('Lunch', meals['lunch']!),
              _buildMealRow('Dinner', meals['dinner']!),
            ],
          ),
        ),
      );
    }).toList();
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              mealName,
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