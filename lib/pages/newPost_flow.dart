import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewPostFlow extends StatefulWidget {
  const NewPostFlow({super.key});

  @override
  _NewPostFlowState createState() => _NewPostFlowState();
}

class _NewPostFlowState extends State<NewPostFlow> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _portionsController = TextEditingController();
  final TextEditingController _ingredientController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  final List<String> _units = [
    'g',
    'kg',
    'ml',
    'L',
    'cup',
    'tbsp',
    'tsp',
    'oz',
    'lb',
    'pcs'
  ];
  final List<Map<String, dynamic>> _ingredients = [];

  static const double _borderRadius = 10.0;
  static const Color _borderColor = CupertinoColors.systemGrey4;
  static const EdgeInsets _contentPadding = EdgeInsets.all(16.0);
  static const double _spacing = 20.0;

  void _addIngredient(String name) {
    setState(() {
      _ingredients.add({
        'name': name,
        'amount': '',
        'unit': '',
      });
    });
  }

  void _updateIngredient(int index, String amount, String unit) {
    setState(() {
      _ingredients[index]['amount'] = amount;
      _ingredients[index]['unit'] = unit;
    });
  }

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

    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      for (var image in images) {
        if (_selectedImages.length < 5) {
          _selectedImages.add(File(image.path));
        }
      }
    });
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

    if (_ingredients.isEmpty) {
      _showErrorMessage('Please add at least one ingredient');
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
        String fileName =
            'posts/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(image);
        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      int portions = int.tryParse(_portionsController.text) ?? 1;

      await FirebaseFirestore.instance.collection('mealPosts').add({
        'userId': user.uid,
        'mealTitle': _titleController.text,
        'mealDescription': _descriptionController.text,
        'ingredients': _ingredients,
        'portions': portions,
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
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create Recipe'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: _contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CupertinoTextField.borderless(
                          controller: _titleController,
                          placeholder: 'Recipe Title',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                        Container(height: 1, color: _borderColor),
                        CupertinoTextField.borderless(
                          controller: _descriptionController,
                          placeholder: 'Description',
                          style: const TextStyle(fontSize: 16),
                          padding: const EdgeInsets.all(12),
                          minLines: 3,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  _buildSection(
                    child: CupertinoTextField.borderless(
                      controller: _portionsController,
                      placeholder: 'Number of Portions',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: false),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(CupertinoIcons.person_2_fill,
                            color: CupertinoColors.systemGrey),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  _buildSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(height: 1, color: _borderColor),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoTextField(
                                  controller: _ingredientController,
                                  placeholder: 'Add ingredient',
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6,
                                    borderRadius:
                                        BorderRadius.circular(_borderRadius),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton(
                                onPressed: () {
                                  if (_ingredientController.text.isNotEmpty) {
                                    _addIngredient(_ingredientController.text);
                                    _ingredientController.clear();
                                  }
                                },
                                child: const Icon(
                                    CupertinoIcons.add_circled_solid),
                              ),
                            ],
                          ),
                        ),
                        if (_ingredients.isNotEmpty)
                          Container(height: 1, color: _borderColor),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _ingredients.length,
                          separatorBuilder: (context, index) =>
                              Container(height: 1, color: _borderColor),
                          itemBuilder: (context, index) =>
                              _buildIngredientItem(index),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  _buildSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_selectedImages.isNotEmpty) ...[
                          Container(height: 1, color: _borderColor),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) =>
                                  _buildImageItem(index),
                            ),
                          ),
                        ],
                        Container(height: 1, color: _borderColor),
                        CupertinoButton(
                          onPressed: _pickImage,
                          child: Text(
                            'Add Photos (${_selectedImages.length}/5)',
                            style: const TextStyle(
                                color: CupertinoColors.activeBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  CupertinoButton.filled(
                    onPressed: _isLoading ? null : _submitPost,
                    child: const Text('Share Recipe'),
                  ),
                  const SizedBox(height: _spacing),
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

  Widget _buildSection({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildIngredientItem(int index) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _ingredients[index]['name'],
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              placeholder: 'Amount',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => _updateIngredient(
                index,
                value,
                _ingredients[index]['unit'],
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(_borderRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showUnitPicker(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: Text(
                  _ingredients[index]['unit'] == ''
                      ? 'Unit'
                      : _ingredients[index]['unit'],
                  style: TextStyle(
                    color: _ingredients[index]['unit'] == ''
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.black,
                  ),
                ),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => setState(() => _ingredients.removeAt(index)),
            child: const Icon(
              CupertinoIcons.delete,
              color: CupertinoColors.destructiveRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageItem(int index) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius),
            child: Image.file(
              _selectedImages[index],
              height: 104,
              width: 104,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _removeImage(index),
            child: Container(
              decoration: const BoxDecoration(
                color: CupertinoColors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.clear,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUnitPicker(int index) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          message: const Text(
            'Select a unit of measurement',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ..._units.map((unit) {
              return CupertinoActionSheetAction(
                onPressed: () {
                  _updateIngredient(
                    index,
                    _ingredients[index]['amount'],
                    unit,
                  );
                  Navigator.pop(context);
                },
                child: Text(unit),
              );
            }),
            CupertinoActionSheetAction(
              onPressed: () {
                _updateIngredient(
                  index,
                  _ingredients[index]['amount'],
                  '',
                );
                Navigator.pop(context);
              },
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'No unit '),
                    TextSpan(
                      text: '(for items like eggs, apples)',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}
