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

class Shopping extends StatefulWidget {
  const Shopping({super.key});

  @override
  State<Shopping> createState() => _ShoppingState();
}

class _ShoppingState extends State<Shopping> {
  final List<ShoppingTable> _shoppingData = [];

  @override
  void initState() {
    super.initState();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    // Sample data - will be replaced with database data
    _shoppingData.addAll([
      ShoppingTable(
        DateTime(2023, 8, 1),
        [
          ProductItem('Rice (1kg)', 2, 120.0),
          ProductItem('Chicken (1kg)', 1, 350.0),
          ProductItem('Vegetables', 3, 150.0),
        ],
      ),
      ShoppingTable(
        DateTime(2023, 8, 8),
        [
          ProductItem('Milk (1L)', 4, 70.0),
          ProductItem('Eggs (dozen)', 2, 130.0),
          ProductItem('Bread', 2, 40.0),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping History'),
        centerTitle: true,
      ),
      body: _shoppingData.isEmpty
          ? const Center(child: Text('No shopping records available'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shoppingData.length,
        itemBuilder: (context, index) {
          final table = _shoppingData[index];
          final total = table.items.fold(
              0.0, (sum, item) => sum + (item.price * item.quantity));

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM dd, yyyy').format(table.date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Qty',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      ...table.items.map((item) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(item.productName),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              item.quantity.toString(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '৳${(item.price * item.quantity).toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '৳${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
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
    );
  }
}