import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
  Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
  Map<String, Map<String, dynamic>> _merchStockQuantities = {};

  bool _loading = true;
  String? _selectedCourseLabel;
  String? _selectedSize;
  final List<String> _courseLabels = [
    'BACOMM',
    'HRM & Culinary',
    'IT&CPE',
    'Tourism'
  ];
  final List<String> _availableSizes = [
    'Small',
    'Medium',
    'Large',
    'XL',
    '2XL',
    '3XL',
    '4XL',
    '5XL',
    '6XL',
    '7XL'
  ];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

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

      await Future.wait(<Future>[
        _fetchSeniorHighStock(),
        _fetchCollegeStock(),
        _fetchMerchStock(),
      ]);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchSeniorHighStock() async {
    try {
      QuerySnapshot seniorHighSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('senior_high_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> seniorHighData = {};
      seniorHighSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> stockData = {};
        String? imagePath = data['imagePath'] as String?;
        String label = data['label'] != null ? data['label'] as String : doc.id;

        if (data.containsKey('sizes') && data['sizes'] is Map) {
          Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map && sizeValue.containsKey('quantity')) {
              stockData[sizeKey] = {
                'quantity': sizeValue['quantity'],
                'price': sizeValue['price'] ?? 0.0,
              };
            }
          });
        }

        seniorHighData[doc.id] = {
          'stock': stockData,
          'imagePath': imagePath ?? '',
          'label': label,
          'price': data['price'] ?? 0.0,
        };
      });

      setState(() {
        _seniorHighStockQuantities = seniorHighData;
      });
    } catch (e) {}
  }

  Future<void> _fetchCollegeStock() async {
    try {
      Map<String, Map<String, dynamic>> collegeData = {};
      for (String courseLabel in _courseLabels) {
        QuerySnapshot courseSnapshot = await firestore
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .get();

        Map<String, Map<String, dynamic>> courseItems = {};
        courseSnapshot.docs.forEach((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String? imagePath = data['imagePath'] as String?;
          String label = data['label'] != null ? data['label'] as String : doc
              .id;

          Map<String, dynamic> stockData = {};
          if (data.containsKey('sizes') && data['sizes'] is Map) {
            Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                stockData[sizeKey] = {
                  'quantity': sizeValue['quantity'],
                  'price': sizeValue['price'] ?? 0.0,
                };
              }
            });
          }

          courseItems[doc.id] = {
            'label': label,
            'imagePath': imagePath ?? '',
            'stock': stockData,
          };
        });

        collegeData[courseLabel] = courseItems;
      }

      setState(() {
        _collegeStockQuantities = collegeData;
      });
    } catch (e) {}
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot merchSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> merchData = merchSnapshot.data() as Map<
          String,
          dynamic>;
      Map<String, Map<String, dynamic>> processedMerchData = {};

      merchData.forEach((key, value) {
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

          processedMerchData[key] = {
            'label': key,
            'imagePath': value['imagePath'] ?? '',
            'stock': stockData,
          };
        }
      });

      setState(() {
        _merchStockQuantities = processedMerchData;
      });
    } catch (e) {}
  }

  void _showAddSizeDialog(String itemKey, Map<String, dynamic> itemData,
      String collectionType) {
    _selectedSize = null;
    _priceController.clear();
    _quantityController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Size and Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSize,
                items: _availableSizes.map((String size) {
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedSize = newValue;
                  });
                },
                decoration: InputDecoration(labelText: 'Size'),
              ),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_selectedSize != null) {
                  _addCustomSize(itemKey, itemData, collectionType);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addCustomSize(String itemKey, Map<String, dynamic> itemData, String collectionType) {
    String size = _selectedSize ?? '';
    double? price = _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null;
    int? newQuantity = _quantityController.text.isNotEmpty ? int.tryParse(_quantityController.text) : null;

    // Update quantity if size already exists
    if (itemData['stock'].containsKey(size)) {
      int currentQuantity = itemData['stock'][size]['quantity'];
      int updatedQuantity = newQuantity != null ? currentQuantity + newQuantity : currentQuantity;
      itemData['stock'][size] = {
        'quantity': updatedQuantity,
        'price': price ?? itemData['stock'][size]['price'], // Only update if a new price is provided
      };
    } else {
      // Add new size if it does not exist
      itemData['stock'][size] = {
        'quantity': newQuantity ?? 0,
        'price': price ?? 0.0,
      };
    }

    // Determine the correct Firestore path based on collectionType
    DocumentReference docRef;
    if (collectionType == 'senior_high_items') {
      docRef = firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items').doc(itemKey);
    } else if (collectionType == 'college_items') {
      docRef = firestore.collection('Inventory_stock').doc('college_items').collection(_selectedCourseLabel!).doc(itemKey);
    } else if (collectionType == 'Merch & Accessories') {
      docRef = firestore.collection('Inventory_stock').doc('Merch & Accessories').collection('Items').doc(itemKey);
    } else {
      return;
    }

    // Update the 'sizes' field directly in the document
    Map<String, dynamic> updateData = {
      'sizes.$size.quantity': newQuantity != null ? FieldValue.increment(newQuantity) : FieldValue.increment(0),
    };
    if (price != null) {
      updateData['sizes.$size.price'] = price;
    }

    docRef.update(updateData).then((_) {
      setState(() {
        _fetchInventoryData(); // Refresh data to update UI
      });
    });
  }

  Widget _buildItemCard(String itemKey, Map<String, dynamic> itemData, String collectionType) {
    String? imagePath = itemData['imagePath'];
    String label = itemData['label'];
    Map<String, dynamic>? stock = itemData['stock'];

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imagePath != null && imagePath.isNotEmpty)
            Image.network(
              imagePath,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  children: [
                    Icon(Icons.image_not_supported, size: 50),
                    Text('Image not available', style: TextStyle(fontSize: 12)),
                  ],
                );
              },
            )
          else
            Column(
              children: [
                Icon(Icons.image_not_supported, size: 50),
                Text('No Image Provided', style: TextStyle(fontSize: 12)),
              ],
            ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          if (stock != null && stock.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stock.keys.map((size) {
                    int currentQuantity = stock[size]['quantity'];
                    double currentPrice = stock[size]['price'];

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              '$size: $currentQuantity available, ₱$currentPrice'),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: currentQuantity > 0 ? () {
                            _updateQuantity(itemKey, size, -1, collectionType);
                          } : null,
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            _updateQuantity(itemKey, size, 1, collectionType);
                          },
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            )
          else
            Text('No sizes available'),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              _showAddSizeDialog(itemKey, itemData, collectionType);
            },
            child: Text('Add Size'),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(String itemKey, String size, int change, String collectionType) {
    DocumentReference docRef;
    if (collectionType == 'senior_high_items') {
      docRef = firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items').doc(itemKey);
    } else if (collectionType == 'college_items') {
      docRef = firestore.collection('Inventory_stock').doc('college_items').collection(_selectedCourseLabel!).doc(itemKey);
    } else if (collectionType == 'Merch & Accessories') {
      docRef = firestore.collection('Inventory_stock').doc('Merch & Accessories').collection('Items').doc(itemKey);
    } else {
      return;
    }

    setState(() {
      Map<String, dynamic>? targetData;
      if (collectionType == 'senior_high_items') {
        targetData = _seniorHighStockQuantities[itemKey];
      } else if (collectionType == 'college_items') {
        targetData = _collegeStockQuantities[_selectedCourseLabel!]![itemKey];
      } else if (collectionType == 'Merch & Accessories') {
        targetData = _merchStockQuantities[itemKey];
      }

      if (targetData != null && targetData['stock'].containsKey(size)) {
        int currentQuantity = targetData['stock'][size]['quantity'];
        int newQuantity = currentQuantity + change;

        if (newQuantity >= 0) {
          targetData['stock'][size]['quantity'] = newQuantity;

          // Update Firestore with new quantity
          docRef.update({
            'sizes.$size.quantity': FieldValue.increment(change),
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Page'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _fetchInventoryData();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Senior High Inventory
            Text(
              'Senior High Inventory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            _seniorHighStockQuantities.isEmpty
                ? Center(child: Text('No items available'))
                : GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
              children: _seniorHighStockQuantities.keys.map((itemKey) {
                Map<String,
                    dynamic> itemData = _seniorHighStockQuantities[itemKey]!;
                return _buildItemCard(itemKey, itemData, 'senior_high_items');
              }).toList(),
            ),
            SizedBox(height: 16),

            // College Inventory
            Text(
              'College Inventory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            DropdownButton<String>(
              value: _selectedCourseLabel,
              hint: Text('Select Course Label'),
              items: _courseLabels.map((String label) {
                return DropdownMenuItem<String>(
                  value: label,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCourseLabel = newValue;
                });
              },
            ),
            _selectedCourseLabel != null &&
                _collegeStockQuantities[_selectedCourseLabel!] != null
                ? GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
              children: _collegeStockQuantities[_selectedCourseLabel!]!.keys
                  .map((itemKey) {
                Map<String,
                    dynamic> itemData = _collegeStockQuantities[_selectedCourseLabel!]![itemKey]!;
                return _buildItemCard(itemKey, itemData, 'college_items');
              }).toList(),
            )
                : Center(child: Text('Select a course to view inventory')),
            SizedBox(height: 16),

            // Merch & Accessories Inventory
            Text(
              'Merch & Accessories Inventory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            _merchStockQuantities.isEmpty
                ? Center(child: Text('No items available'))
                : GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
              children: _merchStockQuantities.keys.map((itemKey) {
                Map<String, dynamic> itemData = _merchStockQuantities[itemKey]!;
                return _buildItemCard(itemKey, itemData, 'Merch & Accessories');
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}