import 'package:flutter/material.dart';

class InventorySummaryPage extends StatelessWidget {
  final Map<String, Map<String, dynamic>> seniorHighStock;
  final Map<String, Map<String, dynamic>> collegeStock;
  final Map<String, Map<String, dynamic>> merchStock;

  InventorySummaryPage({
    required this.seniorHighStock,
    required this.collegeStock,
    required this.merchStock,
  });

  Widget _buildStockSummary(String category, Map<String, Map<String, dynamic>>? stockData) {
    if (stockData == null || stockData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$category Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'No items available',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          Divider(thickness: 1),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$category Summary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...stockData.keys.map((courseLabel) {
          final courseItems = stockData[courseLabel] ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseLabel,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ...courseItems.keys.map((itemKey) {
                Map<String, dynamic> itemData = courseItems[itemKey] ?? {};
                String label = itemData['label'] ?? itemKey;
                Map<String, dynamic> sizes = itemData['stock'] ?? {};

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...sizes.entries.map((entry) {
                        String size = entry.key;
                        int quantity = entry.value['quantity'] ?? 0;
                        double price = entry.value['price'] ?? 0.0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Size: $size'),
                            Text('Quantity: $quantity'),
                            Text('Price: ₱${price.toStringAsFixed(2)}'),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
              Divider(thickness: 1),
            ],
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockSummary('Senior High', seniorHighStock),
            _buildStockSummary('College', collegeStock),
            _buildStockSummary('Merch & Accessories', merchStock),
          ],
        ),
      ),
    );
  }
}
