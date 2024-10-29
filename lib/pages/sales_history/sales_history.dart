import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unistock/widgets/custom_text.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesHistoryPage extends StatefulWidget {
  @override
  _SalesHistoryPageState createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  Future<void> _generatePDF(List<Map<String, dynamic>> salesData) async {
    final pdf = pw.Document();
    const int rowsPerPage = 20;

    int pageCount = (salesData.length / rowsPerPage).ceil();
    for (int page = 0; page < pageCount; page++) {
      final rowsChunk = salesData.skip(page * rowsPerPage).take(rowsPerPage).toList();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Sales History (Page ${page + 1} of $pageCount)'),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Text('Item Label'),
                        pw.Text('Item Size'),
                        pw.Text('Quantity'),
                        pw.Text('Category'),
                        pw.Text('Student Name'),
                        pw.Text('Student Number'),
                        pw.Text('Order Timestamp'),
                      ],
                    ),
                    // Data rows
                    ...rowsChunk.map((saleItem) {
                      return pw.TableRow(
                        children: [
                          pw.Text(saleItem['itemLabel'] ?? 'N/A'),
                          pw.Text(saleItem['itemSize'] ?? 'N/A'),
                          pw.Text(saleItem['quantity'].toString()),
                          pw.Text(saleItem['category'] ?? 'N/A'),
                          pw.Text(saleItem['userName'] ?? 'N/A'),
                          pw.Text(saleItem['studentNumber'] ?? 'N/A'),
                          pw.Text(_formatDate(saleItem['timestamp'] as Timestamp)),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              // Fetch the sales data and pass it to the PDF generation function
              QuerySnapshot snapshot = await _firestore
                  .collection('admin_transactions')
                  .orderBy('timestamp', descending: true)
                  .get();
              final transactions = snapshot.docs;

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

              // Debugging: Print the fetched data
              print("Fetched ${allSalesItems.length} items from Firestore.");
              allSalesItems.forEach((item) => print(item));

              // Ensure that data is being passed to _generatePDF
              if (allSalesItems.isNotEmpty) {
                await _generatePDF(allSalesItems);
              } else {
                print("No sales data to display in PDF");
              }
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
                            DataColumn(label: Text('Student Name')),
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
