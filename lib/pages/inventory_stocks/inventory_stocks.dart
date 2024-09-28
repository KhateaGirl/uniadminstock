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
  final List<String> _courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism'];

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
    } catch (e) {
    }
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
          String label = data['label'] != null ? data['label'] as String : doc.id;
          double price = data['price'] != null ? data['price'] as double : 0.0;

          courseItems[doc.id] = {
            'label': label,
            'imagePath': imagePath ?? '',
            'price': price,
          };
        });

        collegeData[courseLabel] = courseItems;
      }

      setState(() {
        _collegeStockQuantities = collegeData;
      });
    } catch (e) {
    }
  }

  Future<void> _fetchMerchStock() async {
    try {
      DocumentSnapshot merchSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> merchData = merchSnapshot.data() as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> processedMerchData = {};

      merchData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          processedMerchData[key] = {
            'label': key,
            'imagePath': value['imagePath'] ?? '',
            'price': value['price'] ?? 0.0,
          };
        }
      });

      setState(() {
        _merchStockQuantities = processedMerchData;
      });
    } catch (e) {
    }
  }

  Future<void> _addCustomSize(String itemKey, String customSize, int quantity, double? price, String collectionType) async {
    try {
      DocumentReference itemRef;

      if (collectionType == 'Merch & Accessories') {
        itemRef = FirebaseFirestore.instance.collection('Inventory_stock').doc('Merch & Accessories');
      } else if (collectionType == 'senior_high_items') {
        itemRef = FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('senior_high_items')
            .collection('Items')
            .doc(itemKey);
      } else {
        String? courseLabel = _selectedCourseLabel;
        if (courseLabel == null) {
          throw 'Course label not selected';
        }
        itemRef = FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .doc(itemKey);
      }

      // Fetch current item data
      DocumentSnapshot documentSnapshot = await itemRef.get();
      Map<String, dynamic>? currentItemData = documentSnapshot.data() as Map<String, dynamic>?;

      // Check and fetch the sizes data
      Map<String, dynamic> sizesData = currentItemData != null && currentItemData['sizes'] is Map<String, dynamic>
          ? currentItemData['sizes'] as Map<String, dynamic> : {};

      // Check if size already exists and its quantity
      Map<String, dynamic> sizeData = sizesData[customSize] ?? {'quantity': 0};
      int currentQuantity = sizeData['quantity'] ?? 0;

      // Limit quantity to prevent exceeding total availability
      int newQuantity = currentQuantity + quantity;
      if (newQuantity > 5) { // Assuming 5 is the maximum allowed quantity as per your screenshots
        // Show an error message to the user if they are trying to add more than available stock
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot add more than available stock (5 items)')),
        );
        return;
      }

      // Update size quantity
      sizeData['quantity'] = newQuantity;
      sizesData[customSize] = sizeData;

      // Prepare update data
      Map<String, dynamic> updateData = {'sizes': sizesData};
      if (price != null) {
        updateData['price'] = price;
      }

      // Update FirestoreF  F
      await itemRef.update(updateData);

      // Update local state
      setState(() {
        if (collectionType == 'senior_high_items') {
          _seniorHighStockQuantities[itemKey]?['sizes'] = sizesData;
          if (price != null) {
            _seniorHighStockQuantities[itemKey]?['price'] = price;
          }
        } else if (collectionType == 'Merch & Accessories') {
          _merchStockQuantities[itemKey]?['sizes'] = sizesData;
          if (price != null) {
            _merchStockQuantities[itemKey]?['price'] = price;
          }
        } else {
          _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['sizes'] = sizesData;
          if (price != null) {
            _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['price'] = price;
          }
        }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showCustomSizeDialog(String itemKey, String collectionType) {
    String customSize = 'Small';
    int customQuantity = 1;
    double? customPrice;
    TextEditingController _priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Custom Size for $itemKey'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: customSize,
                    onChanged: (String? newValue) {
                      setState(() {
                        customSize = newValue!;
                      });
                    },
                    items: ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Quantity:'),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (customQuantity > 1) customQuantity--;
                          });
                        },
                      ),
                      Text('$customQuantity'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            customQuantity++;
                          });
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      hintText: 'Enter price (optional)',
                    ),
                    onChanged: (value) {
                      customPrice = double.tryParse(value);
                    },
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
                ElevatedButton(
                  onPressed: () {
                    _addCustomSize(itemKey, customSize, customQuantity, customPrice, collectionType);
                    Navigator.of(context).pop();
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Widget _buildItemCard(String itemKey, Map<String, dynamic> itemData, String collectionType) {
    String? imagePath = itemData['imagePath'];
    String label = itemData['label'];
    double price = itemData['price'];
    Map<String, dynamic>? stock = itemData['sizes'];

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
          Text(
            '₱$price',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          SizedBox(height: 8),
          if (stock != null && stock.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: stock.keys.map((size) {
                int currentQuantity = stock[size]['quantity'];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$size: $currentQuantity available'),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            if (currentQuantity > 0) {
                              _updateSizeQuantity(itemKey, size, currentQuantity - 1, collectionType);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            _updateSizeQuantity(itemKey, size, currentQuantity + 1, collectionType);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            )
          else
            Text('No sizes available'),
          ElevatedButton(
            onPressed: () {
              _showCustomSizeDialog(itemKey, collectionType);
            },
            child: Text('Add Custom Size'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSizeQuantity(String itemKey, String size, int newQuantity, String collectionType) async {
    try {
      DocumentReference itemRef;

      if (collectionType == 'Merch & Accessories') {
        itemRef = firestore.collection('Inventory_stock').doc('Merch & Accessories');
      } else if (collectionType == 'senior_high_items') {
        itemRef = firestore.collection('Inventory_stock').doc('senior_high_items').collection('Items').doc(itemKey);
      } else {
        String? courseLabel = _selectedCourseLabel;
        if (courseLabel == null) {
          throw 'Course label not selected';
        }
        itemRef = firestore.collection('Inventory_stock')
            .doc('college_items')
            .collection(courseLabel)
            .doc(itemKey);
      }

      await itemRef.update({
        'sizes.$size.quantity': newQuantity,
      });

      setState(() {
        if (collectionType == 'senior_high_items') {
          _seniorHighStockQuantities[itemKey]?['sizes']?[size]['quantity'] = newQuantity;
        } else if (collectionType == 'Merch & Accessories') {
          _merchStockQuantities[itemKey]?['sizes']?[size]['quantity'] = newQuantity;
        } else {
          _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['sizes']?[size]['quantity'] = newQuantity;
        }
      });
    } catch (e) {
    }
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
              _fetchInventoryData(); // Manually refresh the data
            },
          ),
        ],
      ),
      // Show loading spinner while data is being fetched
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
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
                Map<String, dynamic> itemData = _seniorHighStockQuantities[itemKey]!;
                return _buildItemCard(itemKey, itemData, 'senior_high_items');
              }).toList(),
            ),
            SizedBox(height: 16),
            Text(
              'College Inventory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            DropdownButton<String>(
              hint: Text('Select Course Label'),
              value: _selectedCourseLabel,
              items: _courseLabels.map((label) {
                return DropdownMenuItem(
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
            SizedBox(height: 16),
            if (_selectedCourseLabel != null &&
                _collegeStockQuantities[_selectedCourseLabel!] != null)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
                children: _collegeStockQuantities[_selectedCourseLabel!]!.keys
                    .map((itemKey) {
                  Map<String, dynamic> itemData = _collegeStockQuantities[_selectedCourseLabel!]![itemKey];
                  return _buildItemCard(itemKey, itemData, 'college_items');
                }).toList(),
              ),
            SizedBox(height: 16),
            Text(
              'Merch & Accessories',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            GridView.count(
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