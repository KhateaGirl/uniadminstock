import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      Map<String, Map<String, Map<String, int>>> soldData = {};

      for (var doc in snapshot.docs) {
        List<dynamic> items = doc['items'];
        for (var item in items) {
          String mainCategory = item['mainCategory'];
          String label = item['label'];
          String size = item['itemSize'];
          int quantity = item['quantity'];

          if (!soldData.containsKey(mainCategory)) {
            soldData[mainCategory] = {};
          }
          if (!soldData[mainCategory]!.containsKey(label)) {
            soldData[mainCategory]![label] = {};
          }

          soldData[mainCategory]![label]![size] =
              (soldData[mainCategory]![label]![size] ?? 0) + quantity;
        }
      }

      setState(() {
        _soldData = soldData;
      });
    } catch (e) {
      print("Error fetching sold data: $e");
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
                final soldItems = _soldData[category]?[label] ?? {};

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
          final soldItems = _soldData[category]?[label] ?? {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Summary'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
