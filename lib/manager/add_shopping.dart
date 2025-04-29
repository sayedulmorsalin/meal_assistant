import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductItem {
  final String productName;
  final int quantity;
  final double price;

  ProductItem(this.productName, this.quantity, this.price);
}

class ShoppingTable {
  final DateTime date;
  final List<ProductItem> items;

  ShoppingTable(this.date, this.items);
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
  final List<ShoppingTable> _tables = [];
  final List<InputRow> _inputRows = [InputRow()];

  @override
  void dispose() {
    for (var row in _inputRows) {
      row.productController.dispose();
      row.quantityController.dispose();
      row.priceController.dispose();
    }
    super.dispose();
  }

  void _saveItems() {
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
      final now = DateTime.now();
      final currentDate = DateTime(now.year, now.month, now.day);

      setState(() {
        final existingTableIndex = _tables.indexWhere(
              (table) => table.date.isAtSameMomentAs(currentDate),
        );

        if (existingTableIndex != -1) {
          _tables[existingTableIndex].items.addAll(newItems);
        } else {
          _tables.add(ShoppingTable(currentDate, newItems));
        }

        _inputRows.clear();
        _inputRows.add(InputRow());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one valid item'),
        ),
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
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Records')),
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
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Save All',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _clearInputs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 2),
          Expanded(
            child: _tables.isEmpty
                ? const Center(child: Text('No saved records'))
                : ListView.builder(
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final table = _tables[index];
                final total = table.items.fold(
                  0.0,
                      (sum, item) => sum + item.price,
                );

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(table.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Price')),
                            ],
                            rows: table.items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item.productName)),
                                  DataCell(Text(item.quantity.toString())),
                                  DataCell(Text('৳${item.price.toStringAsFixed(2)}')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Total: ৳${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}