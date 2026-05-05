import 'package:flutter/material.dart';
import 'package:mess_management/manager/add_meal_planning.dart';
import 'package:mess_management/manager/add_shopping.dart';
import 'package:mess_management/manager/manager_messaging.dart';
import 'package:mess_management/manager/meal_member.dart';
import 'package:mess_management/user/history.dart';
import 'package:mess_management/user/profile.dart';
import 'package:mess_management/user/transaction.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  final Map calendarData = {};
  final DateTime today = DateTime.now();
  List selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;
  double totalDeposit = 5000.0;
  double mealRate = 50.0;

  // Mock user data
  final List<Map<String, dynamic>> users = [
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
    for (int day = 1; day <= 31; day++) {
      calendarData[day] = "0,0|0,0|0,0";
    }
  }

  int get totalMeals {
    int sum = 0;
    calendarData.forEach((key, value) {
      List meals = value.split('|');
      for (var meal in meals) {
        List parts = meal.split(',');
        sum += int.parse(parts[0]) + int.parse(parts[1]);
      }
    });
    return sum;
  }

  double get availableBalance => totalDeposit - (totalMeals * mealRate);

  void _showSingleDayUsers(BuildContext context, int day) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Users for Day $day',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
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

  void _showMultiDayUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text('Meal Details for Selected Days (${selectedDays.join(', ')})',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    int totalBreakfast = 0;
                    int totalLunch = 0;
                    int totalDinner = 0;
                    int totalGuestBreakfast = 0;
                    int totalGuestLunch = 0;
                    int totalGuestDinner = 0;

                    for (var day in selectedDays) {
                      final meals = user['meals'][day]?.split('|') ?? ['0,0', '0,0', '0,0'];
                      // Breakfast
                      List breakfast = meals[0].split(',');
                      totalBreakfast += int.parse(breakfast[0]);
                      totalGuestBreakfast += int.parse(breakfast[1]);
                      // Lunch
                      List lunch = meals[1].split(',');
                      totalLunch += int.parse(lunch[0]);
                      totalGuestLunch += int.parse(lunch[1]);
                      // Dinner
                      List dinner = meals[2].split(',');
                      totalDinner += int.parse(dinner[0]);
                      totalGuestDinner += int.parse(dinner[1]);
                    }

                    return ListTile(
                      title: Text(user['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Breakfast: $totalBreakfast (${totalGuestBreakfast} guests)'),
                          Text('Lunch: $totalLunch (${totalGuestLunch} guests)'),
                          Text('Dinner: $totalDinner (${totalGuestDinner} guests)'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isMultiSelectMode ? Colors.green[100] : Colors.yellow[100],
        leading: isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
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
          style: const TextStyle(
              color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black),
              onPressed: selectedDays.isNotEmpty
                  ? () => _showMultiDayUsers(context)
                  : null,
            )
          else
            IconButton(
              icon: const Icon(Icons.message, color: Colors.black),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManagerMessaging()),
              ),
            ),
        ],
      ),
      drawer: isMultiSelectMode ? null : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.yellow[100],
              ),
              child: const Text(
                'Meal Assistant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Profile()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Meal member'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MealMember()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Transaction'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Transaction()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Meal planning'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddMealPlanning()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shop),
              title: const Text('Shopping'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddShopping()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Meal History'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => History()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/user home.jpeg"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, 0,
              0, 1, 0, 0, 0,
              0, 0, 1, 0, 0,
              0, 0, 0, 0.5, 0,
            ]),
          ),
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
                    bool isToday = day == today.day;
                    bool isSelected = selectedDays.contains(day);
                    bool isSingleSelected = selectedDay == day && !isMultiSelectMode;

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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isMultiSelectMode && isSelected
                                    ? Colors.green.withOpacity(0.8)
                                    : isToday
                                    ? Colors.blue.withOpacity(0.8)
                                    : Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8.0),
                                border: isSingleSelected
                                    ? Border.all(color: Colors.greenAccent, width: 2)
                                    : isToday
                                    ? Border.all(color: Colors.blueAccent, width: 2)
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
                                          color: (isMultiSelectMode && isSelected) || isToday
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          calendarData[day]!
                                              .split('|')
                                              .asMap()
                                              .entries
                                              .map((e) {
                                            List parts = e.value.split(',');
                                            return "${['B', 'L', 'D'][e.key]}:${parts[0]}${parts[1] != '0' ? '(${parts[1]})' : ''}";
                                          }).join('\n'),
                                          style: TextStyle(
                                            color: (isMultiSelectMode && isSelected) || isToday
                                                ? Colors.white
                                                : Colors.grey[800],
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
                            if (isMultiSelectMode)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? Colors.white : Colors.white70,
                                  size: 16,
                                ),
                              ),
                          ],
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
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
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
                      _buildStatCard("Total Deposit", "₹${totalDeposit.toStringAsFixed(2)}", Colors.green),
                      _buildStatCard("Available Balance", "₹${availableBalance.toStringAsFixed(2)}", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate", "₹${mealRate.toStringAsFixed(2)}", Colors.orange),
                      _buildStatCard("Total Meals", totalMeals.toString(), Colors.purple),
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
        color: color.withOpacity(0.2),
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
                  color: Colors.grey[700],
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
