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
    String? _selectedSchoolLevel;
    String? _selectedCourseLabel;

    Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
    Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
    Map<String, Map<String, dynamic>> _merchStockQuantities = {};

    List<String> _courseLabels = ['BACOMM', 'HRM & Culinary', 'IT&CPE', 'Tourism'];
    List<String> _schoolLevels = ['College', 'Senior High'];

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
        QuerySnapshot seniorHighSnapshot = await FirebaseFirestore.instance
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
            'sizes': stockData,
            'imagePath': imagePath ?? '',
            'label': label,
            'price': data['price'] ?? 0.0,
          };
        });

        setState(() {
          _seniorHighStockQuantities = seniorHighData;
        });
      } catch (e) {
        print('Error fetching Senior High stock: $e');
      }
    }

    Future<void> _fetchCollegeStock() async {
      try {
        Map<String, Map<String, dynamic>> collegeData = {};
        for (String courseLabel in _courseLabels) {
          QuerySnapshot courseSnapshot = await FirebaseFirestore.instance
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

            // Logic to include sizes for each item
            Map<String, dynamic> stockData = {};
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

            courseItems[doc.id] = {
              'label': label,
              'imagePath': imagePath ?? '',
              'price': price,
              'sizes': stockData,  // Add sizes to the data
            };
          });

          collegeData[courseLabel] = courseItems;
        }

        setState(() {
          _collegeStockQuantities = collegeData;
        });
      } catch (e) {
        print('Error fetching College stock: $e');
      }
    }

    Future<void> _fetchMerchStock() async {
      try {
        DocumentSnapshot merchSnapshot = await FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('Merch & Accessories')
            .get();

        Map<String, dynamic> merchData = merchSnapshot.data() as Map<String, dynamic>;
        Map<String, Map<String, dynamic>> processedMerchData = {};

        merchData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            // Processing sizes
            Map<String, dynamic> stockData = {};
            if (value.containsKey('sizes') && value['sizes'] is Map) {
              Map<String, dynamic> sizes = value['sizes'] as Map<String, dynamic>;
              sizes.forEach((sizeKey, sizeValue) {
                if (sizeValue is Map && sizeValue.containsKey('quantity')) {
                  stockData[sizeKey] = {
                    'quantity': sizeValue['quantity'],
                  };
                }
              });
            }

            processedMerchData[key] = {
              'label': key,
              'imagePath': value['imagePath'] ?? '',
              'price': value['price'] ?? 0.0,
              'sizes': stockData,  // Include the sizes data
            };
          }
        });

        setState(() {
          _merchStockQuantities = processedMerchData;
        });
      } catch (e) {
        print('Error fetching Merch & Accessories stock: $e');
      }
    }

    Widget _buildTextFormField({
      required TextEditingController controller,
      required String label,
      required String validator,
    }) {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return validator;
          }
          return null;
        },
      );
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
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Student Name',
                  validator: 'Please enter the student name',
                ),
                SizedBox(height: 16),
                _buildTextFormField(
                  controller: _studentNumberController,
                  label: 'Student Number',
                  validator: 'Please enter the student number',
                ),
                SizedBox(height: 32),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  onChanged: (newCategory) {
                    setState(() {
                      _selectedCategory = newCategory;
                      _selectedSchoolLevel = null;
                      _selectedCourseLabel = null;
                    });
                  },
                  items: ['Uniform', 'Merch & Accessories'].map((category) {
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
                if (_selectedCategory == 'Uniform')
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedSchoolLevel,
                        onChanged: (newValue) {
                          setState(() {
                            _selectedSchoolLevel = newValue;
                            _selectedCourseLabel = null;
                          });
                        },
                        items: _schoolLevels.map((level) {
                          return DropdownMenuItem<String>(
                            value: level,
                            child: Text(level),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          labelText: 'Select School Level',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      if (_selectedSchoolLevel == 'Senior High') _buildSeniorHighItems(),
                      if (_selectedSchoolLevel == 'College')
                        Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedCourseLabel,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedCourseLabel = newValue;
                                });
                              },
                              items: _courseLabels.map((courseLabel) {
                                return DropdownMenuItem<String>(
                                  value: courseLabel,
                                  child: Text(courseLabel),
                                );
                              }).toList(),
                              decoration: InputDecoration(
                                labelText: 'Select Course Label',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            if (_selectedCourseLabel != null)
                              _buildCollegeItems(_selectedCourseLabel!),
                          ],
                        ),
                    ],
                  ),
                if (_selectedCategory == 'Merch & Accessories')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MERCH & ACCESSORIES',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      _buildMerchGrid(),
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

    Widget _buildSeniorHighItems() {
      return Column(
        children: [
          Text(
            'ITEMS IN Senior High',
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
              childAspectRatio: 1.5,
            ),
            itemCount: _seniorHighStockQuantities.keys.length,
            itemBuilder: (context, index) {
              String itemKey = _seniorHighStockQuantities.keys.elementAt(index);
              return _buildItemCard(_seniorHighStockQuantities[itemKey]!);
            },
          ),
        ],
      );
    }

    Widget _buildCollegeItems(String courseLabel) {
      return Column(
        children: [
          Text(
            'ITEMS IN $courseLabel',
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
              childAspectRatio: 1.5,
            ),
            itemCount: _collegeStockQuantities[courseLabel]?.keys.length ?? 0,
            itemBuilder: (context, index) {
              String itemKey = _collegeStockQuantities[courseLabel]!.keys.elementAt(index);
              return _buildItemCard(_collegeStockQuantities[courseLabel]![itemKey]!);
            },
          ),
        ],
      );
    }

    Widget _buildMerchGrid() {
      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemCount: _merchStockQuantities.keys.length,
        itemBuilder: (context, index) {
          String item = _merchStockQuantities.keys.elementAt(index);
          return _buildItemCard(_merchStockQuantities[item]!);
        },
      );
    }

    Widget _buildItemCard(Map<String, dynamic>? itemData) {
      String itemLabel = itemData?['label'] ?? 'Unknown';
      double price = itemData?['price'] ?? 0;
      Map<String, dynamic>? sizes = itemData?['sizes'];

      // Check if sizes are available for this item
      List<String> availableSizes = sizes != null ? sizes.keys.toList() : [];

      // Get the selected size for this item
      String? selectedSize = _selectedSizes[itemLabel];

      // Set default quantity if not initialized
      _selectedQuantities[itemLabel] = _selectedQuantities[itemLabel] ?? 0;

      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              itemLabel,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Price: ₱$price',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            SizedBox(height: 8),

            // Dropdown to select the size
            if (availableSizes.isNotEmpty)
              DropdownButton<String>(
                value: selectedSize,
                hint: Text('Select Size'),
                onChanged: (newSize) {
                  setState(() {
                    _selectedSizes[itemLabel] = newSize;
                    // Reset the quantity when a new size is selected
                    _selectedQuantities[itemLabel] = 0;
                  });
                },
                items: availableSizes.map((size) {
                  int currentQuantity = sizes![size]['quantity'] ?? 0;
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Text('$size: $currentQuantity available'),
                  );
                }).toList(),
              )
            else
              Text('No sizes available'),

            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    int quantity = _selectedQuantities[itemLabel] ?? 0;
                    if (quantity > 0) {
                      setState(() {
                        _selectedQuantities[itemLabel] = quantity - 1;
                      });
                    }
                  },
                ),
                Text(
                  '${_selectedQuantities[itemLabel] ?? 0}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (selectedSize != null) {
                      int currentQuantity = _selectedQuantities[itemLabel] ?? 0;
                      int availableQuantity = sizes![selectedSize]['quantity'] ?? 0;

                      // Allow increment only if current quantity is less than available quantity
                      if (currentQuantity < availableQuantity) {
                        setState(() {
                          _selectedQuantities[itemLabel] = currentQuantity + 1;
                        });
                      } else {
                        Get.snackbar('Quantity Limit', 'Cannot exceed available quantity for $selectedSize.');
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    Future<void> _submitOrder() async {
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Check if any item has been selected
      bool hasSelectedItem = _selectedQuantities.values.any((quantity) => quantity > 0);

      if (!hasSelectedItem) {
        Get.snackbar('Error', 'No items selected. Please add at least one item to the order.');
        return; // Prevent submission if no item is selected
      }

      String studentName = _nameController.text;
      String studentNumber = _studentNumberController.text;

      try {
        // Find the user document
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

        // Add items to user's cart
        CollectionReference cartRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('cart');

        List<Map<String, dynamic>> cartItems = [];

        for (String item in _selectedQuantities.keys) {
          int quantity = _selectedQuantities[item] ?? 0;
          String? size = _selectedSizes[item];

          if (quantity > 0 && size != null && size != 'None') {
            // Add category field based on the selected category
            String category;
            String? courseLabel;

            if (_selectedCategory == 'Uniform') {
              if (_selectedSchoolLevel == 'Senior High') {
                category = 'senior_high_items';
              } else {
                category = 'college_items';
                courseLabel = _selectedCourseLabel;  // Include course label for college items
              }
            } else {
              category = 'Merch & Accessories';
            }

            // Add item to cart
            DocumentReference cartItemRef = await cartRef.add({
              'itemLabel': item,
              'itemSize': size,
              'quantity': quantity,
              'status': 'pending',
              'category': category,
              'courseLabel': courseLabel,  // Add courseLabel for college items
              'timestamp': FieldValue.serverTimestamp(),
            });

            cartItems.add({
              'itemLabel': item,
              'itemSize': size,
              'quantity': quantity,
              'cartItemRef': cartItemRef.id,
              'category': category,
              'courseLabel': courseLabel,  // Include the course label in the cart items
            });

            // Deduct the quantity from Firestore
            await _deductItemQuantity(item, size, quantity);
          }
        }

        // Create transaction record with category information
        CollectionReference adminRef = FirebaseFirestore.instance.collection('admin_transactions');
        await adminRef.add({
          'userId': userDoc.id,
          'userName': studentName,
          'studentNumber': studentNumber,
          'cartItems': cartItems,
          'category': _selectedCategory,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await _sendNotificationToUser(userDoc.id, studentName, cartItems);

        Get.snackbar('Success', 'Order submitted successfully!');

        // Call the refresh function after a successful order
        _refreshData();  // Add this line to refresh inventory

      } catch (e) {
        Get.snackbar('Error', 'Failed to submit the order. Please try again.');
      }
    }

    void _refreshData() {
      setState(() {
        _selectedSizes.clear();
        _selectedQuantities.clear();
        _loading = true;
      });

      // Fetch the updated inventory data
      _fetchInventoryData().then((_) {
        setState(() {
          _loading = false;  // Hide loading indicator after fetching
        });
      });
    }

    Future<void> _deductItemQuantity(String itemLabel, String size, int quantity) async {
      try {
        CollectionReference itemsRef;

        // Determine the collection to query based on the selected category and school level
        if (_selectedCategory == 'Uniform') {
          if (_selectedSchoolLevel == 'Senior High') {
            // Reference the senior high items collection
            itemsRef = FirebaseFirestore.instance
                .collection('Inventory_stock')
                .doc('senior_high_items')
                .collection('Items');
          } else if (_selectedSchoolLevel == 'College') {
            // Reference the college items collection
            itemsRef = FirebaseFirestore.instance
                .collection('Inventory_stock')
                .doc('college_items')
                .collection(_selectedCourseLabel ?? ''); // Use the selected course label for the sub-collection
          } else {
            print('Unknown school level.');
            return;
          }
        } else if (_selectedCategory == 'Merch & Accessories') {
          // Reference the Merch & Accessories collection
          itemsRef = FirebaseFirestore.instance
              .collection('Inventory_stock')
              .doc('Merch & Accessories')
              .collection('Items');
        } else {
          print('Unknown category.');
          return;
        }

        // Query the collection for the document where the label matches the itemLabel
        QuerySnapshot querySnapshot = await itemsRef
            .where('label', isEqualTo: itemLabel)
            .limit(1) // Limit to 1 result since label should be unique
            .get();

        // Check if we found a document
        if (querySnapshot.docs.isEmpty) {
          print('Item $itemLabel does not exist.');
          return;
        }

        // Get the first document (there should be only one)
        DocumentSnapshot itemDoc = querySnapshot.docs.first;

        // Extract item data and sizes
        Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> sizes = itemData['sizes'] as Map<String, dynamic>;

        // Get current quantity for the selected size
        int currentQuantity = sizes[size]['quantity'];

        if (currentQuantity >= quantity) {
          // Deduct the quantity
          sizes[size]['quantity'] = currentQuantity - quantity;

          // Update the Firestore document with the new sizes data
          await itemsRef.doc(itemDoc.id).update({'sizes': sizes});

          print('Quantity updated for $itemLabel, size $size: New quantity is ${sizes[size]['quantity']}');
        } else {
          print('Insufficient quantity for $itemLabel, size $size.');
        }
      } catch (e) {
        print('Error deducting item quantity: $e');
      }
    }

    Future<void> _sendNotificationToUser(String userId, String studentName, List<Map<String, dynamic>> cartItems) async {
      String notificationMessage = 'Your order has been placed successfully.';

      List<Map<String, dynamic>> sortedOrderSummary = cartItems.map((item) {
        String itemLabel = item['itemLabel'];
        String? itemCategory = item['category'];
        String? courseLabel = item['courseLabel'];  // Add courseLabel if applicable
        int quantity = item['quantity'];

        // Retrieve the price depending on the category and the course label
        double pricePerPiece = 0.0;

        if (itemCategory == 'senior_high_items') {
          pricePerPiece = _seniorHighStockQuantities[itemLabel]?['price'] ?? 0.0;
        } else if (itemCategory == 'college_items' && courseLabel != null) {
          pricePerPiece = _collegeStockQuantities[courseLabel]?[itemLabel]?['price'] ?? 0.0;
        } else if (itemCategory == 'Merch & Accessories') {
          pricePerPiece = _merchStockQuantities[itemLabel]?['price'] ?? 0.0;
        }

        double totalPrice = pricePerPiece * quantity;

        return {
          'itemLabel': itemLabel,
          'itemSize': item['itemSize'],
          'quantity': quantity,
          'pricePerPiece': pricePerPiece,
          'totalPrice': totalPrice,
          'courseLabel': courseLabel,  // Include courseLabel in the order summary
        };
      }).toList();

      sortedOrderSummary.sort((a, b) => a['itemLabel'].compareTo(b['itemLabel']));

      CollectionReference notificationsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      await notificationsRef.add({
        'title': 'Order Placed',
        'message': notificationMessage,
        'orderSummary': sortedOrderSummary,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });
    }
  }