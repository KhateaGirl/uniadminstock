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
    _fetchStockData();
  }

  Future<void> _fetchStockData() async {
    try {
      // Fetch the Senior High items
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

        data.forEach((key, value) {
          if (value is Map && value.containsKey('quantity')) {
            stockData[key] = {
              'quantity': value['quantity'],
              'price': value.containsKey('price') ? value['price'] : 0,  // Default to 0 if price is missing
            };
          }
        });


        seniorHighData[doc.id] = {
          'stock': stockData,
          'imagePath': imagePath ?? '',
          'label': label,
          'price': data['price'] ?? 0.0,
        };
      });

      // Fetch the College items for each course label
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

      // Fetch the Merch & Accessories items
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
        _seniorHighStockQuantities = seniorHighData;
        _collegeStockQuantities = collegeData;
        _merchStockQuantities = processedMerchData;
        _loading = false;
      });
    } catch (e) {
      print('Failed to fetch inventory data: $e');
    }
  }

  Future<void> _addCustomSize(String itemKey, String customSize, int quantity, double? price, String collectionType) async {
    try {
      DocumentReference itemRef = firestore
          .collection('Inventory_stock')
          .doc(collectionType)
          .collection('Items')
          .doc(itemKey);

      DocumentSnapshot documentSnapshot = await itemRef.get();
      Map<String, dynamic>? currentItemData = documentSnapshot.data() as Map<String, dynamic>?;

      // Get the current data for the size or default values
      Map<String, dynamic> sizeData = currentItemData != null && currentItemData[customSize] is Map<String, dynamic>
          ? currentItemData[customSize] as Map<String, dynamic>
          : {'quantity': 0};  // Note: No 'price' field in the size data now

      int newQuantity = (sizeData['quantity'] ?? 0) + quantity;

      // Prepare the update data for Firestore
      Map<String, dynamic> updateData = {
        '$customSize.quantity': newQuantity, // Only update the quantity in the nested size
      };

      // Only update the main price if a new valid price is provided
      if (price != null && price > 0) {
        updateData['price'] = price;  // Update the global item price
      }

      await itemRef.update(updateData);

      // Update the local state with the new size data and the overall price
      setState(() {
        if (collectionType == 'senior_high_items') {
          _seniorHighStockQuantities[itemKey]?['stock']?[customSize] = {
            'quantity': newQuantity,  // Update quantity only in the nested size
          };
          if (price != null && price > 0) {
            _seniorHighStockQuantities[itemKey]?['price'] = price;  // Update the item's overall price
          }
        } else if (collectionType == 'college_items') {
          _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['stock']?[customSize] = {
            'quantity': newQuantity,
          };
          if (price != null && price > 0) {
            _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['price'] = price;
          }
        } else {
          _merchStockQuantities[itemKey]?['stock']?[customSize] = {
            'quantity': newQuantity,
          };
          if (price != null && price > 0) {
            _merchStockQuantities[itemKey]?['price'] = price;
          }
        }
      });
    } catch (e) {
      print('Failed to add custom size: $e');
    }
  }

  void _showCustomSizeDialog(String itemKey, String collectionType) {
    String customSize = 'Small';
    int customQuantity = 1;
    double? customPrice; // Make price nullable to validate it later

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
                    items: ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL']
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
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Price'),
                    onChanged: (value) {
                      customPrice = double.tryParse(value); // Try to parse the price
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
                    // Check if price is valid
                    if (customPrice == null || customPrice! <= 0) {
                      // Show an error if price is invalid
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid price')),
                      );
                    } else {
                      _addCustomSize(itemKey, customSize, customQuantity, customPrice!, collectionType);
                      Navigator.of(context).pop();
                    }
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
    double price = itemData['price']; // Display the updated overall price
    Map<String, dynamic>? stock = itemData['stock']; // This holds the sizes like Small, Medium, etc.

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
          // Show the updated main price of the item
          Text(
            '₱$price', // Display the overall price of the item
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          SizedBox(height: 8),
          // Display available sizes and their quantities with increment/decrement buttons
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
            Text('No sizes available'),  // Fallback if no sizes are found
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
      DocumentReference itemRef = firestore
          .collection('Inventory_stock')
          .doc(collectionType)
          .collection('Items')
          .doc(itemKey);

      // Update the size quantity in Firestore
      await itemRef.update({
        '$size.quantity': newQuantity,
      });

      // Update the local state with the new quantity
      setState(() {
        if (collectionType == 'senior_high_items') {
          _seniorHighStockQuantities[itemKey]?['stock']?[size]['quantity'] = newQuantity;
        } else if (collectionType == 'college_items') {
          _collegeStockQuantities[_selectedCourseLabel!]?[itemKey]?['stock']?[size]['quantity'] = newQuantity;
        } else {
          _merchStockQuantities[itemKey]?['stock']?[size]['quantity'] = newQuantity;
        }
      });
    } catch (e) {
      print('Failed to update size quantity: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Page'),
      ),
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
            GridView.count(
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
