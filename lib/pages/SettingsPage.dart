import 'dart:io';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  bool _isAnnouncementImageUploading = false;
  bool _isItemImageUploading = false;

  File? _selectedImageFile; // Non-web file storage
  File? _selectedItemImageFile; // Non-web file storage
  Uint8List? _webImage; // Web image byte storage for announcement
  Uint8List? _webItemImage; // Web image byte storage for item

  final picker = ImagePicker();
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  String? _selectedAnnouncement;
  List<String> _announcementOptions = ["Announcement 1", "Announcement 2", "Announcement 3"];

  String? _selectedItemCategory;
  String? _selectedCourseLabel;
  List<String> _categories = ["senior_high_items", "college_items"];
  List<String> _courseLabels = ["BACOMM", "HRM & Culinary", "IT&CPE", "Tourism"];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  // Update admin credentials
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

      String storagePath;
      if (!forAnnouncement && _selectedItemCategory == "senior_high_items") {
        storagePath = 'images/${documentId}_${DateTime.now().millisecondsSinceEpoch}.png';
      } else {
        storagePath = forAnnouncement
            ? 'admin_images/$documentId/${DateTime.now().millisecondsSinceEpoch}'
            : 'items/${_selectedCourseLabel ?? "General"}/${DateTime.now().millisecondsSinceEpoch}';
      }

      if (imageBytes != null) {
        Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);

        setState(() {
          if (forAnnouncement) {
            _isAnnouncementImageUploading = true;
          } else {
            _isItemImageUploading = true;
          }
        });

        // Specify MIME type for the image
        final metadata = SettableMetadata(contentType: 'image/jpg');
        UploadTask uploadTask = storageRef.putData(imageBytes, metadata);

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
    } finally {
      setState(() {
        _isItemImageUploading = false;
        _isAnnouncementImageUploading = false;
      });
    }
  }


  Future<void> addOrUpdateItem() async {
    if (!_formKeyInventory.currentState!.validate()) return;

    String label = _itemLabelController.text;
    double price = double.parse(_itemPriceController.text);
    String size = _itemSizeController.text;
    int quantity = int.parse(_itemQuantityController.text);
    String category = _selectedItemCategory ?? "senior_high_items";
    String courseLabel = _selectedCourseLabel ?? "General";

    String collectionPath = category == "college_items"
        ? "Inventory_stock/$category/$courseLabel"
        : "Inventory_stock/$category/Items";

    try {
      QuerySnapshot querySnapshot = await firestore
          .collection(collectionPath)
          .where('label', isEqualTo: label)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot existingItem = querySnapshot.docs.first;
        String documentId = existingItem.id;

        String imageUrl = _webItemImage != null
            ? await _uploadImageToStorage(documentId, forAnnouncement: false)
            : existingItem['imagePath'];

        await existingItem.reference.update({
          'price': price,
          'sizes.$size': {
            'quantity': quantity,
            'price': price,
          },
          'imagePath': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item updated successfully!")),
        );
      } else {
        String documentId = firestore.collection(collectionPath).doc().id;
        String imageUrl = await _uploadImageToStorage(documentId, forAnnouncement: false);

        await firestore.collection(collectionPath).doc(documentId).set({
          'label': label,
          'price': price,
          'sizes': {
            size: {
              'quantity': quantity,
              'price': price,
            }
          },
          'imagePath': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item added successfully!")),
        );
      }

      _itemLabelController.clear();
      _itemPriceController.clear();
      _itemSizeController.clear();
      _itemQuantityController.clear();
      _selectedItemCategory = null;
      _selectedCourseLabel = null;
    } catch (e) {
      print("Error adding/updating item: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add/update item: $e")),
      );
    }
  }

  // Delete item
  Future<void> deleteItem() async {
    String label = _itemLabelController.text.trim();
    String category = _selectedItemCategory ?? "senior_high_items";
    String courseLabel = _selectedCourseLabel ?? "General";

    // Set collection path based on category
    String collectionPath;
    if (category == "college_items" && _selectedCourseLabel != null) {
      collectionPath = "Inventory_stock/$category/$courseLabel";
    } else if (category == "senior_high_items") {
      collectionPath = "Inventory_stock/$category/Items";
    } else {
      // Handle case if category or course label is not set correctly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a valid category and course label.")),
      );
      return;
    }

    try {
      // Query for the document based on the label
      QuerySnapshot querySnapshot = await firestore
          .collection(collectionPath)
          .where('label', isEqualTo: label)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot itemToDelete = querySnapshot.docs.first;
        await itemToDelete.reference.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item deleted successfully!")),
        );

        _itemLabelController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item not found with label: $label")),
        );
      }
    } catch (e) {
      print("Error deleting item in path $collectionPath: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete item: $e")),
      );
    }
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
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.cloud_upload),
                label: _isAnnouncementImageUploading ? Text('Uploading...') : Text('Upload Image'),
                onPressed: _isAnnouncementImageUploading ? null : () => _uploadImageToStorage("announcement", forAnnouncement: true),
              ),
              Divider(thickness: 2),
              Text('Add or Update Item', style: TextStyle(fontWeight: FontWeight.bold)),
              Form(
                key: _formKeyInventory,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _itemLabelController,
                      decoration: InputDecoration(labelText: 'Item Label'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter an item label' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _itemPriceController,
                      decoration: InputDecoration(labelText: 'Item Price'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a price' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _itemSizeController,
                      decoration: InputDecoration(labelText: 'Item Size'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a size' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _itemQuantityController,
                      decoration: InputDecoration(labelText: 'Item Quantity'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a quantity' : null,
                    ),
                    SizedBox(height: 20),
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
                    SizedBox(height: 20),
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
                    if (_selectedItemCategory == "college_items") SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.attach_file),
                      label: Text('Select Image for Item'),
                      onPressed: () => _pickImage(forAnnouncement: false),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: _isItemImageUploading ? Text('Uploading...') : Text('Add or Update Item'),
                      onPressed: _isItemImageUploading ? null : addOrUpdateItem,
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.delete),
                      label: Text('Delete Item'),
                      onPressed: deleteItem,
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
