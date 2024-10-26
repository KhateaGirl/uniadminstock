import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        String? imagePath = data['imagePath'] as String?;
        String label = data['label'] != null ? data['label'] as String : doc.id;

        double defaultPrice = data['price'] != null ? data['price'] as double : 0.0;

        Map<String, dynamic> stockData = {};
        if (data.containsKey('sizes') && data['sizes'] is Map) {
          Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
          sizes.forEach((sizeKey, sizeValue) {
            if (sizeValue is Map) {
              int quantity = sizeValue['quantity'] ?? 0;
              double sizePrice = sizeValue['price'] ?? defaultPrice;

              stockData[sizeKey] = {
                'quantity': quantity,
                'price': sizePrice,
              };
            }
          });
        }

        seniorHighData[doc.id] = {
          'label': label,
          'imagePath': imagePath ?? '',
          'defaultPrice': defaultPrice,
          'sizes': stockData,
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

          double defaultPrice = data['price'] != null ? data['price'] as double : 0.0;

          Map<String, dynamic> stockData = {};
          if (data.containsKey('sizes') && data['sizes'] is Map) {
            Map<String, dynamic> sizes = data['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map) {
                int quantity = sizeValue['quantity'] ?? 0;
                double sizePrice = sizeValue['price'] ?? defaultPrice;

                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
            });
          }

          courseItems[doc.id] = {
            'label': label,
            'imagePath': imagePath ?? '',
            'defaultPrice': defaultPrice,
            'sizes': stockData,
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
      DocumentSnapshot merchSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('Merch & Accessories')
          .get();

      Map<String, dynamic> merchData = merchSnapshot.data() as Map<String, dynamic>;
      Map<String, Map<String, dynamic>> processedMerchData = {};

      merchData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          String? imagePath = value['imagePath'] as String?;
          double defaultPrice = value['price'] != null ? value['price'] as double : 0.0;

          Map<String, dynamic> stockData = {};
          if (value.containsKey('sizes') && value['sizes'] is Map) {
            Map<String, dynamic> sizes = value['sizes'] as Map<String, dynamic>;
            sizes.forEach((sizeKey, sizeValue) {
              if (sizeValue is Map) {
                int quantity = sizeValue['quantity'] ?? 0;
                double sizePrice = sizeValue['price'] ?? defaultPrice;

                stockData[sizeKey] = {
                  'quantity': quantity,
                  'price': sizePrice,
                };
              }
            });
          }

          processedMerchData[key] = {
            'label': key,
            'imagePath': imagePath ?? '',
            'defaultPrice': defaultPrice,
            'sizes': stockData,
          };
        }
      });

      setState(() {
        _merchStockQuantities = processedMerchData;
      });
    } catch (e) {
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
    double defaultPrice = itemData?['defaultPrice'] ?? 0;
    Map<String, dynamic>? sizes = itemData?['sizes'];

    List<String> availableSizes = sizes != null ? sizes.keys.toList() : [];
    String? selectedSize = _selectedSizes[itemLabel];
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
          if (selectedSize != null && sizes != null && sizes.containsKey(selectedSize))
            Text(
              'Price: ₱${sizes[selectedSize]?['price'] ?? defaultPrice}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            )
          else
            Text(
              'Default Price: ₱$defaultPrice',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          SizedBox(height: 8),

          if (availableSizes.isNotEmpty)
            DropdownButton<String>(
              value: selectedSize,
              hint: Text('Select Size'),
              onChanged: (newSize) {
                setState(() {
                  _selectedSizes[itemLabel] = newSize;
                  _selectedQuantities[itemLabel] = 0;

                  double selectedPrice = sizes![newSize]?['price'] ?? defaultPrice;
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

  Future<void> _sendSMSToUser(String studentId, String studentName, double totalAmount, List<Map<String, dynamic>> cartItems) async {
    try {
      // Retrieve the user document by studentId and name
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .where('name', isEqualTo: studentName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userSnapshot = querySnapshot.docs.first;

        // Extract contact number from user document
        String? contactNumber = (userSnapshot.data() as Map<String, dynamic>)['contactNumber'];

        if (contactNumber != null && contactNumber.isNotEmpty) {
          // Construct the SMS message
          String message = "Hello $studentName with student ID $studentId, your order has been placed successfully. Total amount: ₱$totalAmount. Items: ";

          // Append cart items to the message
          for (var item in cartItems) {
            message += "${item['itemLabel']} (x${item['quantity']}), ";
          }
          message = message.trimRight().replaceAll(RegExp(r',\s*$'), '');

          // Send SMS request to your server
          final response = await http.post(
            Uri.parse('http://localhost:3000/send-sms'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'apikey': dotenv.env['APIKEY'] ?? '',
              'number': contactNumber,
              'message': message,
              'sendername': dotenv.env['SENDERNAME'] ?? 'Unistock',
            }),
          );

          if (response.statusCode == 200) {
            print("SMS sent successfully to $contactNumber");
          } else {
            print("Failed to send SMS: ${response.body}");
          }
        } else {
          print("Contact number is not available for studentId: $studentId and name: $studentName");
        }
      } else {
        print("User document does not exist for studentId: $studentId and name: $studentName");
      }
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    bool hasSelectedItem = _selectedQuantities.values.any((quantity) => quantity > 0);

    if (!hasSelectedItem) {
      Get.snackbar('Error', 'No items selected. Please add at least one item to the order.');
      return;
    }

    String studentName = _nameController.text;
    String studentNumber = _studentNumberController.text;

    try {
      List<Map<String, dynamic>> cartItems = [];
      double totalAmount = 0.0;

      for (String item in _selectedQuantities.keys) {
        int quantity = _selectedQuantities[item] ?? 0;
        String? size = _selectedSizes[item];
        if (quantity > 0 && size != null && size != 'None') {
          String category;
          String? courseLabel;

          if (_selectedCategory == 'Uniform') {
            if (_selectedSchoolLevel == 'Senior High') {
              category = 'senior_high_items';
            } else {
              category = 'college_items';
              courseLabel = _selectedCourseLabel;
            }
          } else {
            category = 'Merch & Accessories';
          }

          String documentId = _findDocumentIdForItem(item);

          if (documentId == null) {
            print("Warning: Document ID not found for item $item");
            continue;
          }

          double itemPrice = _getItemPrice(category, item, courseLabel, size);
          double total = itemPrice * quantity;

          totalAmount += total;

          Map<String, dynamic> itemData = {
            'itemLabel': item,
            'itemSize': size,
            'quantity': quantity,
            'category': category,
            'courseLabel': courseLabel,
            'total': total,
          };

          cartItems.add(itemData);

          await _deductItemQuantity(item, size, quantity);
          CollectionReference approvedItemsRef = FirebaseFirestore.instance.collection('approved_items');

          await approvedItemsRef.add({
            'itemLabel': item,
            'itemSize': size,
            'name': studentName,
            'pricePerPiece': itemPrice,
            'quantity': quantity,
            'total': total,
            'reservationDate': FieldValue.serverTimestamp(),
            'approvalDate': FieldValue.serverTimestamp(),
          });
        }
      }

      CollectionReference adminRef = FirebaseFirestore.instance.collection('admin_transactions');
      await adminRef.add({
        'userName': studentName,
        'studentNumber': studentNumber,
        'cartItems': cartItems,
        'category': _selectedCategory,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _sendSMSToUser(studentNumber, studentName, totalAmount, cartItems);

      Get.snackbar('Success', 'Order submitted and SMS sent successfully!');
      _refreshData();

    } catch (e) {
      Get.snackbar('Error', 'Failed to submit the order. Please try again.');
      print('Error in _submitOrder: $e');
    }
  }

  double _getItemPrice(String category, String itemLabel, String? courseLabel, String selectedSize) {

    double price = 0.0;
    String documentId = _findDocumentIdForItem(itemLabel);

    if (category == 'senior_high_items') {

      price = _seniorHighStockQuantities[documentId]?['sizes']?[selectedSize]?['price'] ??
          _seniorHighStockQuantities[documentId]?['defaultPrice'] ?? 0.0;

      if (price == 0.0) {
      }
    } else if (category == 'college_items' && courseLabel != null) {

      _collegeStockQuantities[courseLabel]?.forEach((docId, itemData) {
        if (itemData['label'] == itemLabel) {
          price = itemData['sizes']?[selectedSize]?['price'] ?? itemData['defaultPrice'] ?? 0.0;
        }
      });

      if (price == 0.0) {
      }
    } else if (category == 'Merch & Accessories') {

      price = _merchStockQuantities[documentId]?['sizes']?[selectedSize]?['price'] ??
          _merchStockQuantities[documentId]?['defaultPrice'] ?? 0.0;

      if (price == 0.0) {
      }
    } else {
    }

    return price;
  }

  String _findDocumentIdForItem(String itemLabel) {
    Map<String, String> labelToIdMap = {
      "Blouse with Vest": "SHS_BLOUSE_WITH_VEST",
      "Polo with Vest": "SHS_POLO_WITH_VEST",
      "SHS APRON": "SHS_APRON",
      "SHS NECKTIE": "SHS_NECKTIE",
      "SHS PANTS": "SHS_PANTS",
      "SHS PE PANTS": "SHS_PE_PANTS",
      "SHS PE SHIRT": "SHS_PE_SHIRT",
      "SHS Skirt": "SHS_SKIRT",
      "SHS Washday": "SHS_WASHDAY",
      "STI Checkered Beanie": "STI_CHECKERED_BEANIE",
      "STI Checkered Pants": "STI_LONG_CHECKERED_PANTS",
      "STI Chef's Blouse": "STI_WHITE_CHEF_LONG_SLEEVE_BLOUSE"
    };

    return labelToIdMap[itemLabel] ?? itemLabel;
  }

  void _refreshData() {
    setState(() {
      _selectedSizes.clear();
      _selectedQuantities.clear();
      _loading = true;
    });

    _fetchInventoryData().then((_) {
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> _deductItemQuantity(String itemLabel, String size, int quantity) async {
    try {
      CollectionReference itemsRef;

      if (_selectedCategory == 'Uniform') {
        if (_selectedSchoolLevel == 'Senior High') {
          itemsRef = FirebaseFirestore.instance
              .collection('Inventory_stock')
              .doc('senior_high_items')
              .collection('Items');
        } else if (_selectedSchoolLevel == 'College') {
          itemsRef = FirebaseFirestore.instance
              .collection('Inventory_stock')
              .doc('college_items')
              .collection(_selectedCourseLabel ?? '');
        } else {
          return;
        }
      } else if (_selectedCategory == 'Merch & Accessories') {
        itemsRef = FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc('Merch & Accessories')
            .collection('Items');
      } else {
        return;
      }

      QuerySnapshot querySnapshot = await itemsRef
          .where('label', isEqualTo: itemLabel)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return;
      }

      DocumentSnapshot itemDoc = querySnapshot.docs.first;

      Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> sizes = itemData['sizes'] as Map<String, dynamic>;

      int currentQuantity = sizes[size]['quantity'];

      if (currentQuantity >= quantity) {
        sizes[size]['quantity'] = currentQuantity - quantity;
        await itemsRef.doc(itemDoc.id).update({'sizes': sizes});

      } else {
      }
    } catch (e) {
    }
  }

  Future<void> _sendNotificationToUser(String userId, String studentName, List<Map<String, dynamic>> cartItems) async {
    String notificationMessage = 'Your order has been placed successfully.';

    List<Map<String, dynamic>> sortedOrderSummary = cartItems.map((item) {
      String itemLabel = item['itemLabel'];
      String? itemCategory = item['category'];
      String? courseLabel = item['courseLabel'];
      int quantity = item['quantity'];
      double pricePerPiece = 0.0;

      if (itemCategory == 'senior_high_items') {
        pricePerPiece = _seniorHighStockQuantities[itemLabel]?['sizes']?[item['itemSize']]?['price'] ?? 0.0;
      } else if (itemCategory == 'college_items' && courseLabel != null) {
        pricePerPiece = _collegeStockQuantities[courseLabel]?[itemLabel]?['sizes']?[item['itemSize']]?['price'] ?? 0.0;
      } else if (itemCategory == 'Merch & Accessories') {
        pricePerPiece = _merchStockQuantities[itemLabel]?['sizes']?[item['itemSize']]?['price'] ?? 0.0;
      }

      double total = pricePerPiece * quantity; 

      return {
        'itemLabel': itemLabel,
        'itemSize': item['itemSize'],
        'quantity': quantity,
        'pricePerPiece': pricePerPiece,
        'total': total,  
        'courseLabel': courseLabel,
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