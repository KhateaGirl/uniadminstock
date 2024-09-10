import 'package:flutter/material.dart';
import 'package:unistock/constants/style.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  Map<String, Map<String, int>> _stockQuantities = {
    // Senior High Items
    'BLOUSE WITH VEST': {'Small': 5, 'Medium': 3, 'Large': 2},
    'POLO WITH VEST': {'Small': 10, 'Medium': 5, 'Large': 5},
    'HM SKIRT': {'Small': 8, 'Medium': 5, 'Large': 2},
    'HS PANTS': {'Small': 10, 'Medium': 10, 'Large': 5},
    'HRM-CHECKERED PANTS FEMALE': {'Small': 5, 'Medium': 10, 'Large': 15},
    'HRM CHEF\'S POLO FEMALE': {'Small': 8, 'Medium': 6, 'Large': 4},
    'HRM CHEF\'S POLO MALE': {'Small': 7, 'Medium': 10, 'Large': 5},
    'HRM-CHECKERED PANTS MALE': {'Small': 5, 'Medium': 12, 'Large': 10},
    'HS PE SHIRT': {'Small': 6, 'Medium': 4, 'Large': 2},
    'HS PE PANTS': {'Small': 10, 'Medium': 5, 'Large': 4},
    // College Items
    'IT 3/4 BLOUSE': {'Small': 5, 'Medium': 5, 'Large': 4},
    'IT 3/4 POLO': {'Small': 8, 'Medium': 5, 'Large': 3},
    'FEMALE BLAZER': {'Small': 4, 'Medium': 2, 'Large': 2},
    'MALE BLAZER': {'Small': 5, 'Medium': 3, 'Large': 2},
    'HRM BLOUSE': {'Small': 6, 'Medium': 4, 'Large': 2},
    'HRM POLO': {'Small': 6, 'Medium': 4, 'Large': 2},
    'HRM VEST FEMALE': {'Small': 2, 'Medium': 2, 'Large': 2},
    'HRM VEST MALE': {'Small': 3, 'Medium': 3, 'Large': 2},
    'RTW SKIRT': {'Small': 10, 'Medium': 6, 'Large': 4},
    'RTW FEMALE PANTS': {'Small': 12, 'Medium': 8, 'Large': 5},
    'RTW MALE PANTS': {'Small': 15, 'Medium': 10, 'Large': 5},
    'CHEF\'S POLO': {'Small': 9, 'Medium': 6, 'Large': 3},
    'CHEF\'S PANTS': {'Small': 11, 'Medium': 7, 'Large': 4},
    'TM FEMALE BLOUSE': {'Small': 7, 'Medium': 5, 'Large': 3},
    'TM FEMALE BLAZER': {'Small': 5, 'Medium': 3, 'Large': 2},
    'TM SKIRT': {'Small': 10, 'Medium': 6, 'Large': 4},
    'TM MALE POLO': {'Small': 13, 'Medium': 8, 'Large': 4},
    'TM MALE BLAZER': {'Small': 4, 'Medium': 3, 'Large': 1},
    'BM/AB COMM BLOUSE': {'Small': 7, 'Medium': 5, 'Large': 3},
    'BM/AB COMM POLO': {'Small': 8, 'Medium': 5, 'Large': 3},
    'PE SHIRT': {'Small': 6, 'Medium': 4, 'Large': 2},
    'PE PANTS': {'Small': 10, 'Medium': 5, 'Large': 4},
    'WASHDAY SHIRT': {'Small': 5, 'Medium': 3, 'Large': 2},
    'NSTP SHIRT': {'Small': 6, 'Medium': 4, 'Large': 2},
    'NECKTIE': {'AB/COMM': 5, 'BM': 6, 'TM': 5, 'CRIM': 7,},
    'SCARF': {'AB/COMM': 30, 'BM': 6, 'TM': 5},
    'FABRIC SPECIAL SIZE': {'CHEF\'S PANTS FABRIC 2.5 yards': 8},
  };

  bool _showConfirmButton = false;

  List<String> _getItems() {
    return [
      // Senior High Items
      'BLOUSE WITH VEST',
      'POLO WITH VEST',
      'HM SKIRT',
      'HS PANTS',
      'HRM-CHECKERED PANTS FEMALE',
      'HRM CHEF\'S POLO FEMALE',
      'HRM CHEF\'S POLO MALE',
      'HRM-CHECKERED PANTS MALE',
      'HS PE SHIRT',
      'HS PE PANTS',
      // College Items
      'IT 3/4 BLOUSE',
      'IT 3/4 POLO',
      'FEMALE BLAZER',
      'MALE BLAZER',
      'HRM BLOUSE',
      'HRM POLO',
      'HRM VEST FEMALE',
      'HRM VEST MALE',
      'RTW SKIRT',
      'RTW FEMALE PANTS',
      'RTW MALE PANTS',
      'CHEF\'S POLO',
      'CHEF\'S PANTS',
      'TM FEMALE BLOUSE',
      'TM FEMALE BLAZER',
      'TM SKIRT',
      'TM MALE POLO',
      'TM MALE BLAZER',
      'BM/AB COMM BLOUSE',
      'BM/AB COMM POLO',
      'PE SHIRT',
      'PE PANTS',
      'WASHDAY SHIRT',
      'NSTP SHIRT',
      'NECKTIE',
      'SCARF',
      'FABRIC SPECIAL SIZE',
    ];
  }

  List<String> _getSizeOptions(String item) {
    switch (item) {
      case 'CHEF\'S POLO':
      case 'CHEF\'S PANTS':
      case 'NSTP SHIRT':
      case 'HS PE SHIRT':
        return ['XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL'];
      case 'TM FEMALE BLOUSE':
      case 'TM FEMALE BLAZER':
      case 'TM SKIRT':
        return ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL'];
      case 'TM MALE POLO':
      case 'TM MALE BLAZER':
        return ['Small', 'Medium', 'Large', 'XL'];
      case 'PE SHIRT':
      case 'PE PANTS':
      case 'WASHDAY SHIRT':
        return ['XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL'];
      case 'NECKTIE':
        return ['AB/COMM', 'BM', 'TM', 'CRIM'];
      case 'SCARF':
        return ['AB/COMM', 'BM', 'TM'];
      case 'FABRIC SPECIAL SIZE':
        return ['CHEF\'S PANTS FABRIC 2.5 yards',
                'CHEF\'S POLO FABRIC 2.5 yards',
                'HRM FABRIC 3 yards',
                'HRM VEST FABRIC 2.5 yards',
                'IT FABRIC 2.5 yards',
                'ABCOMM/BM FABRIC 2.5 yards',
                'PANTS FABRIC 2.5 yards',
                'BLAZER FABRIC 2.75 yards',
                'TOURISM BLAZER FABRIC 2.5 yards',
                'TOURISM PANTS FABRIC 2.5 yards',
                'TOURISM POLO FABRIC 2.5 yards'];
      case 'BLOUSE WITH VEST':
      case 'POLO WITH VEST':
        return ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL', '7XL'];
      case 'HM SKIRT':
        return ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL', '4XL', '5XL'];
      case 'HS PANTS':
        return ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL'];
      case 'HRM-CHECKERED PANTS FEMALE':
        return ['Medium', 'Large', 'XL', '2XL', '3XL'];
      case 'HRM CHEF\'S POLO FEMALE':
      case 'HRM CHEF\'S POLO MALE':
      case 'HRM-CHECKERED PANTS MALE':
        return ['XS', 'Small', 'Medium', 'Large', 'XL', '2XL', '3XL'];
      default:
        return ['Small', 'Medium', 'Large', 'XL', '2XL', '3XL'];
    }
  }

  Widget _buildItemCard(String item) {
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
          SizedBox(height: 8),
          ..._getSizeOptions(item).map((size) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  child: Text('$size:'),
                ),
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if ((_stockQuantities[item]?[size] ?? 0) > 0) {
                        _stockQuantities[item]?[size] = _stockQuantities[item]![size]! - 1;
                        _showConfirmButton = true;
                      }
                    });
                  },
                ),
                Container(
                  width: 18,
                  child: Text('${_stockQuantities[item]?[size] ?? 0}',
                  style: TextStyle(fontWeight: FontWeight.bold,
                  color: active)),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _stockQuantities[item]?[size] = (_stockQuantities[item]?[size] ?? 0) + 1;
                      _showConfirmButton = true;
                    });
                  },
                ),
              ],
            );
          }).toList(),
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
                    children: _getItems().take(10).map((item) {
                      return _buildItemCard(item);
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
                    children: _getItems().skip(10).map((item) {
                      return _buildItemCard(item);
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
                    backgroundColor: Colors.blue, // Replace with your desired color
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
