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
        String? imagePath = data['imagePath'] as String?; // Senior High uses imagePath
        String label = data['label'] != null ? data['label'] as String : doc.id; // Use document ID if label is missing

        // Process stock data
        data.forEach((key, value) {
          if (value is Map && value.containsKey('quantity') && value.containsKey('price')) {
            stockData[key] = {
              'quantity': value['quantity'],
              'price': value['price'],
            };
          }
        });

        // Store processed item data
        seniorHighData[doc.id] = {
          'stock': stockData,
          'imagePath': imagePath ?? '', // Use empty string as fallback for imagePath
          'label': label,
          'price': data['price'] ?? 0.0, // Set price to 0.0 if missing
        };
        print('Fetched Senior High item: ${doc.id}, Label: $label, ImagePath: $imagePath');

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
          String? imageUrl = data['imageUrl'] as String?; // College uses imageUrl
          String label = data['label'] != null ? data['label'] as String : doc.id; // Use document ID if label is missing
          double price = data['price'] != null ? data['price'] as double : 0.0; // Set default price to 0 if missing

          courseItems[doc.id] = {
            'label': label,
            'imageUrl': imageUrl ?? '', // Use empty string as fallback for imageUrl
            'price': price,
          };
        });

        // Add course data to collegeData
        collegeData[courseLabel] = courseItems;
        print('Finished fetching items for course label: $courseLabel.');

      }

      // Update the state
      setState(() {
        _seniorHighStockQuantities = seniorHighData;
        _collegeStockQuantities = collegeData;
        _loading = false;
      });
    } catch (e) {
      print('Failed to fetch inventory data: $e');
    }
  }

  Widget _buildItemCard(String itemKey, Map<String, dynamic> itemData) {
    String? imagePath = itemData['imagePath']; // Use imagePath for Senior High
    String label = itemData['label'];
    double price = itemData['price'];

    print('Loading image for $label with URL: $imagePath'); // Added print for debugging

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Check if imagePath is not null and not an empty string
          if (imagePath != null && imagePath.isNotEmpty)
            Image.network(
              imagePath,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Failed to load image for $label with error: $error'); // Log the error
                return Column(
                  children: [
                    Icon(Icons.broken_image, size: 50), // Better error icon
                    Text('Image Not Available', style: TextStyle(fontSize: 12)),
                  ],
                );
              },
            )
          else
          // Fallback when no imagePath is provided
            Column(
              children: [
                Icon(Icons.image_not_supported, size: 50), // Fallback icon
                Text('No Image Provided', style: TextStyle(fontSize: 12)),
              ],
            ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '₱$price',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
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
            // Senior High Inventory
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
                return _buildItemCard(itemKey, itemData); // Add 'true' as the third argument
              }).toList(),
            ),
            SizedBox(height: 16),

            // College Inventory with Dropdown
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
                  Map<String, dynamic> itemData =
                  _collegeStockQuantities[_selectedCourseLabel!]![itemKey];
                  return _buildItemCard(itemKey, itemData);
                }).toList(),
              ),
            if (_selectedCourseLabel == null)
              Center(child: Text('Please select a course label to view items')),
          ],
        ),
      ),
    );
  }
}
