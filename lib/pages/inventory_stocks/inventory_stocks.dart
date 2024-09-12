import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unistock/constants/style.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Map<String, int>> _seniorHighStockQuantities = {};
  Map<String, Map<String, int>> _collegeStockQuantities = {};
  bool _loading = true;
  bool _showConfirmButton = false;

  final List<String> _allowedCustomSizes = ['XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'];
  final List<String> _excludedItems = ['Necktie', 'Scarf']; // Items to exclude from adding custom sizes

  @override
  void initState() {
    super.initState();
    _fetchStockData();
  }

  // Fetch stock data from Firestore
  Future<void> _fetchStockData() async {
    try {
      // Fetch Senior High items
      QuerySnapshot seniorHighSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('Senior_high_items')
          .collection('Items')
          .get();

      // Fetch College items
      QuerySnapshot collegeSnapshot = await firestore
          .collection('Inventory_stock')
          .doc('College_items')
          .collection('Items')
          .get();

      Map<String, Map<String, int>> seniorHighData = {};
      Map<String, Map<String, int>> collegeData = {};

      // Process Senior High items
      seniorHighSnapshot.docs.forEach((doc) {
        seniorHighData[doc.id] = Map<String, int>.from(doc.data() as Map);
      });

      // Process College items
      collegeSnapshot.docs.forEach((doc) {
        collegeData[doc.id] = Map<String, int>.from(doc.data() as Map);
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

  // Function to increment stock quantity
  Future<void> _incrementStock(String item, String size, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';
      int currentStock = isSeniorHigh
          ? (_seniorHighStockQuantities[item]?[size] ?? 0)
          : (_collegeStockQuantities[item]?[size] ?? 0);
      int newStock = currentStock + 1;

      // Update the stock in Firestore
      await firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(item)
          .update({size: newStock});

      // Update the UI state
      setState(() {
        if (isSeniorHigh) {
          _seniorHighStockQuantities[item]?[size] = newStock;
        } else {
          _collegeStockQuantities[item]?[size] = newStock;
        }
        _showConfirmButton = true;
      });
    } catch (e) {
      print('Failed to update stock: $e');
    }
  }

  // Function to decrement stock quantity
  Future<void> _decrementStock(String item, String size, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';
      int currentStock = isSeniorHigh
          ? (_seniorHighStockQuantities[item]?[size] ?? 0)
          : (_collegeStockQuantities[item]?[size] ?? 0);
      if (currentStock > 0) {
        int newStock = currentStock - 1;

        // Update the stock in Firestore
        await firestore
            .collection('Inventory_stock')
            .doc(collection)
            .collection('Items')
            .doc(item)
            .update({size: newStock});

        // Update the UI state
        setState(() {
          if (isSeniorHigh) {
            _seniorHighStockQuantities[item]?[size] = newStock;
          } else {
            _collegeStockQuantities[item]?[size] = newStock;
          }
          _showConfirmButton = true;
        });
      }
    } catch (e) {
      print('Failed to update stock: $e');
    }
  }

  // Function to add custom size and quantity
  Future<void> _addCustomSize(String item, String customSize, int quantity, bool isSeniorHigh) async {
    try {
      String collection = isSeniorHigh ? 'Senior_high_items' : 'College_items';

      // Update Firestore with the custom size and quantity
      await firestore
          .collection('Inventory_stock')
          .doc(collection)
          .collection('Items')
          .doc(item)
          .update({customSize: quantity});

      // Update the UI state
      setState(() {
        if (isSeniorHigh) {
          _seniorHighStockQuantities[item]?[customSize] = quantity;
        } else {
          _collegeStockQuantities[item]?[customSize] = quantity;
        }
        _showConfirmButton = true;
      });
    } catch (e) {
      print('Failed to add custom size: $e');
    }
  }

  // Function to show a dialog for adding a custom size
  void _showCustomSizeDialog(String item, bool isSeniorHigh) {
    String customSize = 'XL';
    int customQuantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Custom Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown for custom size selection
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
                _addCustomSize(item, customSize, customQuantity, isSeniorHigh);
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Build item card with custom size option
  Widget _buildItemCard(String item, bool isSeniorHigh) {
    Map<String, Map<String, int>> stockQuantities =
    isSeniorHigh ? _seniorHighStockQuantities : _collegeStockQuantities;

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
            item,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          ...?stockQuantities[item]?.keys.map((size) {
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
                  child: Text('${stockQuantities[item]?[size] ?? 0}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: active)),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    _incrementStock(item, size, isSeniorHigh);
                  },
                ),
              ],
            );
          }).toList(),
          SizedBox(height: 8),
          // Add custom size button only if the item is not in the excluded list
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
                backgroundColor: Colors.blue, // Replace with your desired color
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
                  // Senior High Inventory Section
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

                  // College Inventory Section
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
