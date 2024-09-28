import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class SalesHistoryPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to format the date (removes milliseconds)
  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Sales History",
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('admin_transactions')
            .orderBy('timestamp', descending: true)
            .snapshots(), // Listen to real-time updates from admin_transactions
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: CustomText(text: "Error fetching sales history"),
            );
          } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
            return Center(
              child: CustomText(text: "No sales history found"),
            );
          } else if (snapshot.hasData) {
            final transactions = snapshot.data!.docs;

            // List to hold all sales items from transactions
            List<Map<String, dynamic>> allSalesItems = [];

            // Extracting each transaction's cart items
            transactions.forEach((transactionDoc) {
              var transactionData = transactionDoc.data() as Map<String, dynamic>;
              List<dynamic> cartItems = transactionData['cartItems'] ?? [];

              // Add additional transaction details to each cart item, and ensure type conversion
              cartItems.forEach((item) {
                Map<String, dynamic> saleItem = item as Map<String, dynamic>;
                saleItem['userName'] = transactionData['userName'] ?? 'N/A';
                saleItem['studentNumber'] = transactionData['studentNumber'] ?? 'N/A';
                saleItem['timestamp'] = transactionData['timestamp'];
                allSalesItems.add(saleItem);
              });
            });

            // Build the sales history table
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Item Label')),
                  DataColumn(label: Text('Item Size')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Buyer Name')),
                  DataColumn(label: Text('Student Number')),
                  DataColumn(label: Text('Order Timestamp')),
                ],
                rows: allSalesItems.map((saleItem) {
                  int quantity = saleItem['quantity'] ?? 0;
                  String category = saleItem['category'] ?? 'N/A';

                  return DataRow(cells: [
                    DataCell(Text(saleItem['itemLabel'] ?? 'N/A')),
                    DataCell(Text(saleItem['itemSize'] ?? 'N/A')),
                    DataCell(Text(quantity.toString())),
                    DataCell(Text(category)),
                    DataCell(Text(saleItem['userName'] ?? 'N/A')),
                    DataCell(Text(saleItem['studentNumber'] ?? 'N/A')),
                    DataCell(Text(_formatDate(saleItem['timestamp'] as Timestamp))),
                  ]);
                }).toList(),
              ),
            );
          } else {
            return Center(
              child: CustomText(text: "No data available"),
            );
          }
        },
      ),
    );
  }
}
