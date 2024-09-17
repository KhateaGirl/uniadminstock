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
  final _formKeyCredentials = GlobalKey<FormState>();  // Separate form key for credentials
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  File? _imageFile;
  Uint8List? _webImage; // For web-based image upload
  final picker = ImagePicker();
  String? _imageUrl;
  String? _selectedItem; // Selected item from the dropdown
  List<String> _items = []; // Items to populate the dropdown
  bool _isLoading = false; // Loading indicator for fetching items

  @override
  void initState() {
    super.initState();
    _fetchExistingImage();
    _fetchItems(); // Fetch items on initialization
  }

  // Function to update admin credentials (username and password) in Firestore
  Future<void> updateAdminCredentials() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    if (_formKeyCredentials.currentState?.validate() == true) {
      try {
        // Assuming the logged-in admin's document ID is stored in the UserController
        UserController userController = Get.find();
        String documentId = userController.documentId.value;

        // Update the credentials in Firestore (admin collection)
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

  // Fetch the existing image URL from Firestore
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

  // Fetch items from the Firestore subcollection (College_items or Senior_high_items)
  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String parentCollection = 'College_items'; // Change to 'Senior_high_items' as needed
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc(parentCollection)
          .collection('Items')
          .get();

      List<String> fetchedItems = querySnapshot.docs.map((doc) {
        return doc.id; // Assuming each document has an 'id' field for dropdown reference
      }).toList();

      setState(() {
        _items = fetchedItems;
      });
    } catch (e) {
      print("Error fetching items: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        // Web: Read image as bytes
        setState(() async {
          _webImage = await pickedFile.readAsBytes();
        });
      } else {
        // Mobile/Desktop: Use File class
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  // Function to upload the image to Firebase Storage
  Future<String> _uploadImageToStorage(String documentId) async {
    try {
      if (kIsWeb && _webImage != null) {
        // For Flutter Web, we use the byte data to upload
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('admin_images/$documentId');

        UploadTask uploadTask = storageRef.putData(_webImage!);
        TaskSnapshot taskSnapshot = await uploadTask;

        return await taskSnapshot.ref.getDownloadURL();
      } else if (_imageFile != null) {
        // For mobile and desktop
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

  // Function to save the image URL to Firestore (admin collection and the selected item)
  Future<void> _saveImageToFirestore(String imageUrl) async {
    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    // Save to 'admin' collection
    await FirebaseFirestore.instance
        .collection('admin')
        .doc(documentId)
        .set({'image_url': imageUrl}, SetOptions(merge: true));

    // Save to the selected item in the 'Items' subcollection
    if (_selectedItem != null) {
      await FirebaseFirestore.instance
          .collection('Inventory_stock')
          .doc('College_items') // or 'Senior_high_items' based on logic
          .collection('Items')
          .doc(_selectedItem)
          .set({'image_url': imageUrl}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image applied to item successfully!")),
      );
    }
  }

  // Function to upload and save the image to both the admin collection and the selected item
  Future<void> _uploadAndSaveImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_imageFile == null && _webImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select an image first.")),
        );
        return;
      }

      if (_selectedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select an item first.")),
        );
        return;
      }

      UserController userController = Get.find();
      String documentId = userController.documentId.value;

      String imageUrl = await _uploadImageToStorage(documentId);
      if (imageUrl.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl;
        });

        // Save image URL to both admin collection and the selected item
        await _saveImageToFirestore(imageUrl);
      }
    } catch (e) {
      print("Error uploading image: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to build the image display widget depending on the platform (web vs other)
  Widget _buildImageDisplay() {
    if (kIsWeb) {
      // Display the web image as bytes
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
      // For mobile or desktop
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
              // Image upload section (without validation)
              Text('Upload Image to Associate with an Item',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              // Row for image and dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the image
                  _buildImageDisplay(),
                  SizedBox(width: 20),
                  // Dropdown for items
                  Expanded(
                    child: _isLoading
                        ? CircularProgressIndicator() // Show loading indicator while fetching items
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

              // Image Picker Button
              ElevatedButton.icon(
                icon: Icon(Icons.photo_library), // Add an icon to the button
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
                  icon: Icon(Icons.cloud_upload), // Add an upload icon
                  label: Text(_isLoading ? 'Uploading...' : 'Upload and Apply Image'), // Change text based on loading state
                  onPressed: _isLoading ? null : _uploadAndSaveImage, // Disable button during upload
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ],
              SizedBox(height: 20),

              // Separator line or space
              Divider(thickness: 2),
              SizedBox(height: 20),

              // Credentials update section
              Text('Update Admin Credentials',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              // Form for credentials
              Form(
                key: _formKeyCredentials,
                child: Column(
                  children: [
                    // Username TextField
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

                    // Credentials Update Button
                    ElevatedButton.icon(
                      icon: Icon(Icons.update), // Add update icon
                      label: Text(_isLoading ? 'Updating...' : 'Update Credentials'), // Change text based on loading state
                      onPressed: _isLoading ? null : updateAdminCredentials, // Disable button during update
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
