import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:unistock/main.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  File? _imageFile;  // To hold the image file
  final picker = ImagePicker();  // For image picking
  String? _imageUrl;  // To store the image URL

  @override
  void initState() {
    super.initState();
    _fetchExistingImage();
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

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Function to upload the image to Firebase Storage
  Future<String> _uploadImageToStorage(String documentId) async {
    try {
      if (_imageFile == null) throw 'No image selected';

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('admin_images/$documentId');  // Store with the document ID

      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask;

      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return '';
    }
  }

  // Function to save the image URL to Firestore
  Future<void> _saveImageToFirestore(String imageUrl) async {
    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    await FirebaseFirestore.instance
        .collection('admin')
        .doc(documentId)
        .set({'image_url': imageUrl}, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Image uploaded successfully!")),
    );
  }

  // Function to delete image from Firestore and Storage
  Future<void> _deleteImage() async {
    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    await FirebaseFirestore.instance
        .collection('admin')
        .doc(documentId)
        .update({'image_url': FieldValue.delete()});

    await FirebaseStorage.instance
        .ref()
        .child('admin_images/$documentId')
        .delete();

    setState(() {
      _imageUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Image removed successfully!")),
    );
  }

  // Function to upload and save the image
  Future<void> _uploadAndSaveImage() async {
    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    String imageUrl = await _uploadImageToStorage(documentId);
    if (imageUrl.isNotEmpty) {
      setState(() {
        _imageUrl = imageUrl;
      });
      _saveImageToFirestore(imageUrl);
    }
  }

  // Function to update admin credentials
  void updateAdminCredentials() async {
    UserController userController = Get.find();  // Get the UserController
    String documentId = userController.documentId.value;  // Retrieve the document ID

    if (documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: No document ID found")),
      );
      return;
    }

    // Proceed with updating credentials in Firestore
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection('admin')
            .doc(documentId)  // Use the stored document ID from the UserController
            .update({
          'Username': _usernameController.text,
          'Password': _passwordController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Credentials updated successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating credentials: $e")),
        );
      }
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Display the image or the placeholder if there's no image
                _imageUrl != null
                    ? Column(
                  children: [
                    Image.network(_imageUrl!, height: 150),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _deleteImage,
                      child: Text("Remove Image"),
                    ),
                  ],
                )
                    : Text('No image uploaded.'),
                SizedBox(height: 20),

                // Image Picker Button
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Select Image'),
                ),
                if (_imageFile != null) ...[
                  SizedBox(height: 20),
                  Image.file(_imageFile!, height: 150),  // Display selected image
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _uploadAndSaveImage,
                    child: Text('Upload Image'),
                  ),
                ],
                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: updateAdminCredentials,
                  child: Text('Update Credentials'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
