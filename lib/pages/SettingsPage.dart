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
  List<String> _categories = ["senior_high_items", "college_items", "Merch & Accessories"];
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
      if (forAnnouncement) {
        // Use exact path for the announcement
        storagePath = 'admin_images/Announcements/ZmjXRodEmi3LOaYA10tH/${DateTime.now().millisecondsSinceEpoch}.png';
      } else if (_selectedItemCategory == "Merch & Accessories") {
        storagePath = 'merch_images/${documentId}_${DateTime.now().millisecondsSinceEpoch}.png';
      } else if (_selectedItemCategory == "senior_high_items") {
        storagePath = 'images/${documentId}_${DateTime.now().millisecondsSinceEpoch}.png';
      } else if (_selectedItemCategory == "college_items" && _selectedCourseLabel != null) {
        storagePath = 'items/${_selectedCourseLabel}/${DateTime.now().millisecondsSinceEpoch}.png';
      } else {
        throw 'Invalid storage path configuration';
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

        final metadata = SettableMetadata(contentType: 'image/jpg');
        UploadTask uploadTask = storageRef.putData(imageBytes, metadata);

        TaskSnapshot taskSnapshot = await uploadTask;
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();

        // If it's an announcement, update Firestore with the new image URL
        if (forAnnouncement && _selectedAnnouncement != null) {
          await _updateAnnouncementImageUrl(downloadUrl);
        }

        return downloadUrl;
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

  Future<void> _updateAnnouncementImageUrl(String imageUrl) async {
    try {
      // First, find the document ID that matches the selected announcement label
      final querySnapshot = await firestore
          .collection('admin')
          .doc('ZmjXRodEmi3LOaYA10tH')
          .collection('announcements')
          .where('announcement_label', isEqualTo: _selectedAnnouncement) // Assuming _selectedAnnouncement is the label
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final announcementDocId = querySnapshot.docs.first.id;

        // Now, use the document ID to update the image URL
        final announcementDocRef = firestore
            .collection('admin')
            .doc('ZmjXRodEmi3LOaYA10tH')
            .collection('announcements')
            .doc(announcementDocId);

        await announcementDocRef.update({
          'image_url': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Announcement image updated successfully!")),
        );
      } else {
        print("No matching document found for label: $_selectedAnnouncement");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to find announcement document.")),
        );
      }
    } catch (e) {
      print("Error updating Firestore with image URL: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update announcement image URL.")),
      );
    }
  }

  Future<void> addOrUpdateItem() async {
    if (!_formKeyInventory.currentState!.validate()) return;

    String label = _itemLabelController.text.trim();
    double price = double.parse(_itemPriceController.text);
    String size = _itemSizeController.text.trim();
    int quantity = int.parse(_itemQuantityController.text);

    try {
      // Access the "Merch & Accessories" document directly
      DocumentReference documentRef = firestore
          .collection("Inventory_stock")
          .doc("Merch & Accessories");

      // Query to check if the item with the specified label exists
      DocumentSnapshot merchSnapshot = await documentRef.get();
      Map<String, dynamic>? merchData = merchSnapshot.data() as Map<String, dynamic>?;

      if (merchData != null && merchData.containsKey(label)) {
        // Update the existing item if it exists
        Map<String, dynamic> existingItem = merchData[label];
        String imageUrl = _webItemImage != null
            ? await _uploadImageToStorage(label, forAnnouncement: false)
            : existingItem['imagePath'];

        await documentRef.update({
          "$label.price": price,
          "$label.sizes.$size.quantity": quantity,
          "$label.sizes.$size.price": price,
          "$label.imagePath": imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item updated successfully!")),
        );
      } else {
        // Add new item if it doesn't exist
        String imageUrl = await _uploadImageToStorage(label, forAnnouncement: false);

        await documentRef.update({
          label: {
            'label': label,
            'price': price,
            'sizes': {
              size: {
                'quantity': quantity,
                'price': price,
              }
            },
            'imagePath': imageUrl,
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item added successfully!")),
        );
      }

      // Clear input fields and reset selection
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

  Future<void> deleteItem() async {
    String label = _itemLabelController.text.trim();

    try {
      // Reference the "Merch & Accessories" document directly
      DocumentReference documentRef = firestore
          .collection("Inventory_stock")
          .doc("Merch & Accessories");

      // Check if the item exists within the document
      DocumentSnapshot merchSnapshot = await documentRef.get();
      Map<String, dynamic>? merchData = merchSnapshot.data() as Map<String, dynamic>?;

      if (merchData != null && merchData.containsKey(label)) {
        // If the item with the given label exists, delete it
        await documentRef.update({
          label: FieldValue.delete(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item deleted successfully!")),
        );

        // Clear input fields
        _itemLabelController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item not found with label: $label")),
        );
      }
    } catch (e) {
      print("Error deleting item: $e");
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