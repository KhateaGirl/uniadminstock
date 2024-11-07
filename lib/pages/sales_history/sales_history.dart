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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
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
                          pw.Text(_formatDate(saleItem['timestamp'] as Timestamp?)),
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

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    List<Map<String, dynamic>> allSalesItems = [];

    // Fetch from admin_transactions collection
    QuerySnapshot adminTransactionsSnapshot = await _firestore
        .collection('admin_transactions')
        .orderBy('timestamp', descending: true)
        .get();
    adminTransactionsSnapshot.docs.forEach((transactionDoc) {
      var transactionData = transactionDoc.data() as Map<String, dynamic>;

      if (transactionData.containsKey('label') && transactionData.containsKey('quantity')) {
        allSalesItems.add({
          'itemLabel': transactionData['label'] ?? 'N/A',
          'itemSize': transactionData['itemSize'] ?? 'N/A',
          'quantity': transactionData['quantity'] ?? 0,
          'category': transactionData['category'] ?? 'N/A',
          'userName': transactionData['userName'] ?? 'N/A',
          'studentNumber': transactionData['studentNumber'] ?? 'N/A',
          'timestamp': transactionData['timestamp'],
        });
      }

      if (transactionData['cartItems'] is List) {
        List<dynamic> cartItems = transactionData['cartItems'];
        for (var item in cartItems) {
          allSalesItems.add({
            'itemLabel': item['itemLabel'] ?? 'N/A',
            'itemSize': item['itemSize'] ?? 'N/A',
            'quantity': item['quantity'] ?? 0,
            'category': item['category'] ?? 'N/A',
            'userName': transactionData['userName'] ?? 'N/A',
            'studentNumber': transactionData['studentNumber'] ?? 'N/A',
            'timestamp': transactionData['timestamp'],
          });
        }
      }
    });

    // Fetch from approved_preorders collection
    QuerySnapshot approvedPreordersSnapshot = await _firestore.collection('approved_preorders').get();
    print("Fetched ${approvedPreordersSnapshot.docs.length} documents from approved_preorders");

    approvedPreordersSnapshot.docs.forEach((preorderDoc) {
      var preorderData = preorderDoc.data() as Map<String, dynamic>;

      if (preorderData['items'] is List) {
        List<dynamic> items = preorderData['items'];
        for (var item in items) {
          print("Processing item in approved_preorders: ${item['label']}");
          allSalesItems.add({
            'itemLabel': item['label'] ?? 'N/A',
            'itemSize': item['itemSize'] ?? 'N/A',
            'quantity': item['quantity'] ?? 0,
            'category': item['category'] ?? 'N/A',
            'userName': preorderData['userName'] ?? 'N/A',
            'studentNumber': preorderData['studentNumber'] ?? 'N/A',
            'timestamp': preorderData['preOrderDate'] ?? Timestamp.now(),
          });
        }
      }
    });

    // Sort by timestamp in descending order
    allSalesItems.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
    print("Total sales items fetched: ${allSalesItems.length}");
    return allSalesItems;
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
                // Trigger a rebuild to refresh the data
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              final allSalesItems = await _fetchSalesData();
              if (allSalesItems.isNotEmpty) {
                await _generatePDF(allSalesItems);
              } else {
                print("No sales data to display in PDF");
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSalesData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: CustomText(text: "Error fetching sales history"));
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return Center(child: CustomText(text: "No sales history found"));
          } else if (snapshot.hasData) {
            final allSalesItems = snapshot.data!;

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
                              DataCell(Text(_formatDate(saleItem['timestamp'] as Timestamp?))),
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
            return Center(child: CustomText(text: "No data available"));
          }
        },
      ),
    );
  }
}
