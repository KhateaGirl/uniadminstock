import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unistock/constants/InventoryData.dart';
import 'package:unistock/constants/style.dart';

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
  final Map<String, String> _selectedCategories = {};
  String? _selectedCategory;
  String? _selectedSubcategory;

  // Create instance of InventoryData class
  final InventoryData _inventoryData = InventoryData();

  List<DropdownMenuItem<String>> _getSizeOptions(String subcategory) {
    List<String> sizes = _inventoryData.getPriceOptions(subcategory)?.keys.toList() ?? [];
    return [
      DropdownMenuItem<String>(
        value: 'None',
        child: Text('None'),
      ),
      ...sizes.map((size) {
        double? price = _inventoryData.getPriceOptions(subcategory)?[size];
        return DropdownMenuItem<String>(
          value: size,
          child: Text('$size - ₱${price?.toStringAsFixed(2) ?? ""}'),
        );
      }).toList(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  'Walk-In Order Form',
                  style: GoogleFonts.roboto(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
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
                      _selectedCategories.clear(); // Clear previous selections
                    });
                  },
                  items: _inventoryData.getCategories().map((category) {
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
                        _selectedCategories[_selectedSubcategory ?? ''] = '';
                      });
                    },
                    items: _inventoryData.getSubcategories(_selectedCategory!)!.map((subcategory) {
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
                if (_selectedSubcategory != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'ITEMS IN ${_selectedSubcategory!.toUpperCase()}',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 4, // Adjust this for better layout
                        ),
                        itemCount: (_inventoryData.getUniformsByCategory(_selectedSubcategory!) ?? []).length,
                        itemBuilder: (context, index) {
                          String item = (_inventoryData.getUniformsByCategory(_selectedSubcategory!) ?? [])[index];
                          return Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Label for the item
                                Text(
                                  item,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: active,
                                    fontSize: 14, // Adjust font size for better fit
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                // Size dropdown
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
                                  items: _getSizeOptions(item),
                                ),
                                SizedBox(height: 4),
                                // Quantity controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove,
                                        color: Colors.black,
                                      ),
                                      onPressed: () {
                                        int quantity = _selectedQuantities[item] ?? 0;
                                        if (quantity > 0) {
                                          setState(() {
                                            _selectedQuantities[item] = quantity - 1;
                                          });
                                        }
                                      },
                                    ),
                                    Text('${_selectedQuantities[item] ?? 0}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: active)),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color: Colors.black,
                                      ),
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
                  onPressed: () {
                    // Submit action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    'Submit Order',
                    style: TextStyle(color: Colors.yellow),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
