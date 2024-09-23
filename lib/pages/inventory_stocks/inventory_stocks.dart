import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unistock/constants/style.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _seniorHighStockQuantities = {};
  Map<String, Map<String, dynamic>> _collegeStockQuantities = {};
  bool _loading = true;
  bool _showConfirmButton = false;

  final List<String> _allowedCustomSizes = ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'];
  final List<String> _excludedItems = ['Necktie', 'Scarf'];

  @override
  void initState() {
    super.initState();
    _fetchStockData();
  }

  Future<void> _fetchStockData() async {
    try {
      QuerySnapshot seniorHighSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('Senior_high_items')
          .collection('Items')
          .get();

      QuerySnapshot collegeSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('College_items')
          .collection('Items')
          .get();

      Map<String, Map<String, dynamic>> seniorHighData = {};
      Map<String, Map<String, dynamic>> collegeData = {};

      seniorHighSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> stockData = {};
        String? imageUrl;

        data.forEach((key, value) {
          if (value is Map && value.containsKey('quantity') && value.containsKey('price')) {
            stockData[key] = {
              'quantity': value['quantity'],
              'price': value['price'],
            };
          } else if (key == 'image_url') {
            imageUrl = value as String;
          }
        });

        seniorHighData[doc.id] = {
          'stock': stockData,
          'image_url': imageUrl,
        };
      });

      collegeSnapshot.docs.forEach((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> stockData = {};
        String? imageUrl;

        data.forEach((key, value) {
          if (value is Map && value.containsKey('quantity') && value.containsKey('price')) {
            stockData[key] = {
              'quantity': value['quantity'],
              'price': value['price'],
            };
          } else if (key == 'image_url') {
            imageUrl = value as String;
          }
        });

        collegeData[doc.id] = {
          'stock': stockData,
          'image_url': imageUrl,
        };
      });

      setState(() {
        _seniorHighStockQuantities = seniorHighData;
        _collegeStockQuantities = collegeData;
        _loading = false;
      });
    } catch (e) {
      print('Failed to fetch inventory data: $e');
    }
  }

  Future<void> _addCustomSize(String item, String customSize, int quantity, double price, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';

      DocumentSnapshot documentSnapshot = await firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(item)
          .get();

      Map<String, dynamic>? currentItemData = documentSnapshot.data() as Map<String, dynamic>?;

      int existingQuantity = currentItemData?[customSize]?['quantity'] ?? 0;

      int newQuantity = existingQuantity + quantity;

      double newPrice = price;

      await firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(item)
          .update({
        customSize: {
          'quantity': newQuantity,
          'price': newPrice,
        }
      });

      setState(() {
        if (isSeniorHigh) {
          _seniorHighStockQuantities[item]?['stock']?[customSize] = {
            'quantity': newQuantity,
            'price': newPrice
          };
        } else {
          _collegeStockQuantities[item]?['stock']?[customSize] = {
            'quantity': newQuantity,
            'price': newPrice
          };
        }
        _showConfirmButton = true;
      });
    } catch (e) {
      print('Failed to add custom size: $e');
    }
  }

  Future<void> _incrementStock(String item, String size, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';
      int currentStock = isSeniorHigh
          ? (_seniorHighStockQuantities[item]?['stock']?[size]['quantity'] ?? 0)
          : (_collegeStockQuantities[item]?['stock']?[size]['quantity'] ?? 0);
      int newStock = currentStock + 1;

      await firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(item)
          .update({size: {'quantity': newStock}});

      setState(() {
        if (isSeniorHigh) {
          _seniorHighStockQuantities[item]?['stock']?[size]['quantity'] = newStock;
        } else {
          _collegeStockQuantities[item]?['stock']?[size]['quantity'] = newStock;
        }
        _showConfirmButton = true;
      });
    } catch (e) {
      print('Failed to update stock: $e');
    }
  }

  Future<void> _decrementStock(String item, String size, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';
      int currentStock = isSeniorHigh
          ? (_seniorHighStockQuantities[item]?['stock']?[size]['quantity'] ?? 0)
          : (_collegeStockQuantities[item]?['stock']?[size]['quantity'] ?? 0);
      if (currentStock > 0) {
        int newStock = currentStock - 1;

        await firestore
            .collection('Inventory_stock')
            .doc(collection)
            .collection('Items')
            .doc(item)
            .update({size: {'quantity': newStock}});

        setState(() {
          if (isSeniorHigh) {
            _seniorHighStockQuantities[item]?['stock']?[size]['quantity'] = newStock;
          } else {
            _collegeStockQuantities[item]?['stock']?[size]['quantity'] = newStock;
          }
          _showConfirmButton = true;
        });
      }
    } catch (e) {
      print('Failed to update stock: $e');
    }
  }

  void _showCustomSizeDialog(String item, bool isSeniorHigh) {
    String customSize = 'Small';
    int customQuantity = 1;
    double customPrice = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Custom Size'),
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
                    items: _allowedCustomSizes.map<DropdownMenuItem<String>>((String value) {
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
                      SizedBox(width: 10),
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
                      customPrice = double.parse(value);
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
                    _addCustomSize(item, customSize, customQuantity, customPrice, isSeniorHigh);
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

  Widget _buildItemCard(String item, bool isSeniorHigh) {
    Map<String, Map<String, dynamic>> stockQuantities = isSeniorHigh ? _seniorHighStockQuantities : _collegeStockQuantities;
    Map<String, dynamic>? stockData = stockQuantities[item]?['stock'] as Map<String, dynamic>?;
    String? imageUrl = stockQuantities[item]?['image_url'] as String?;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                } else {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.error);
              },
            ),
          SizedBox(height: 8),
          Text(
            item,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),

          if (stockData != null)
            ...stockData.keys.map((size) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      child: Text('$size:'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      _decrementStock(item, size, isSeniorHigh);
                    },
                  ),
                  Container(
                    width: 18,
                    child: Text(
                      '${stockData[size]?['quantity'] ?? 0}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: active),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      _incrementStock(item, size, isSeniorHigh);
                    },
                  ),
                  Container(
                    width: 50,
                    child: Text(
                      '\₱${stockData[size]?['price'] ?? 0}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ],
              );
            }).toList(),

          SizedBox(height: 8),
          if (!_excludedItems.contains(item))
            ElevatedButton(
              onPressed: () {
                _showCustomSizeDialog(item, isSeniorHigh);
              },
              child: Text('Add Custom Size'),
            ),
        ],
      ),
    );
  }

  void _confirmChanges() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Changes'),
          content: Text('Are you sure you want to confirm these changes?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showConfirmButton = false;
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Confirm',
                style: TextStyle(color: Colors.yellow),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _seniorHighStockQuantities.keys.map((item) {
                      return _buildItemCard(item, true);
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'College Inventory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: _collegeStockQuantities.keys.map((item) {
                      return _buildItemCard(item, false);
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_showConfirmButton)
              Center(
                child: ElevatedButton(
                  onPressed: _confirmChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    'Confirm',
                    style: TextStyle(color: Colors.yellow),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
