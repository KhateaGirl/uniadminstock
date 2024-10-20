import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKeyCredentials = GlobalKey<FormState>();
  final _formKeyInventory = GlobalKey<FormState>();

  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  TextEditingController _itemLabelController = TextEditingController();
  TextEditingController _itemPriceController = TextEditingController();
  TextEditingController _itemSizeController = TextEditingController();
  TextEditingController _itemQuantityController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImageFile;
  File? _selectedItemImageFile;
  Uint8List? _webImage;
  Uint8List? _webItemImage;
  final picker = ImagePicker();
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  String? _selectedAnnouncement;
  List<String> _announcementOptions = ["Announcement 1", "Announcement 2", "Announcement 3"];

  String? _selectedItemCategory;
  String? _selectedCourseLabel;
  List<String> _categories = ["senior_high_items", "college_items"];
  List<String> _courseLabels = ["BACOMM", "HRM & Culinary", "IT&CPE", "Tourism"];

  @override
  void initState() {
    super.initState();
  }

  Future<void> updateAdminCredentials() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    if (_formKeyCredentials.currentState?.validate() == true) {
      try {
        // Placeholder for Admin Credentials Update Logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Credentials updated successfully!")),
        );
      } catch (e) {
        print("Error updating credentials: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update credentials: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in the form correctly.")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage({bool forAnnouncement = true}) async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        Uint8List webFileBytes = await pickedFile.readAsBytes();
        setState(() {
          if (forAnnouncement) {
            _webImage = webFileBytes;
          } else {
            _webItemImage = webFileBytes;
          }
          _uploadStatus = "Image selected.";
        });
      } else {
        setState(() {
          if (forAnnouncement) {
            _selectedImageFile = File(pickedFile.path);
          } else {
            _selectedItemImageFile = File(pickedFile.path);
          }
          _uploadStatus = "Image selected.";
        });
      }
    } else {
      setState(() {
        _uploadStatus = "No image selected.";
      });
    }
  }

  Future<String> _uploadImageToStorage(String documentId, {bool forAnnouncement = true}) async {
    try {
      Uint8List? imageBytes = forAnnouncement ? _webImage : _webItemImage;
      File? imageFile = forAnnouncement ? _selectedImageFile : _selectedItemImageFile;

      // Determine the correct storage path based on `courseLabel`
      String storagePath;
      if (forAnnouncement) {
        storagePath = 'admin_images/$documentId/${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Define the folder path based on the selected course label or general path
        String courseLabelPath = _selectedCourseLabel ?? "General";
        storagePath = 'items/$courseLabelPath/${DateTime.now().millisecondsSinceEpoch}';
      }

      if (kIsWeb && imageBytes != null) {
        Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);

        UploadTask uploadTask = storageRef.putData(imageBytes);
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadStatus = "Uploading... ${(_uploadProgress * 100).toStringAsFixed(2)}%";
          });
        });

        TaskSnapshot taskSnapshot = await uploadTask;
        return await taskSnapshot.ref.getDownloadURL();
      } else if (imageFile != null) {
        Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);

        UploadTask uploadTask = storageRef.putFile(imageFile);
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadStatus = "Uploading... ${(_uploadProgress * 100).toStringAsFixed(2)}%";
          });
        });

        TaskSnapshot taskSnapshot = await uploadTask;
        return await taskSnapshot.ref.getDownloadURL();
      } else {
        throw 'No image selected';
      }
    } catch (e) {
      print("Error uploading image: $e");
      return '';
    }
  }

  Future<void> addNewItemToInventory() async {
    if (_formKeyInventory.currentState?.validate() == true) {
      try {
        String label = _itemLabelController.text;
        double price = double.parse(_itemPriceController.text);
        String size = _itemSizeController.text;
        int quantity = int.parse(_itemQuantityController.text);

        String category = _selectedItemCategory ?? "senior_high_items";
        String courseLabel = _selectedCourseLabel ?? "General";
        String documentPath;

        if (category == "college_items" && courseLabel.isNotEmpty) {
          documentPath = "Inventory_stock/$category/$courseLabel";
        } else {
          documentPath = "Inventory_stock/$category/Items";
        }

        String imageUrl = await _uploadImageToStorage("", forAnnouncement: false);

        Map<String, dynamic> itemData = {
          'label': label,
          'price': price,
          'sizes': {
            size: {
              'quantity': quantity,
              'price': price,
            }
          },
          'imagePath': imageUrl,
        };

        await FirebaseFirestore.instance.collection(documentPath).add(itemData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item added to inventory successfully!")),
        );

        _itemLabelController.clear();
        _itemPriceController.clear();
        _itemSizeController.clear();
        _itemQuantityController.clear();
        _selectedItemCategory = null;
        _selectedCourseLabel = null;
      } catch (e) {
        print("Error adding item to inventory: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add item to inventory: $e")),
        );
      }
    }
  }

  void _refreshUIAfterUpload() {
    setState(() {
      _selectedImageFile = null;
      _selectedItemImageFile = null;
      _webImage = null;
      _webItemImage = null;
      _selectedAnnouncement = null;
      _uploadStatus = "";
      _uploadProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Settings'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Text('Update Admin Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Form(
                key: _formKeyCredentials,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: 'Username'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a password' : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.update),
                      label: Text(_isLoading ? 'Updating...' : 'Update Credentials'),
                      onPressed: _isLoading ? null : updateAdminCredentials,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Divider(thickness: 2),
              SizedBox(height: 20),
              Text('Upload Announcement Image', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Select Announcement', border: OutlineInputBorder()),
                value: _selectedAnnouncement,
                items: _announcementOptions.map((option) {
                  return DropdownMenuItem(value: option, child: Text(option));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAnnouncement = value;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.attach_file),
                label: Text('Select Image for Announcement'),
                onPressed: () => _pickImage(forAnnouncement: true),
              ),
              if (_webImage != null) Image.memory(_webImage!, height: 150),
              if (_selectedImageFile != null) Image.file(_selectedImageFile!, height: 150),
              if (_uploadProgress > 0) LinearProgressIndicator(value: _uploadProgress),
              ElevatedButton.icon(
                icon: Icon(Icons.cloud_upload),
                label: Text(_isLoading ? 'Uploading...' : 'Upload Image'),
                onPressed: _isLoading ? null : () => _uploadImageToStorage(""),
              ),
              Divider(thickness: 2),
              Text('Add New Item to Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
              Form(
                key: _formKeyInventory,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _itemLabelController,
                      decoration: InputDecoration(labelText: 'Item Label'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter an item label' : null,
                    ),
                    TextFormField(
                      controller: _itemPriceController,
                      decoration: InputDecoration(labelText: 'Item Price'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a price' : null,
                    ),
                    TextFormField(
                      controller: _itemSizeController,
                      decoration: InputDecoration(labelText: 'Item Size'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a size' : null,
                    ),
                    TextFormField(
                      controller: _itemQuantityController,
                      decoration: InputDecoration(labelText: 'Item Quantity'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a quantity' : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
                      value: _selectedItemCategory,
                      items: _categories.map((option) {
                        return DropdownMenuItem(value: option, child: Text(option));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedItemCategory = value;
                          if (value != "college_items") _selectedCourseLabel = null;
                        });
                      },
                    ),
                    if (_selectedItemCategory == "college_items")
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Select Course Label', border: OutlineInputBorder()),
                        value: _selectedCourseLabel,
                        items: _courseLabels.map((option) {
                          return DropdownMenuItem(value: option, child: Text(option));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCourseLabel = value;
                          });
                        },
                      ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.attach_file),
                      label: Text('Select Image for Item'),
                      onPressed: () => _pickImage(forAnnouncement: false),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Item'),
                      onPressed: addNewItemToInventory,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
