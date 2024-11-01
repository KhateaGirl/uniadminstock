import 'dart:io';
import 'package:flutter/foundation.dart';
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

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isAnnouncementImageUploading = false;
  bool _isItemImageUploading = false;

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
  List<String> _categories = ["senior_high_items", "college_items", "Merch & Accessories"];
  List<String> _courseLabels = ["BACOMM", "BSA & BSBA", "HRM & Culinary", "IT&CPE", "Tourism"];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  void _refreshPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => super.widget),
    );
  }

  Future<void> updateAdminCredentials() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    if (_formKeyCredentials.currentState?.validate() == true) {
      try {
        await firestore.collection('admin').doc('ZmjXRodEmi3LOaYA10tH').update({
          'Username': username,
          'Password': password,
        });

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

  Future<void> _updateAnnouncementImageUrl(String imageUrl) async {
    try {
      final querySnapshot = await firestore
          .collection('admin')
          .doc('ZmjXRodEmi3LOaYA10tH')
          .collection('announcements')
          .where('announcement_label', isEqualTo: _selectedAnnouncement)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final announcementDocId = querySnapshot.docs.first.id;

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

  Future<String> _uploadImageToStorage(String documentId, {bool forAnnouncement = true}) async {
    try {
      Uint8List? imageBytes = forAnnouncement ? _webImage : _webItemImage;

      String storagePath;
      if (forAnnouncement) {
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

        if (forAnnouncement && _selectedAnnouncement != null) {
          await _updateAnnouncementImageUrl(downloadUrl);
        }

        // Refresh the page after successful upload
        _refreshPage();

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

  Future<void> addOrUpdateItem() async {
    if (!_formKeyInventory.currentState!.validate()) return;

    String label = _itemLabelController.text.trim();
    double price = double.parse(_itemPriceController.text);
    String size = _itemSizeController.text.trim();
    int quantity = int.parse(_itemQuantityController.text);

    try {
      DocumentReference documentRef;

      String imageUrl = await _uploadImageToStorage(label, forAnnouncement: false);
      if (imageUrl.isEmpty) throw 'Image upload failed';

      if (_selectedItemCategory == "Merch & Accessories") {
        documentRef = firestore.collection("Inventory_stock").doc("Merch & Accessories");

        Map<String, dynamic> itemData = {
          "label": label,
          "price": price,
          "sizes": {
            size: {
              'quantity': quantity,
              'price': price,
            }
          },
          "imagePath": imageUrl,
        };

        await documentRef.update({
          label: itemData,
        });

      } else if (_selectedItemCategory == "senior_high_items") {
        documentRef = firestore.collection("Inventory_stock")
            .doc("senior_high_items").collection("Items").doc(label);

        Map<String, dynamic> itemData = {
          "label": label,
          "price": price,
          "sizes": {
            size: {
              'quantity': quantity,
              'price': price,
            }
          },
          "imagePath": imageUrl,
          "category": _selectedItemCategory,
        };

        await documentRef.set(itemData, SetOptions(merge: true));

      } else if (_selectedItemCategory == "college_items" && _selectedCourseLabel != null) {
        documentRef = firestore.collection("Inventory_stock")
            .doc("college_items").collection(_selectedCourseLabel!).doc(label);

        Map<String, dynamic> itemData = {
          "label": label,
          "price": price,
          "sizes": {
            size: {
              'quantity': quantity,
              'price': price,
            }
          },
          "imageUrl": imageUrl,
          "category": _selectedItemCategory,
        };

        await documentRef.set(itemData, SetOptions(merge: true));

      } else {
        throw 'Invalid category or course label';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Item added or updated successfully!")),
      );

      // Refresh the page after successful add/update
      _refreshPage();

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
      DocumentReference documentRef;

      if (_selectedItemCategory == "Merch & Accessories") {
        documentRef = firestore.collection("Inventory_stock").doc("Merch & Accessories");
        DocumentSnapshot documentSnapshot = await documentRef.get();
        Map<String, dynamic>? data = documentSnapshot.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey(label)) {
          await documentRef.update({
            label: FieldValue.delete(),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' deleted successfully from Merch & Accessories!")),
          );

          _refreshPage();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' not found in Merch & Accessories!")),
          );
        }

      } else if (_selectedItemCategory == "senior_high_items") {
        QuerySnapshot querySnapshot = await firestore
            .collection("Inventory_stock")
            .doc("senior_high_items")
            .collection("Items")
            .where("label", isEqualTo: label)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          for (QueryDocumentSnapshot doc in querySnapshot.docs) {
            await doc.reference.delete();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' deleted successfully from Senior High Items!")),
          );

          // Refresh the page after successful deletion
          _refreshPage();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' not found in Senior High Items!")),
          );
        }

      } else if (_selectedItemCategory == "college_items" && _selectedCourseLabel != null) {
        QuerySnapshot querySnapshot = await firestore
            .collection("Inventory_stock")
            .doc("college_items")
            .collection(_selectedCourseLabel!)
            .where("label", isEqualTo: label)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          for (QueryDocumentSnapshot doc in querySnapshot.docs) {
            await doc.reference.delete();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' deleted successfully from College Items!")),
          );

          // Refresh the page after successful deletion
          _refreshPage();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Item '$label' not found in College Items!")),
          );
        }

      } else {
        throw 'Invalid category or course label';
      }

      _itemLabelController.clear();

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
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible; // Toggle visibility
                            });
                          },
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
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
                    if (_webItemImage != null) Image.memory(_webItemImage!, height: 150),
                    // Preview of the selected item image
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.cloud_upload),
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