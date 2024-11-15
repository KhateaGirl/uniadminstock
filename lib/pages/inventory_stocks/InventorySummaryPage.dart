import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class InventorySummaryPage extends StatefulWidget {
  @override
  _InventorySummaryPageState createState() => _InventorySummaryPageState();
}

class _InventorySummaryPageState extends State<InventorySummaryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _seniorHighStock = {};
  Map<String, Map<String, dynamic>> _collegeStock = {};
  Map<String, Map<String, dynamic>> _merchStock = {};
  Map<String, Map<String, Map<String, int>>> _soldData = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    try {
      setState(() {
        _loading = true;
      });

      await Future.wait([
        _fetchSeniorHighStock(),
        _fetchCollegeStock(),
        _fetchMerchStock(),
        _fetchSoldData(),  // Fetch sold data
      ]);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      print("Error fetching inventory data: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchSoldData() async {
    try {
      QuerySnapshot snapshot = await firestore.collection('approved_items').get();
      Map<String, Map<String, Map<String, int>>> newSoldData = {};

      for (var doc in snapshot.docs) {
        var docData = doc.data() as Map<String, dynamic>;
        if (docData['items'] is List) {
          List items = docData['items'];
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              String category = item['mainCategory'];
              String label = item['label'];
              String size = item['itemSize'];
              int quantity = item['quantity'];

              newSoldData[category] = newSoldData[category] ?? {};
              newSoldData[category]![label] = newSoldData[category]![label] ?? {};
              newSoldData[category]![label]![size] = (newSoldData[category]![label]![size] ?? 0) + quantity;

              // Print each item being processed
              print("Processed item - Category: $category, Label: $label, Size: $size, Quantity: $quantity");
            }
          }
        }
      }

      // Print final sold data structure
      print("Final Sold Data: $newSoldData");

      setState(() {
        _soldData = newSoldData;
      });
    } catch (e) {
      print('Error fetching sold data: $e');
    }
  }

  Future<void> _fetchSeniorHighStock() async {
    try {
      QuerySnapshot snapshot = await firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> data = {};
      for (var doc in snapshot.docs) {
        Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;

        Map<String, dynamic> stockData = {};
        if (docData.containsKey('sizes') && docData['sizes'] is Map) {
          Map<String, dynamic> sizes = docData['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map && sizeValue.containsKey('quantity')) {
              stockData[sizeKey] = {
                'quantity': sizeValue['quantity'],
                'price': sizeValue['price'] ?? 0.0,
              };
            }
          });
        }

        data[doc.id] = {
          'label': docData['label'] ?? doc.id,
          'stock': stockData,
        };
      }

      setState(() {
        _seniorHighStock = data;
      });
    } catch (e) {
      print("Error fetching senior high stock: $e");
    }
  }

  Future<void> _fetchCollegeStock() async {
    try {
      Map<String, Map<String, dynamic>> data = {};
      List<String> courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism', 'BSA & BSBA'];

      for (String courseLabel in courseLabels) {
        QuerySnapshot snapshot = await firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .get();

        Map<String, Map<String, dynamic>> courseData = {};
        for (var doc in snapshot.docs) {
          Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;

          Map<String, dynamic> stockData = {};
          if (docData.containsKey('sizes') && docData['sizes'] is Map) {
            Map<String, dynamic> sizes = docData['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'] ?? 0,
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          courseData[doc.id] = {
            'label': docData['label'] ?? doc.id,
            'stock': stockData,
          };
        }
        data[courseLabel] = courseData;
      }

      setState(() {
        _collegeStock = data;
      });
    } catch (e) {
      print("Error fetching college stock: $e");
    }
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot doc = await firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> data = {};

      docData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          Map<String, dynamic> stockData = {};
          if (value.containsKey('sizes') && value['sizes'] is Map) {
            Map<String, dynamic> sizes = value['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'],
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          data[key] = {
            'label': value['label'] ?? key,
            'stock': stockData,
          };
        }
      });

      setState(() {
        _merchStock = data;
      });
    } catch (e) {
      print("Error fetching merch stock: $e");
    }
  }

  Widget _buildStockSummary(String category, Map<String, Map<String, dynamic>>? stockData) {
    // Map the UI category to Firestore category names
    String soldDataCategory = category == 'College' ? 'college_items'
        : category == 'Senior High' ? 'senior_high_items'
        : category == 'Merch & Accessories' ? 'merch_and_accessories'
        : '';

    // Fetch the relevant sold data
    final categorySoldData = _soldData[soldDataCategory];

    print("Building summary for $category with sold data: $categorySoldData");

    if (stockData == null || stockData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$category Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text('No items available', style: TextStyle(fontStyle: FontStyle.italic)),
          Divider(thickness: 1),
        ],
      );
    }

    // College category with dropdown
    if (category == 'College') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'College Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          ...stockData.keys.map((courseLabel) {
            final courseItems = stockData[courseLabel];
            return ExpansionTile(
              title: Text(courseLabel, style: TextStyle(fontWeight: FontWeight.bold)),
              children: courseItems?.keys.map((itemKey) {
                final item = courseItems[itemKey];
                final label = item?['label'] ?? itemKey;
                final stock = item?['stock'] as Map<String, dynamic>? ?? {};
                final soldItems = categorySoldData?[label] ?? {};

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                      ...stock.keys.map((sizeKey) {
                        final size = stock[sizeKey];
                        final soldQuantity = soldItems[sizeKey] ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Size: $sizeKey'),
                            Text('Quantity: ${size['quantity']}'),
                            Text('Sold: $soldQuantity'),
                            Text('Price: ₱${size['price'].toStringAsFixed(2)}'),
                          ],
                        );
                      }).toList(),
                      Divider(thickness: 1),
                    ],
                  ),
                );
              }).toList() ?? [],
            );
          }).toList(),
        ],
      );
    }

    // Other categories without dropdown
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$category Summary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        ...stockData.keys.map((itemKey) {
          final item = stockData[itemKey];
          final label = item?['label'] ?? itemKey;
          final stock = item?['stock'] as Map<String, dynamic>? ?? {};
          final soldItems = categorySoldData?[label] ?? {};

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                ...stock.keys.map((sizeKey) {
                  final size = stock[sizeKey];
                  final soldQuantity = soldItems[sizeKey] ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Size: $sizeKey'),
                      Text('Quantity: ${size['quantity']}'),
                      Text('Sold: $soldQuantity'),
                      Text('Price: ₱${size['price'].toStringAsFixed(2)}'),
                    ],
                  );
                }).toList(),
                Divider(thickness: 1),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _printSummary() async {
    final pdf = pw.Document();
    final maxHeight = PdfPageFormat.a4.availableHeight;

    // List to hold each category's summary
    List<Map<String, dynamic>> categorySummaries = [
      {"title": "Senior High Summary", "data": _seniorHighStock, "soldCategory": "senior_high_items"},
      {"title": "College Summary", "data": _collegeStock, "soldCategory": "college_items"},
      {"title": "Merch & Accessories Summary", "data": _merchStock, "soldCategory": "merch_and_accessories"},
    ];

    for (var category in categorySummaries) {
      String categoryTitle = category["title"];
      Map<String, Map<String, dynamic>>? stockData = category["data"];
      String soldCategory = category["soldCategory"];

      if (stockData == null || stockData.isEmpty) {
        continue; // Skip empty or null categories
      }

      List<pw.Widget> categoryWidgets = [];

      // Add category title
      categoryWidgets.add(
        pw.Text(categoryTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      );

      if (categoryTitle == "College Summary") {
        stockData.forEach((courseLabel, courseItems) {
          categoryWidgets.add(pw.Text(courseLabel, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));

          (courseItems as Map<String, dynamic>).forEach((itemKey, item) {
            String label = item['label'] ?? itemKey;
            final stock = item['stock'] as Map<String, dynamic>? ?? {};
            final soldItems = _soldData[soldCategory]?[label] ?? {};

            categoryWidgets.add(pw.Text(label, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));

            stock.forEach((sizeKey, sizeDetails) {
              final soldQuantity = soldItems[sizeKey] ?? 0;
              categoryWidgets.add(
                pw.Text(
                  'Size: $sizeKey, Quantity: ${sizeDetails['quantity'] ?? 0}, Sold: $soldQuantity, Price: ₱${sizeDetails['price'] ?? 0.0}',
                  style: pw.TextStyle(fontSize: 12),
                ),
              );
            });
          });
        });
      } else {
        stockData.forEach((itemKey, item) {
          String label = item['label'] ?? itemKey;
          final stock = item['stock'] as Map<String, dynamic>? ?? {};
          final soldItems = _soldData[soldCategory]?[label] ?? {};

          categoryWidgets.add(pw.Text(label, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));

          stock.forEach((sizeKey, sizeDetails) {
            final soldQuantity = soldItems[sizeKey] ?? 0;
            categoryWidgets.add(
              pw.Text(
                'Size: $sizeKey, Quantity: ${sizeDetails['quantity'] ?? 0}, Sold: $soldQuantity, Price: ₱${sizeDetails['price'] ?? 0.0}',
                style: pw.TextStyle(fontSize: 12),
              ),
            );
          });
        });
      }

      // Divide categoryWidgets into pages based on maxHeight
      List<pw.Widget> pageWidgets = [];
      double currentHeight = 0;
      const lineHeight = 15.0;

      for (var widget in categoryWidgets) {
        // Check if adding the next widget would exceed the maxHeight
        if (currentHeight + lineHeight > maxHeight) {
          // Add the accumulated widgets as a new page
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: pageWidgets,
                );
              },
            ),
          );
          // Reset for the next page
          pageWidgets = [];
          currentHeight = 0;
        }

        pageWidgets.add(widget);
        currentHeight += lineHeight;
      }

      // Add any remaining widgets as the last page for this category
      if (pageWidgets.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pageWidgets,
              );
            },
          ),
        );
      }
    }

    // Print or preview the generated PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Inventory...'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Summary'),
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _printSummary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockSummary('Senior High', _seniorHighStock),
            _buildStockSummary('College', _collegeStock),
            _buildStockSummary('Merch & Accessories', _merchStock),
          ],
        ),
      ),
    );
  }
}