import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class SalesHistoryPage extends StatefulWidget {
  @override
  _SalesHistoryPageState createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // Function to format the date (removes milliseconds)
  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Sales History",
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Trigger a rebuild to refresh the stream
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('admin_transactions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
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

            List<Map<String, dynamic>> allSalesItems = [];

            transactions.forEach((transactionDoc) {
              var transactionData = transactionDoc.data() as Map<String, dynamic>;

              // Process top-level sales data (if exists)
              if (transactionData.containsKey('label') &&
                  transactionData.containsKey('quantity')) {
                Map<String, dynamic> topSaleItem = {
                  'itemLabel': transactionData['label'] ?? 'N/A',
                  'itemSize': transactionData['itemSize'] ?? 'N/A',
                  'quantity': transactionData['quantity'] ?? 0,
                  'category': transactionData['category'] ?? 'N/A',
                  'userName': transactionData['userName'] ?? 'N/A',
                  'studentNumber': transactionData['studentNumber'] ?? 'N/A',
                  'timestamp': transactionData['timestamp'],
                };
                allSalesItems.add(topSaleItem);
              }

              // Check and process nested cartItems if present
              if (transactionData['cartItems'] is List) {
                List<dynamic> cartItems = transactionData['cartItems'];

                for (var item in cartItems) {
                  Map<String, dynamic> saleItem = {
                    'itemLabel': item['itemLabel'] ?? 'N/A',
                    'itemSize': item['itemSize'] ?? 'N/A',
                    'quantity': item['quantity'] ?? 0,
                    'category': item['category'] ?? 'N/A',
                    'userName': transactionData['userName'] ?? 'N/A',
                    'studentNumber': transactionData['studentNumber'] ?? 'N/A',
                    'timestamp': transactionData['timestamp'],
                  };

                  allSalesItems.add(saleItem);
                }
              }
            });

            return Column(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
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
                            return DataRow(cells: [
                              DataCell(Text(saleItem['itemLabel'] ?? 'N/A')),
                              DataCell(Text(saleItem['itemSize'] ?? 'N/A')),
                              DataCell(Text(saleItem['quantity'].toString())),
                              DataCell(Text(saleItem['category'] ?? 'N/A')),
                              DataCell(Text(saleItem['userName'] ?? 'N/A')),
                              DataCell(Text(saleItem['studentNumber'] ?? 'N/A')),
                              DataCell(Text(_formatDate(saleItem['timestamp'] as Timestamp))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: 2000,
                        height: 20,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
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