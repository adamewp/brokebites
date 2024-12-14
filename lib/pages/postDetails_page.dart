import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  final int portions;

  const PostDetailsPage({
    super.key,
    required this.ingredients,
    required this.portions,
  });

  @override
  _PostDetailsPageState createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isLoading = false;

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      _showErrorMessage('Maximum 5 images allowed');
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
      _showErrorMessage('Please enter a title');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      List<String> imageUrls = [];
      for (File image in _selectedImages) {
        String fileName = 'posts/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(image);
        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

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

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print('Error submitting post: $e');
      _showErrorMessage('Failed to submit post. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Post Details'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: 'Title',
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _descriptionController,
                    placeholder: 'Description',
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImages.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
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
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeImage(index),
                                  child: const Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    color: CupertinoColors.destructiveRed,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _pickImage,
                    child: Text('Add Images (${_selectedImages.length}/5)'),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _submitPost,
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: CupertinoColors.systemBackground.withOpacity(0.7),
                child: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}