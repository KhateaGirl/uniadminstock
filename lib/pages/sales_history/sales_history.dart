import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';  // Import the intl package

class SalesHistoryPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all approved items from Firestore
  Future<List<Map<String, dynamic>>> _fetchSalesHistory() async {
    QuerySnapshot approvedItemsSnapshot = await _firestore.collection('approved_items').get();
    List<Map<String, dynamic>> salesHistory = [];

    for (var doc in approvedItemsSnapshot.docs) {
      salesHistory.add(doc.data() as Map<String, dynamic>);
    }

    return salesHistory;
  }

  // Function to format the date (removes milliseconds)
  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date); // Formats without milliseconds
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: CustomText(text: "Error fetching sales history"),
            );
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return Center(
              child: CustomText(text: "No sales history found"),
            );
          } else if (snapshot.hasData) {
            final salesHistory = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Item Label')),
                  DataColumn(label: Text('Item Size')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Buyer Name')),
                  DataColumn(label: Text('Reservation Date')),
                  DataColumn(label: Text('Approval Date')),
                ],
                rows: salesHistory.map((sale) {
                  return DataRow(cells: [
                    DataCell(Text(sale['itemLabel'] ?? 'N/A')),
                    DataCell(Text(sale['itemSize'] ?? 'N/A')),
                    DataCell(Text(sale['quantity'].toString() ?? '0')),
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
