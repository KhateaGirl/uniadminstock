import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:unistock/main.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKeyCredentials = GlobalKey<FormState>();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImageFile;
  Uint8List? _webImage;
  final picker = ImagePicker();
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  // Dropdown related
  String? _selectedAnnouncement;
  List<String> _announcementOptions = ["Announcement 1", "Announcement 2", "Announcement 3"];

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

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Compress image quality to optimize storage
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        Uint8List webFileBytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = webFileBytes;
          _uploadStatus = "Image selected.";
        });
      } else {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _uploadStatus = "Image selected.";
        });
      }
    } else {
      setState(() {
        _uploadStatus = "No image selected.";
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_isLoading) return; // Prevent multiple uploads
    if (_selectedAnnouncement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an announcement label.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0; // Reset progress indicator
      _uploadStatus = "Uploading...";
    });

    UserController userController = Get.find();
    String documentId = userController.documentId.value;

    try {
      // Upload the image to Firebase Storage
      String imageUrl = await _uploadImageToStorage(documentId);

      if (imageUrl.isNotEmpty) {
        // Check if a document with the selected label exists
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('admin')
            .doc(documentId)
            .collection('announcements')
            .where('announcement_label', isEqualTo: _selectedAnnouncement)
            .get();

        if (snapshot.docs.isNotEmpty) {
          // If exists, update the existing document
          String existingDocId = snapshot.docs.first.id;
          await FirebaseFirestore.instance
              .collection('admin')
              .doc(documentId)
              .collection('announcements')
              .doc(existingDocId)
              .update({'image_url': imageUrl});

          setState(() {
            _uploadStatus = "Image updated successfully!";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image updated successfully!")),
          );
        } else {
          // If it does not exist, create a new document
          await FirebaseFirestore.instance
              .collection('admin')
              .doc(documentId)
              .collection('announcements')
              .add({
            'image_url': imageUrl,
            'announcement_label': _selectedAnnouncement,
          });

          setState(() {
            _uploadStatus = "Image uploaded successfully!";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image uploaded successfully!")),
          );
        }

        // Refresh the UI after successful upload
        _refreshUIAfterUpload();
      } else {
        setState(() {
          _uploadStatus = "Failed to upload image.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image.')),
        );
      }
    } catch (e) {
      print("Error uploading image: $e");
      setState(() {
        _uploadStatus = "Error uploading image: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: $e")),
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
            .child('admin_images/Announcements/$documentId/${DateTime.now().millisecondsSinceEpoch}');

        UploadTask uploadTask = storageRef.putData(_webImage!);
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadStatus = "Uploading... ${(_uploadProgress * 100).toStringAsFixed(2)}%";
          });
        });

        TaskSnapshot taskSnapshot = await uploadTask;
        return await taskSnapshot.ref.getDownloadURL();
      } else if (_selectedImageFile != null) {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('admin_images/Announcements/$documentId/${DateTime.now().millisecondsSinceEpoch}');

        UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);
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

  void _refreshUIAfterUpload() {
    // Reset the state of the form after successful upload
    setState(() {
      _selectedImageFile = null; // Clear the selected image file
      _webImage = null; // Clear the web image
      _selectedAnnouncement = null; // Reset the dropdown selection
      _uploadStatus = ""; // Clear the upload status
      _uploadProgress = 0.0; // Reset the upload progress
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
              SizedBox(height: 20),

              Divider(thickness: 2),
              SizedBox(height: 20),

              Text('Upload Announcement Image',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              // Dropdown to select announcement label
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Announcement',
                  border: OutlineInputBorder(),
                ),
                value: _selectedAnnouncement,
                items: _announcementOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
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
                label: Text('Select Image'),
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 20),

              // Display image preview
              if (_webImage != null) ...[
                Image.memory(_webImage!, height: 150),
                SizedBox(height: 10),
              ] else if (_selectedImageFile != null) ...[
                Image.file(_selectedImageFile!, height: 150),
                SizedBox(height: 10),
              ],

              if (_uploadProgress > 0) ...[
                Text(
                  _uploadStatus,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                LinearProgressIndicator(value: _uploadProgress),
                SizedBox(height: 20),
              ],

              ElevatedButton.icon(
                icon: Icon(Icons.cloud_upload),
                label: Text(_isLoading ? 'Uploading...' : 'Upload Image'),
                onPressed: _isLoading ? null : _uploadImage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
