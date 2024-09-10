import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final Map<String, List<String>> _clothingTypes = {
    'Uniform': ['Senior High', 'College'],
    'Proware Shirt': ['Proware Shirt'],
    'Merch & Accessories': ['Merch & Accessories'],
  };

  final Map<String, List<String>> _shsUniforms = {
    'Senior High': [
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
    ]
  };

  final Map<String, List<String>> _collegeUniforms = {
    'College': [
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
    ]
  };

  final Map<String, Map<String, double>> _priceOptions = {
    // SHS Uniforms
    'BLOUSE WITH VEST': {
      'Small': 600.00,
      'Medium': 600.00,
      'Large': 600.00,
      'XL': 600.00,
      '2XL': 600.00,
      '3XL': 600.00,
      '4XL': 910.00,
      '5XL': 910.00,
      '6XL': 910.00,
      '7XL': 910.00,
    },
    'POLO WITH VEST': {
      'Small': 620.00,
      'Medium': 620.00,
      'Large': 620.00,
      'XL': 655.00,
      '2XL': 655.00,
      '3XL': 655.00,
      '4XL': 950.00,
      '5XL': 950.00,
      '6XL': 950.00,
      '7XL': 950.00,
    },
    'HM SKIRT': {
      'Small': 275.00,
      'Medium': 275.00,
      'Large': 275.00,
      'XL': 275.00,
      '2XL': 290.00,
      '3XL': 290.00,
      '5XL': 290.00,
    },
    'HS PANTS': {
      'Small': 415.00,
      'Medium': 415.00,
      'Large': 440.00,
      'XL': 440.00,
      '2XL': 440.00,
      '3XL': 470.00,
    },
    'HRM-CHECKERED PANTS FEMALE': {
      'Medium': 250.00,
      'Large': 250.00,
      'XL': 250.00,
      '2XL': 250.00,
      '3XL': 250.00,
    },
    'HRM-CHECKERED PANTS MALE': {
      'XS': 265.00,
      'Small': 265.00,
      'Medium': 265.00,
      'Large': 265.00,
      'XL': 265.00,
      '2XL': 265.00,
      '3XL': 265.00,
    },
    'HRM CHEF\'S POLO FEMALE': {
      'Small': 375.00,
      'Medium': 375.00,
      'Large': 375.00,
      'XL': 375.00,
      '2XL': 375.00,
      '3XL': 375.00,
    },
    'HRM CHEF\'S POLO MALE': {
      'XS': 400.00,
      'Small': 400.00,
      'Medium': 400.00,
      'Large': 400.00,
      'XL': 400.00,
      '2XL': 400.00,
      '3XL': 400.00,
    },
    'HS PE SHIRT': {
      'XS': 175.00,
      'Small': 175.00,
      'Medium': 175.00,
      'Large': 175.00,
      'XL': 175.00,
      '2XL': 175.00,
      '3XL': 200.00,
      '5XL': 230.00,
    },
    'HS PE PANTS': {
      'Small': 340.00,
      'Medium': 340.00,
      'Large': 340.00,
      'XL': 340.00,
      '2XL': 360.00,
      '3XL': 360.00,
      '5XL': 415.00,
    },

    // College Uniforms
    'IT 3/4 BLOUSE': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 380.00,
      '2XL': 380.00,
      '3XL': 380.00,
    },
    'IT 3/4 POLO': {
      'Small': 390.00,
      'Medium': 390.00,
      'Large': 390.00,
      'XL': 390.00,
      '2XL': 390.00,
      '3XL': 390.00,
    },
    'FEMALE BLAZER': {
      'Small': 720.00,
      'Medium': 720.00,
      'Large': 720.00,
      'XL': 840.00,
      '2XL': 840.00,
      '3XL': 840.00,
    },
    'MALE BLAZER': {
      'Small': 750.00,
      'Medium': 750.00,
      'Large': 750.00,
      'XL': 870.00,
      '2XL': 870.00,
      '3XL': 870.00,
    },
    'HRM BLOUSE': {
      'Small': 360.00,
      'Medium': 360.00,
      'Large': 360.00,
      'XL': 360.00,
      '2XL': 360.00,
      '3XL': 360.00,
    },
    'HRM POLO': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 380.00,
      '2XL': 380.00,
      '3XL': 380.00,
    },
    'HRM VEST FEMALE': {
      'Small': 350.00,
      'Medium': 350.00,
      'Large': 350.00,
      'XL': 350.00,
      '2XL': 350.00,
      '3XL': 350.00,
    },
    'HRM VEST MALE': {
      'Small': 380.00,
      'Medium': 380.00,
      'Large': 380.00,
      'XL': 390.00,
      '2XL': 405.00,
      '3XL': 405.00,
    },
    'RTW SKIRT': {
      'Small': 195.00,
      'Medium': 195.00,
      'Large': 195.00,
      'XL': 195.00,
      '2XL': 195.00,
      '3XL': 195.00,
    },
    'RTW FEMALE PANTS': {
      'Small': 442.00,
      'Medium': 442.00,
      'Large': 442.00,
      'XL': 442.00,
      '2XL': 442.00,
      '3XL': 442.00,
    },
    'RTW MALE PANTS': {
      'Small': 450.00,
      'Medium': 450.00,
      'Large': 450.00,
      'XL': 450.00,
      '2XL': 450.00,
      '3XL': 450.00,
    },
    'CHEF\'S POLO': {
      'XS': 360.00,
      'Small': 360.00,
      'Medium': 360.00,
      'Large': 360.00,
      'XL': 360.00,
      '2XL': 360.00,
      '3XL': 360.00,
    },
    'CHEF\'S PANTS': {
      'XS': 305.00,
      'Small': 305.00,
      'Medium': 305.00,
      'Large': 305.00,
      'XL': 305.00,
      '2XL': 305.00,
      '3XL': 305.00,
    },
    'TM FEMALE BLOUSE': {
      'Small': 365.00,
      'Medium': 365.00,
      'Large': 365.00,
      'XL': 365.00,
      '3XL': 365.00,
    },
    'TM FEMALE BLAZER': {
      'Small': 750.00,
      'Medium': 750.00,
      'Large': 750.00,
      'XL': 750.00,
      '3XL': 750.00,
    },
    'TM SKIRT': {
      'Small': 240.00,
      'Medium': 240.00,
      'Large': 240.00,
      'XL': 240.00,
      '3XL': 240.00,
    },
    'TM MALE POLO': {
      'Small': 375.00,
      'Medium': 375.00,
      'Large': 375.00,
      'XL': 375.00,
    },
    'TM MALE BLAZER': {
      'Small': 780.00,
      'Medium': 780.00,
      'Large': 780.00,
      'XL': 780.00,
    },
    'TM CLOTH PANTS': {
      'M 1yard': 330.00,
      'XL 1.5yard': 345.00,
      '3XL 2yard': 390.00,
    },
    'BM/AB COMM BLOUSE': {
      'Small': 365.00,
      'Medium': 365.00,
      'Large': 365.00,
      'XL': 365.00,
      '2XL': 365.00,
      '3XL': 365.00,
    },
    'BM/AB COMM POLO': {
      'Small': 395.00,
      'Medium': 395.00,
      'Large': 395.00,
      'XL': 395.00,
      '2XL': 395.00,
      '3XL': 395.00,
    },
    'PE SHIRT': {
      'XS': 175.00,
      'Small': 175.00,
      'Medium': 175.00,
      'Large': 175.00,
      'XL': 175.00,
      '2XL': 175.00,
      '3XL': 175.00,
      '5XL': 195.00,
    },
    'PE PANTS': {
      'XS': 310.00,
      'Small': 310.00,
      'Medium': 310.00,
      'Large': 310.00,
      'XL': 310.00,
      '2XL': 310.00,
      '3XL': 310.00,
      '5XL': 310.00,
    },
    'WASHDAY SHIRT': {
      'Small': 220.00,
      'Medium': 220.00,
      'Large': 220.00,
      'XL': 220.00,
      '2XL': 220.00,
      '3XL': 220.00,
      '5XL': 245.00,
    },
    'NSTP SHIRT': {
      'XS': 210.00,
      'Small': 210.00,
      'Medium': 210.00,
      'Large': 210.00,
      'XL': 210.00,
      '2XL': 230.00,
      '3XL': 230.00,
      '5XL': 250.00,
    },
    'NECKTIE': {
      'AB/COMM': 125.00,
      'BM': 125.00,
      'TM': 140.00,
      'CRIM': 130.00,
    },
    'SCARF': {
      'AB/COMM': 70.00,
      'BM': 70.00,
      'TM': 70.00,
    },
    'FABRIC SPECIAL SIZE': {
      'CHEF\'S PANTS FABRIC 2.5 yards': 400.00,
      'CHEF\'S POLO FABRIC 2.5 yards': 470.00,
      'HRM FABRIC 3 yards': 410.00,
      'HRM VEST FABRIC 2.5 yards': 300.00,
      'IT FABRIC 2.5 yards': 380.00,
      'ABCOMM/BM FABRIC 2.5 yards': 400.00,
      'PANTS FABRIC 2.5 yards': 260.00,
      'BLAZER FABRIC 2.75 yards': 740.00,
      'TOURISM BLAZER FABRIC 2.5 yards': 400.00,
      'TOURISM PANTS FABRIC 2.5 yards': 400.00,
      'TOURISM POLO FABRIC 2.5 yards': 295.00,
    },
  };

    List<DropdownMenuItem<String>> _getSizeOptions(String subcategory) {
    List<String> sizes = _priceOptions[subcategory]?.keys.toList() ?? [];
    return [
      DropdownMenuItem<String>(
        value: 'None',
        child: Text('None'),
      ),
      ...sizes.map((size) {
        double? price = _priceOptions[subcategory]?[size];
        return DropdownMenuItem<String>(
          value: size,
          child: Text('$size - ₱${price?.toStringAsFixed(2) ?? ""}'),
        );
      }).toList(),
    ];
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      double totalPrice = 0.0;
      List<String> selectedItems = [];

      _selectedSizes.forEach((subcategory, size) {
        if (size != null && size != 'None') {
          double? price = _priceOptions[subcategory]?[size];
          int quantity = _selectedQuantities[subcategory] ?? 0;
          double itemTotal = (price ?? 0) * quantity;
          totalPrice += itemTotal;
          selectedItems.add('$subcategory ($size) x$quantity = ₱${itemTotal.toStringAsFixed(2)}');
        }
      });

      Get.snackbar(
        'Success',
        'Order submitted successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('ORDER SLIP',
            style: TextStyle(fontWeight: FontWeight.bold),),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Name: ${_nameController.text}'),
                Text('Student Number: ${_studentNumberController.text}'),
                SizedBox(height: 32),
                Text('Selected Items:'),
                ...selectedItems.map((item) => Text(item)).toList(),
                SizedBox(height: 32),
                Text('Total Price: ₱${totalPrice.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold),),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _nameController.clear();
                    _studentNumberController.clear();
                    _selectedSizes.clear();
                    _selectedQuantities.clear();
                    _selectedCategories.clear();
                    _selectedCategory = null;
                    _selectedSubcategory = null;
                  });
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    }
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
                  items: _clothingTypes.keys.map((category) {
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
                    items: _clothingTypes[_selectedCategory!]!.map((subcategory) {
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 3.5,
                        ),
                        itemCount: (_shsUniforms[_selectedSubcategory!] ?? _collegeUniforms[_selectedSubcategory!] ?? []).length,
                        itemBuilder: (context, index) {
                          String item = (_shsUniforms[_selectedSubcategory!] ?? _collegeUniforms[_selectedSubcategory!] ?? [])[index];
                          return Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: 
                                Text(item,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                color: active,
                                fontSize: 18),),
                                ),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove, color: Colors.black,),
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
                                    style: TextStyle(fontWeight: FontWeight.bold,
                                    color: active)),
                                    IconButton(
                                      icon: Icon(Icons.add, color: Colors.black,),
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
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                          backgroundColor: active,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16)
                    ),
                    child: Text('Submit Order',
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