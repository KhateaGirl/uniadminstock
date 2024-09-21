import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:unistock/main.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKeyCredentials = GlobalKey<FormState>();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  File? _imageFile;
  Uint8List? _webImage;
  final picker = ImagePicker();
  String? _imageUrl;
  String? _selectedItem;
  List<String> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingImage();
    _fetchItems();
  }

  Future<void> updateAdminCredentials() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    if (_formKeyCredentials.currentState?.validate() == true) {
      try {
        UserController userController = Get.find();
        String documentId = userController.documentId.value;

        await FirebaseFirestore.instance.collection('admin').doc(documentId).update({
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

  Future<void> _fetchExistingImage() async {
    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('admin')
        .doc(documentId)
        .get();

    setState(() {
      _imageUrl = docSnapshot['image_url'];
    });
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Query items from College_items collection
      QuerySnapshot collegeItemsSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('College_items')
          .collection('Items')
          .get();

      // Query items from Senior_high_items collection
      QuerySnapshot seniorHighItemsSnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('Senior_high_items')
          .collection('Items')
          .get();

      // Merge both collections into a single list of items
      List<String> fetchedItems = [
        ...collegeItemsSnapshot.docs.map((doc) => doc.id).toList(),
        ...seniorHighItemsSnapshot.docs.map((doc) => doc.id).toList(),
      ];

      // Ensure no duplicate items
      List<String> uniqueItems = fetchedItems.toSet().toList(); // Removes duplicates

      setState(() {
        _items = uniqueItems;

        // Reset _selectedItem if it's not in the new list
        if (_selectedItem != null && !_items.contains(_selectedItem)) {
          _selectedItem = null;
        }
      });
    } catch (e) {
      print("Error fetching items: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        Uint8List webImageBytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = webImageBytes;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _uploadAndSaveImage() async {
    if (_isLoading) return; // Prevent multiple uploads
    setState(() {
      _isLoading = true;
    });

    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    try {
      // Upload the image to Firebase Storage
      String imageUrl = await _uploadImageToStorage(documentId);

      if (imageUrl.isNotEmpty) {
        // Save the image URL to Firestore for the selected item
        await _saveImageToFirestore(imageUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image.')),
        );
      }
    } catch (e) {
      print("Error uploading and saving image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading and saving image: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _uploadImageToStorage(String documentId) async {
    try {
      if (kIsWeb && _webImage != null) {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('admin_images/$documentId');

        UploadTask uploadTask = storageRef.putData(_webImage!);
        TaskSnapshot taskSnapshot = await uploadTask;

        return await taskSnapshot.ref.getDownloadURL();
      } else if (_imageFile != null) {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('admin_images/$documentId');

        UploadTask uploadTask = storageRef.putFile(_imageFile!);
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

  Future<void> _saveImageToFirestore(String imageUrl) async {
    if (_selectedItem != null) {
      try {
        // Determine the correct parent collection based on the selected item
        String parentCollection;

        // Assuming you know that some items belong to Senior_high_items, you need a way to differentiate
        if (_selectedItem!.contains('BLOUSE WITH VEST') || _selectedItem!.contains('Senior')) {
          // Check if the selected item should go into Senior_high_items
          parentCollection = 'Senior_high_items';
        } else {
          // Default to College_items for other items
          parentCollection = 'College_items';
        }

        // Save the image URL to the corresponding collection (either College_items or Senior_high_items)
        await FirebaseFirestore.instance
            .collection('Inventory_stock')
            .doc(parentCollection)
            .collection('Items')
            .doc(_selectedItem)
            .set({'image_url': imageUrl}, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image applied to item successfully!")),
        );
      } catch (e) {
        print("Error saving image to item: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save image to item: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an item first.")),
      );
    }
  }

  Widget _buildImageDisplay() {
    if (kIsWeb) {
      return _webImage != null
          ? Image.memory(
        _webImage!,
        height: 150,
        width: 150,
        fit: BoxFit.cover,
      )
          : Container(
        height: 150,
        width: 150,
        color: Colors.grey[300],
        child: Center(child: Text('No image')),
      );
    } else {
      return _imageFile != null
          ? Image.file(
        _imageFile!,
        height: 150,
        width: 150,
        fit: BoxFit.cover,
      )
          : Container(
        height: 150,
        width: 150,
        color: Colors.grey[300],
        child: Center(child: Text('No image')),
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
              Text('Upload Image to Associate with an Item',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageDisplay(),
                  SizedBox(width: 20),
                  Expanded(
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Select Item'),
                      value: _selectedItem,
                      items: _items.map((item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedItem = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              ElevatedButton.icon(
                icon: Icon(Icons.photo_library),
                label: Text('Select Image'),
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              if (_imageFile != null || _webImage != null) ...[
                SizedBox(height: 20),
                _buildImageDisplay(),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.cloud_upload),
                  label: Text(_isLoading ? 'Uploading...' : 'Upload and Apply Image'),
                  onPressed: _isLoading ? null : _uploadAndSaveImage,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ],
              SizedBox(height: 20),

              Divider(thickness: 2),
              SizedBox(height: 20),

              Text('Update Admin Credentials',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Form(
                key: _formKeyCredentials,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Password TextField
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: Icon(Icons.update),
                      label: Text(_isLoading ? 'Updating...' : 'Update Credentials'),
                      onPressed: _isLoading ? null : updateAdminCredentials,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        textStyle: TextStyle(fontSize: 16),
                      ),
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
