import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryAdmin extends StatefulWidget {
  const HistoryAdmin({super.key});

  @override
  State<HistoryAdmin> createState() => _HistoryAdminState();
}

class _HistoryAdminState extends State<HistoryAdmin> {
  final Map<int, String> _calendarData = {};
  final DateTime _today = DateTime.now();
  final double _totalDeposit = 5000.0;
  final double _mealRate = 50.0;

  // Mock user data
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'John Doe',
      'meals': {
        1: '1,0|1,0|1,0',
        2: '0,1|1,0|0,1',
        3: '1,0|1,1|1,0',
      },
      'details': 'Room 101, Vegetarian'
    },
    {
      'name': 'Jane Smith',
      'meals': {
        1: '0,1|1,0|0,0',
        2: '1,0|1,1|1,0',
        3: '0,0|1,0|1,1',
      },
      'details': 'Room 102, Non-vegetarian'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    for (int day = 1; day <= 31; day++) {
      _calendarData[day] = "0,0|0,0|0,0";
    }
    // Set sample data
    _calendarData[5] = "1,0|1,1|1,0";
    _calendarData[12] = "1,0|0,0|1,2";
    _calendarData[15] = "1,1|1,0|1,0";
  }

  int get _totalMeals {
    int sum = 0;
    _calendarData.forEach((key, value) {
      List<String> meals = value.split('|');
      for (var meal in meals) {
        List<String> parts = meal.split(',');
        sum += int.parse(parts[0]) + int.parse(parts[1]);
      }
    });
    return sum;
  }

  double get _availableBalance => _totalDeposit - (_totalMeals * _mealRate);

  void _showDayDetails(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Meal Details for Day $day',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final meals = user['meals'][day]?.split('|') ?? ['0,0', '0,0', '0,0'];
                    return ListTile(
                      title: Text(user['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Breakfast: ${meals[0].split(',')[0]} (${meals[0].split(',')[1]} guest)'),
                          Text('Lunch: ${meals[1].split(',')[0]} (${meals[1].split(',')[1]} guest)'),
                          Text('Dinner: ${meals[2].split(',')[0]} (${meals[2].split(',')[1]} guest)'),
                        ],
                      ),
                      trailing: Text(user['details'],
                          style: TextStyle(color: Colors.grey[600])),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History (Admin)'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4.0,
                    crossAxisSpacing: 4.0,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: 31,
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    bool isToday = day == _today.day;

                    return GestureDetector(
                      onTap: () => _showDayDetails(context, day),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8.0),
                            border: isToday
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$day",
                                    style: TextStyle(
                                      color: isToday ? Colors.blue : Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      _calendarData[day]!
                                          .split('|')
                                          .asMap()
                                          .entries
                                          .map((e) {
                                        List<String> parts = e.value.split(',');
                                        return "${['B', 'L', 'D'][e.key]}:${parts[0]}${parts[1] != '0' ? '(+${parts[1]})' : ''}";
                                      }).join('\n'),
                                      style: TextStyle(
                                        color: isToday ? Colors.blue : Colors.grey[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.left,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 3,
                                    ),
                                  ),
                                ],
                              ),
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
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
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
                          "৳${_totalDeposit.toStringAsFixed(2)}", Colors.green),
                      _buildStatCard("Available Balance",
                          "৳${_availableBalance.toStringAsFixed(2)}", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "৳${_mealRate.toStringAsFixed(2)}", Colors.orange),
                      _buildStatCard(
                          "Total Meals", _totalMeals.toString(), Colors.purple),
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
        color: color.withOpacity(0.1),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
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