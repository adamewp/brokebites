import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _bio = '';
  late TextEditingController _bioController;
  List<String> _dietaryRestrictions = ['Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free'];
  String _dob = '';
  late TextEditingController _dobController;
  String _firstName = '';
  late TextEditingController _firstNameController;
  String _lastName = '';
  late TextEditingController _lastNameController;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  List<bool> _selectedRestrictions = [false, false, false, false];
  String _username = ''; // New variable for username

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _dobController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserProfile();
  }

  Future _loadUserProfile() async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    
    if (snapshot.exists) {
      var data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _username = data['username'] ?? ''; // Load username
        _selectedRestrictions = List.generate(_dietaryRestrictions.length, (index) {
          return data['dietaryRestrictions']?.contains(_dietaryRestrictions[index]) ?? false;
        });
      });
    } else {
      print('User document does not exist.');
    }
  }

  Future _saveUserProfile() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      _showErrorDialog('Please enter both first and last names.');
      return;
    }

    RegExp dateFormat = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateFormat.hasMatch(_dobController.text)) {
      _showErrorDialog('Please enter the date of birth in DD/MM/YYYY format.');
      return;
    }

    try {
      String userId = _auth.currentUser!.uid;
      Map<String, dynamic> userData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'dob': _dobController.text,
        'bio': _bioController.text,
        'dietaryRestrictions': _selectedRestrictions.asMap().entries
            .where((entry) => entry.value)
            .map((entry) => _dietaryRestrictions[entry.key])
            .toList(),
      };

      await FirebaseFirestore.instance.collection('users').doc(userId).set(userData, SetOptions(merge: true));
      
      // Navigate back and indicate a refresh is needed
      Navigator.pop(context, true); // Pass true to indicate a refresh
    } catch (e) {
      _showErrorDialog('Error saving profile: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '@${_username}', // Add @ when displaying
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: _dobController,
              decoration: InputDecoration(labelText: 'Date of Birth (DD/MM/YYYY)'),
            ),
            TextField(
              controller: _bioController,
              decoration: InputDecoration(labelText: 'Bio'),
            ),
            SizedBox(height: 20),
            Text('Dietary Restrictions:'),
            ...List.generate(_dietaryRestrictions.length, (index) {
              return CheckboxListTile(
                value: _selectedRestrictions[index],
                onChanged: (bool? value) {
                  setState(() {
                    _selectedRestrictions[index] = value!;
                  });
                },
                title: Text(_dietaryRestrictions[index]),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.grey, // Fill the checkbox with grey when selected
                checkColor: Colors.white, // Set checkmark color to white
                tileColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              );
            }),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800], // Set a darker button background color
                foregroundColor: Colors.white, // Set the text color to white for contrast
              ),
              child: Text('Save Profile'),
            )
          ],
        ),
      ),
    );
  }
}
