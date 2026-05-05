import 'package:flutter/material.dart';
import 'package:mess_management/manager/manager_home.dart';
import 'package:mess_management/user/history.dart';
import 'package:mess_management/user/meal_planning.dart';
import 'package:mess_management/user/profile.dart';
import 'package:mess_management/user/shopping.dart';
import 'package:mess_management/user/transaction.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State createState() => _UserHomeState();
}

class _UserHomeState extends State {
  final Map calendarData = {};
  final DateTime today = DateTime.now();
  List selectedDays = [];
  bool isMultiSelectMode = false;
  int? selectedDay;

  double totalDeposit = 5000.0;
  double mealRate = 50.0;

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

  void _showDateDetails(BuildContext context, [int? day]) {
    if (day == null && selectedDays.isEmpty) return;

    List initialValues = day != null
        ? calendarData[day]!.split('|')
        : calendarData[selectedDays.first]!.split('|');
    List meals = initialValues.map((m) => m.split(',')).toList();
    List mealValues = meals.map((m) => m[0] == '1').toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: day != null
                  ? Text("Edit Day $day")
                  : Text("Edit ${selectedDays.length} Days"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMealSwitch("Breakfast", mealValues[0], (value) {
                    setState(() => mealValues[0] = value);
                  }),
                  _buildMealSwitch("Lunch", mealValues[1], (value) {
                    setState(() => mealValues[1] = value);
                  }),
                  _buildMealSwitch("Dinner", mealValues[2], (value) {
                    setState(() => mealValues[2] = value);
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showGuestMealDialog(context, day: day);
                        },
                        child: const Text("Add Guest Meal"),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final values = mealValues.asMap().entries.map((entry) {
                              int index = entry.key;
                              bool value = entry.value;
                              return "${value ? '1' : '0'},${meals[index][1]}";
                            }).join("|");

                            if (day != null) {
                              calendarData[day] = values;
                            } else {
                              for (var d in selectedDays) {
                                calendarData[d] = values;
                              }
                            }
                            Navigator.of(context).pop();
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        if (day == null) {
          selectedDays.clear();
          isMultiSelectMode = false;
        }
      });
    });
  }

  void _showGuestMealDialog(BuildContext context, {int? day}) {
    bool isMultiSelect = selectedDays.isNotEmpty;
    if (isMultiSelect && selectedDays.isEmpty) return;

    List initialBreakfast = [];
    List initialLunch = [];
    List initialDinner = [];

    if (isMultiSelect) {
      for (var d in selectedDays) {
        var meals = calendarData[d]!.split('|');
        for (int i = 0; i < 3; i++) {
          var parts = meals[i].split(',');
          initialBreakfast.add(int.parse(parts[1]));
          initialLunch.add(int.parse(parts[1]));
          initialDinner.add(int.parse(parts[1]));
        }
      }
    } else {
      var meals = calendarData[day!]!.split('|');
      for (int i = 0; i < 3; i++) {
        var parts = meals[i].split(',');
        initialBreakfast.add(int.parse(parts[1]));
        initialLunch.add(int.parse(parts[1]));
        initialDinner.add(int.parse(parts[1]));
      }
    }

    int breakfastValue = isMultiSelect ? initialBreakfast.first : initialBreakfast[0];
    int lunchValue = isMultiSelect ? initialLunch.first : initialLunch[0];
    int dinnerValue = isMultiSelect ? initialDinner.first : initialDinner[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: isMultiSelect
                  ? Text("Add Guest Meals to ${selectedDays.length} Days")
                  : Text("Add Guest Meal to Day $day"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGuestMealDropdown("Breakfast", breakfastValue,
                          (v) => setState(() => breakfastValue = v)),
                  _buildGuestMealDropdown("Lunch", lunchValue,
                          (v) => setState(() => lunchValue = v)),
                  _buildGuestMealDropdown("Dinner", dinnerValue,
                          (v) => setState(() => dinnerValue = v)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: Navigator.of(context).pop,
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          String getUpdatedMeal(String original, int guest) {
                            List parts = original.split(',');
                            return "${parts[0]},$guest";
                          }

                          if (isMultiSelect) {
                            for (var d in selectedDays) {
                              var originalMeals = calendarData[d]!.split('|');
                              List newMeals = [];
                              for (int i = 0; i < 3; i++) {
                                int guest = [breakfastValue, lunchValue, dinnerValue][i];
                                newMeals.add(getUpdatedMeal(originalMeals[i], guest));
                              }
                              calendarData[d] = newMeals.join('|');
                            }
                          } else {
                            var originalMeals = calendarData[day!]!.split('|');
                            List newMeals = [];
                            for (int i = 0; i < 3; i++) {
                              int guest = [breakfastValue, lunchValue, dinnerValue][i];
                              newMeals.add(getUpdatedMeal(originalMeals[i], guest));
                            }
                            calendarData[day!] = newMeals.join('|');
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => setState(() {}));
  }

  Widget _buildMealSwitch(
      String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Switch(
            value: value,
            activeColor: Colors.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMealDropdown(
      String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          DropdownButton(
            value: value,
            items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text("$i"))),
            onChanged: (v) => onChanged(v!),
          ),
        ],
      ),
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
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: selectedDays.isNotEmpty
                  ? () => _showDateDetails(context)
                  : null,
            )
          else
            IconButton(
              icon: const Icon(Icons.message, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManagerHome()),
                );
              },
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
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Profile()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Transaction'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Transaction()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Meal planning'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MealPlanning()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shop),
              title: const Text('Shopping'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Shopping()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Meal History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => History()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
              },
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
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
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
                    bool isSingleSelected =
                        selectedDay == day && !isMultiSelectMode;

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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMultiSelectMode && isSelected
                                ? Colors.green.withOpacity(0.8)
                                : isToday
                                ? Colors.blue.withOpacity(0.8)
                                : Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8.0),
                            border: isSingleSelected
                                ? Border.all(
                                color: Colors.greenAccent, width: 2)
                                : isToday
                                ? Border.all(
                                color: Colors.blueAccent, width: 2)
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$day",
                                      style: TextStyle(
                                        color: (isMultiSelectMode && isSelected) ||
                                            isToday
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isMultiSelectMode)
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                                        color: isSelected ? Colors.white : Colors.white70,
                                        size: 14,
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  calendarData[day]!
                                      .split('|')
                                      .asMap()
                                      .entries
                                      .map((e) {
                                    List parts = e.value.split(',');
                                    return "${['B', 'L', 'D'][e.key]}:${parts[0]}${parts[1] != '0' ? '(${parts[1]})' : ''}";
                                  }).join('\n'),
                                  style: TextStyle(
                                    color: (isMultiSelectMode &&
                                        isSelected) ||
                                        isToday
                                        ? Colors.white
                                        : Colors.grey[800],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                                const Spacer(),
                              ],
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
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
                      _buildStatCard("Total Deposit",
                          "₹${totalDeposit.toStringAsFixed(2)}", Colors.green),
                      _buildStatCard("Available Balance",
                          "₹${availableBalance.toStringAsFixed(2)}", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard("Meal Rate",
                          "₹${mealRate.toStringAsFixed(2)}", Colors.orange),
                      _buildStatCard(
                          "Total Meals", totalMeals.toString(), Colors.purple),
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
