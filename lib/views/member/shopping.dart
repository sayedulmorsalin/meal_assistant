import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meal_assistant/services/database_service.dart';
import 'package:meal_assistant/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_assistant/models/user_model.dart';
import '../../core/app_colors.dart';

class Shopping extends StatefulWidget {
  const Shopping({super.key});

  @override
  State<Shopping> createState() => _ShoppingState();
}

class _ShoppingState extends State<Shopping> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() => _user = UserModel.fromMap(doc.data()!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping History'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.getShoppingHistory(_user!.messId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final records = snapshot.data!;
          if (records.isEmpty) return const Center(child: Text('No shopping records available'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final date = (record['date'] as Timestamp).toDate();
              final items = (record['items'] as List);
              final total = items.fold(0.0, (totalSum, item) => totalSum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()));

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM dd, yyyy').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1.5),
                        },
                        border: TableBorder.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer), textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                          ...items.map((item) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(item['productName']),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(item['quantity'].toString(), textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('৳${(item['price'] * item['quantity']).toStringAsFixed(2)}', textAlign: TextAlign.right),
                              ),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('৳${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                        ],
                      ),
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
}
