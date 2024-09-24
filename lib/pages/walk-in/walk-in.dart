import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalkinPage extends StatefulWidget {
  @override
  _MainWalkInPageState createState() => _MainWalkInPageState();
}

class _MainWalkInPageState extends State<WalkinPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  final Map<String, String?> _selectedSizes = {};
  final Map<String, int> _selectedQuantities = {};
  String? _selectedCategory;
  String? _selectedSubcategory;

  // Store data fetched from Firestore
  Map<String, Map<String, Map<String, dynamic>>> _uniformsData = {};

  @override
  void initState() {
    super.initState();
    _fetchUniformsData();
  }

  Future<void> _fetchUniformsData() async {
    try {
      QuerySnapshot seniorHighSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('Senior_high_items')
          .collection('Items')
          .get();

      QuerySnapshot collegeSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('College_items')
          .collection('Items')
          .get();

      _parseUniformsData(seniorHighSnapshot, 'Senior High');
      _parseUniformsData(collegeSnapshot, 'College');

      setState(() {});
    } catch (e) {
      print('Error fetching inventory data: $e');
    }
  }

  void _parseUniformsData(QuerySnapshot snapshot, String category) {
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> filteredData = {};

      data.forEach((key, value) {
        if (value is Map && value.containsKey('quantity') && value.containsKey('price')) {
          filteredData[key] = {
            'quantity': value['quantity'],
            'price': value['price'],
          };
        }
      });

      _uniformsData[category] ??= {};
      _uniformsData[category]![doc.id] = filteredData;
    }
  }

  List<String> _sizeOrder = [
    'XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'
  ];

  List<String> _getSortedSizes(Map<String, dynamic> sizes) {
    List<String> sortedSizes = sizes.keys.toList();
    sortedSizes.sort((a, b) {
      int indexA = _sizeOrder.indexOf(a);
      int indexB = _sizeOrder.indexOf(b);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });
    return sortedSizes;
  }

  List<DropdownMenuItem<String>> _getSizeOptions(String item, String category) {
    Map<String, dynamic>? sizesMapDynamic = _uniformsData[category]?[item];

    if (sizesMapDynamic == null) return [];

    Map<String, dynamic> sizesMap = sizesMapDynamic.map((key, value) => MapEntry(key, value['quantity']));

    List<String> sortedSizes = _getSortedSizes(sizesMap);

    return [
      DropdownMenuItem<String>(
        value: 'None',
        child: Text('None'),
      ),
      ...sortedSizes.map((size) {
        return DropdownMenuItem<String>(
          value: size,
          child: Text('$size - ₱${sizesMapDynamic[size]?['price'] ?? 0}'),
        );
      }).toList(),
    ];
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String studentName = _nameController.text;
    String studentNumber = _studentNumberController.text;

    try {
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: studentName)
          .where('studentId', isEqualTo: studentNumber)
          .get();

      if (userSnapshot.docs.isEmpty) {
        Get.snackbar('Error', 'No matching user found with this name and student number');
        return;
      }

      DocumentSnapshot userDoc = userSnapshot.docs.first;

      CollectionReference cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('cart');

      List<Map<String, dynamic>> cartItems = [];

      for (String item in _selectedQuantities.keys) {
        int quantity = _selectedQuantities[item] ?? 0;
        String? size = _selectedSizes[item];

        if (quantity > 0 && size != null && size != 'None') {
          // Deduct quantity from Firestore inventory
          await _deductQuantityFromInventory(item, size, quantity);

          // Add the item to the cart
          DocumentReference cartItemRef = await cartRef.add({
            'itemLabel': item,
            'itemSize': size,
            'quantity': quantity,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });

          cartItems.add({
            'itemLabel': item,
            'itemSize': size,
            'quantity': quantity,
            'cartItemRef': cartItemRef.id,
          });

          // Update Sales History (approved_items collection)
          await _addToSalesHistory(item, size, quantity, studentName);

          // Update Sales Statistics
          await _updateSalesStatistics(item, size, quantity);
        }
      }

      CollectionReference adminRef = FirebaseFirestore.instance.collection('admin_transactions');

      await adminRef.add({
        'userId': userDoc.id,
        'userName': studentName,
        'studentNumber': studentNumber,
        'cartItems': cartItems,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Get.snackbar('Success', 'Order submitted successfully!');
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit the order. Please try again.');
    }
  }

// Add to Sales History (approved_items collection)
  Future<void> _addToSalesHistory(String item, String size, int quantity, String buyerName) async {
    await FirebaseFirestore.instance.collection('approved_items').add({
      'itemLabel': item,
      'itemSize': size,
      'quantity': quantity,
      'name': buyerName,
      'reservationDate': FieldValue.serverTimestamp(),
      'approvalDate': FieldValue.serverTimestamp(), // You can change this to actual approval date logic
    });
  }

// Update Sales Statistics
  Future<void> _updateSalesStatistics(String item, String size, int quantity) async {
    String collection = _selectedSubcategory == 'Senior High' ? 'senior_high_sales' : 'college_sales';

    // Reference to the sales document for this item and size
    DocumentReference salesRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(item);

    // Fetch current sales data
    DocumentSnapshot salesSnapshot = await salesRef.get();

    if (salesSnapshot.exists) {
      Map<String, dynamic>? salesData = salesSnapshot.data() as Map<String, dynamic>?;
      int currentSales = salesData?[size] ?? 0;
      await salesRef.update({
        size: currentSales + quantity,
      });
    } else {
      // If this item/size doesn't exist in sales stats, create it
      await salesRef.set({
        size: quantity,
      });
    }
  }

  Future<void> _deductQuantityFromInventory(String item, String size, int orderQuantity) async {
    // Determine the collection based on the selected category (Senior High or College)
    String collection = _selectedSubcategory == 'Senior High' ? 'Senior_high_items' : 'College_items';

    // Reference the item in the Firestore collection
    DocumentReference itemRef = FirebaseFirestore.instance
        .collection('Inventory_stock')
        .doc(collection)
        .collection('Items')
        .doc(item);

    // Get the current document snapshot for the item
    DocumentSnapshot itemSnapshot = await itemRef.get();

    if (itemSnapshot.exists) {
      Map<String, dynamic>? itemData = itemSnapshot.data() as Map<String, dynamic>?;

      // Check if the item has data and the selected size exists
      if (itemData != null && itemData.containsKey(size)) {
        int currentQuantity = itemData[size]['quantity'] ?? 0;

        // Log the current quantity and the order quantity
        print('Current Quantity for $item ($size): $currentQuantity');
        print('Order Quantity: $orderQuantity');

        if (currentQuantity > 0) {
          // Calculate the new quantity after the order
          int newQuantity = currentQuantity - orderQuantity;

          if (newQuantity < 0) {
            newQuantity = 0; // Avoid negative quantities
          }

          // Log the new quantity to be updated
          print('New Quantity: $newQuantity');

          // Update the Firestore document with the new quantity
          // Use the correct path for updating the nested quantity field (e.g., 2XL.quantity)
          await itemRef.update({
            '$size.quantity': newQuantity, // Correctly reference the nested field
          });

          print('Firestore updated successfully for $item ($size)');
        } else {
          print('Insufficient stock for $item ($size)');
        }
      } else {
        print('Size $size not found for item $item');
      }
    } else {
      print('Item $item not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Walk-In Order Form',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the student name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _studentNumberController,
                decoration: InputDecoration(
                  labelText: 'Student Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the student number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                onChanged: (newCategory) {
                  setState(() {
                    _selectedCategory = newCategory;
                    _selectedSubcategory = null;
                  });
                },
                items: ['Uniform'].map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_selectedCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedSubcategory,
                  onChanged: (newSubcategory) {
                    setState(() {
                      _selectedSubcategory = newSubcategory;
                    });
                  },
                  items: ['Senior High', 'College'].map((subcategory) {
                    return DropdownMenuItem<String>(
                      value: subcategory,
                      child: Text(subcategory),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Senior High or College',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              SizedBox(height: 16),
              if (_selectedSubcategory != null && _uniformsData[_selectedSubcategory] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'ITEMS IN ${_selectedSubcategory!.toUpperCase()}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2,
                      ),
                      itemCount: _uniformsData[_selectedSubcategory]!.keys.length,
                      itemBuilder: (context, index) {
                        String item = _uniformsData[_selectedSubcategory]!.keys.elementAt(index);
                        return Container(
                          height: 150,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                item,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
                              DropdownButton<String>(
                                value: _selectedSizes[item],
                                onChanged: (newSize) {
                                  setState(() {
                                    _selectedSizes[item] = newSize;
                                    if (newSize == 'None') {
                                      _selectedSizes.remove(item);
                                    }
                                  });
                                },
                                items: _getSizeOptions(item, _selectedSubcategory!),
                              ),
                              SizedBox(height: 4),
                              if (_selectedSizes[item] != null && _selectedSizes[item] != 'None')
                                Text(
                                  'Price: ₱${_uniformsData[_selectedSubcategory]?[item]?[_selectedSizes[item]]?['price'] ?? 0}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: () {
                                      int quantity = _selectedQuantities[item] ?? 0;
                                      if (quantity > 0) {
                                        setState(() {
                                          _selectedQuantities[item] = quantity - 1;
                                        });
                                      }
                                    },
                                  ),
                                  Text(
                                    '${_selectedQuantities[item] ?? 0}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () {
                                      int quantity = _selectedQuantities[item] ?? 0;
                                      setState(() {
                                        _selectedQuantities[item] = quantity + 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Submit Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
