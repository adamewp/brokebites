import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  final int portions;

  PostDetailsPage({required this.ingredients, required this.portions});

  @override
  _PostDetailsPageState createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 5 images allowed')),
      );
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        for (var image in images) {
          if (_selectedImages.length < 5) {
            _selectedImages.add(File(image.path));
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      for (File image in _selectedImages) {
        String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(image);
        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // Create post document in Firestore
      await FirebaseFirestore.instance.collection('mealPosts').add({
        'userId': user.uid,
        'mealTitle': _titleController.text,
        'mealDescription': _descriptionController.text,
        'ingredients': widget.ingredients,
        'portions': widget.portions,
        'imageUrls': imageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'comments': [],
      });

      // Navigate back to main page after successful post
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print('Error submitting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit post. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Post Details'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Image.file(
                                  _selectedImages[index],
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                child: IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.add_photo_alternate),
                    label: Text('Add Images (${_selectedImages.length}/5)'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitPost,
                    child: Text('Post'),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}