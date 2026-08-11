import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mess_management/services/database_service.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';
import '../../core/app_colors.dart';

class ProductItem {
  final String productName;
  final int quantity;
  final double price;

  ProductItem(this.productName, this.quantity, this.price);

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'quantity': quantity,
    'price': price,
  };
}

class InputRow {
  final TextEditingController productController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
}

class AddShopping extends StatefulWidget {
  const AddShopping({super.key});

  @override
  State<AddShopping> createState() => _AddShoppingState();
}

class _AddShoppingState extends State<AddShopping> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;

  final List<InputRow> _inputRows = [InputRow()];

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
  void dispose() {
    for (var row in _inputRows) {
      row.productController.dispose();
      row.quantityController.dispose();
      row.priceController.dispose();
    }
    super.dispose();
  }

  void _saveItems() async {
    if (_user == null || _user!.messId == null) return;

    final List<ProductItem> newItems = [];
    for (final row in _inputRows) {
      final productName = row.productController.text;
      final quantity = int.tryParse(row.quantityController.text) ?? 0;
      final price = double.tryParse(row.priceController.text) ?? 0.0;

      if (productName.isNotEmpty && quantity > 0 && price > 0) {
        newItems.add(ProductItem(productName, quantity, price));
      }
    }

    if (newItems.isNotEmpty) {
      await _dbService.saveShoppingRecord(
        _user!.messId!,
        DateTime.now(),
        newItems.map((e) => e.toMap()).toList()
      );

      setState(() {
        _inputRows.clear();
        _inputRows.add(InputRow());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shopping record saved successfully')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one valid item')),
      );
    }
  }

  void _clearInputs() {
    setState(() {
      _inputRows.clear();
      _inputRows.add(InputRow());
    });
  }

  Widget _buildInputRow(InputRow row, int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: row.productController,
              decoration: const InputDecoration(
                labelText: 'Product',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.quantityController,
              decoration: const InputDecoration(
                labelText: 'Qty',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (value) {
                if (row.productController.text.isNotEmpty &&
                    row.quantityController.text.isNotEmpty &&
                    value.isNotEmpty) {
                  setState(() {
                    _inputRows.add(InputRow());
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Add Shopping Record')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _inputRows.length,
                    itemBuilder: (context, index) =>
                        _buildInputRow(_inputRows[index], index),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _saveItems,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save All'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearInputs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 2),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Recent History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dbService.getShoppingHistory(_user!.messId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final records = snapshot.data!;
                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final date = (record['date'] as Timestamp).toDate();
                    final items = (record['items'] as List);
                    double total = items.fold(0.0, (totalSum, item) => totalSum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()));

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ExpansionTile(
                        title: Text(DateFormat('yyyy-MM-dd').format(date)),
                        subtitle: Text('Total: ৳${total.toStringAsFixed(2)}'),
                        children: [
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Price')),
                            ],
                            rows: items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item['productName'])),
                                  DataCell(Text(item['quantity'].toString())),
                                  DataCell(Text('৳${(item['price'] * item['quantity']).toStringAsFixed(2)}')),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
