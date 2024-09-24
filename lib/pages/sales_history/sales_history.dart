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
            .collection('approved_items')
            .orderBy('approvalDate', descending: true)
            .snapshots(), // Listen to real-time updates
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
            final salesHistory = snapshot.data!.docs;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Item Label')),
                  DataColumn(label: Text('Item Size')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Price/Item (₱)')),
                  DataColumn(label: Text('Total Price (₱)')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Buyer Name')),
                  DataColumn(label: Text('Reservation Date')),
                  DataColumn(label: Text('Approval Date')),
                ],
                rows: salesHistory.map((saleDoc) {
                  var sale = saleDoc.data() as Map<String, dynamic>;
                  int quantity = sale['quantity'] ?? 0;
                  double pricePerItem = sale['pricePerPiece'] ?? 0.0;
                  double totalPrice = quantity * pricePerItem;
                  String category = sale['category'] ?? 'N/A';

                  return DataRow(cells: [
                    DataCell(Text(sale['itemLabel'] ?? 'N/A')),
                    DataCell(Text(sale['itemSize'] ?? 'N/A')),
                    DataCell(Text(quantity.toString())),
                    DataCell(Text('₱${pricePerItem.toStringAsFixed(2)}')),
                    DataCell(Text('₱${totalPrice.toStringAsFixed(2)}')),
                    DataCell(Text(category)),
                    DataCell(Text(sale['name'] ?? 'N/A')),
                    DataCell(Text(_formatDate(sale['reservationDate'] as Timestamp))),
                    DataCell(Text(_formatDate(sale['approvalDate'] as Timestamp))),
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
