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

  Future<List<Map<String, dynamic>>>? _salesDataFuture;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _salesDataFuture = _fetchSalesData();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    List<Map<String, dynamic>> allSalesItems = [];
    double totalRevenue = 0.0;

    try {
      print("Fetching admin transactions...");
      QuerySnapshot adminTransactionsSnapshot = await _firestore
          .collection('admin_transactions')
          .orderBy('timestamp', descending: true)
          .get();

      for (var transactionDoc in adminTransactionsSnapshot.docs) {
        var transactionData = transactionDoc.data() as Map<String, dynamic>;

        totalRevenue += (transactionData['totalTransactionPrice'] ?? 0.0) as double;

        if (transactionData['items'] is List) {
          List<dynamic> items = transactionData['items'];
          for (var item in items) {
            allSalesItems.add({
              'orNumber': transactionData['orNumber'] ?? 'N/A',
              'userName': transactionData['userName'] ?? 'N/A',
              'studentNumber': transactionData['studentNumber'] ?? 'N/A',
              'itemLabel': item['label'] ?? 'N/A',
              'itemSize': item['itemSize'] ?? 'N/A',
              'quantity': item['quantity'] ?? 0,
              'category': item['mainCategory'] ?? 'N/A',
              'totalPrice': item['totalPrice'] ?? 0.0,
            });
          }
        }
      }

      _totalRevenue = totalRevenue;
      print("Sales data fetch completed. Total items: ${allSalesItems.length}");
      return allSalesItems;

    } catch (e) {
      print("Error fetching sales data: $e");
      return [];
    }
  }

  Future<void> _generatePDF(List<Map<String, dynamic>> salesData) async {
    final pdf = pw.Document();
    const int rowsPerPage = 10; // 10 data rows + 1 header row

    int pageCount = (salesData.length / rowsPerPage).ceil();
    for (int page = 0; page < pageCount; page++) {
      final rowsChunk = salesData.skip(page * rowsPerPage).take(rowsPerPage).toList();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Sales Report (Page ${page + 1} of $pageCount)'),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Text('OR Number', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Student Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Student ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Item Label', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Item Size', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Total Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    // Data rows
                    ...rowsChunk.map((saleItem) {
                      return pw.TableRow(
                        children: [
                          pw.Text(saleItem['orNumber'] ?? 'N/A'),
                          pw.Text(saleItem['userName'] ?? 'N/A'),
                          pw.Text(saleItem['studentNumber'] ?? 'N/A'),
                          pw.Text(saleItem['itemLabel'] ?? 'N/A'),
                          pw.Text(saleItem['itemSize'] ?? 'N/A'),
                          pw.Text(saleItem['quantity'].toString()),
                          pw.Text(saleItem['category'] ?? 'N/A'),
                          pw.Text('₱${(saleItem['totalPrice'] ?? 0.0).toStringAsFixed(2)}'),
                        ],
                      );
                    }),
                  ],
                ),
                if (page == pageCount - 1) // Add total revenue on the last page
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 16),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "Sales Report"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _salesDataFuture = _fetchSalesData();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              final allSalesItems = await _salesDataFuture;
              if (allSalesItems != null && allSalesItems.isNotEmpty) {
                await _generatePDF(allSalesItems);
              } else {
                print("No sales data to display in PDF");
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _salesDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print("Error in FutureBuilder: ${snapshot.error}");
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
                            DataColumn(label: Text('OR Number')),
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Student ID')),
                            DataColumn(label: Text('Item Label')),
                            DataColumn(label: Text('Item Size')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Total Price')),
                          ],
                          rows: allSalesItems.map((saleItem) {
                            return DataRow(cells: [
                              DataCell(Text(saleItem['orNumber'] ?? 'N/A')),
                              DataCell(Text(saleItem['userName'] ?? 'N/A')),
                              DataCell(Text(saleItem['studentNumber'] ?? 'N/A')),
                              DataCell(Text(saleItem['itemLabel'] ?? 'N/A')),
                              DataCell(Text(saleItem['itemSize'] ?? 'N/A')),
                              DataCell(Text(saleItem['quantity'].toString())),
                              DataCell(Text(saleItem['category'] ?? 'N/A')),
                              DataCell(Text('₱${(saleItem['totalPrice'] ?? 0.0).toStringAsFixed(2)}')),
                            ]);
                          }).toList(),
                        )
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
