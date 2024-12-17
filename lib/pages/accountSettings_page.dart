import 'package:flutter/cupertino.dart';
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
  final String _bio = '';
  late TextEditingController _bioController;
  final List<String> _dietaryRestrictions = [
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Dairy-Free'
  ];
  final String _dob = '';
  late TextEditingController _dobController;
  final String _firstName = '';
  late TextEditingController _firstNameController;
  final String _lastName = '';
  late TextEditingController _lastNameController;
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  List<bool> _selectedRestrictions = [false, false, false, false];
  String _username = '';
  final TextEditingController _deleteConfirmController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _deleteConfirmController.dispose();
    _passwordController.dispose();
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
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (snapshot.exists) {
      var data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _username = data['username'] ?? '';
        _selectedRestrictions =
            List.generate(_dietaryRestrictions.length, (index) {
          return data['dietaryRestrictions']
                  ?.contains(_dietaryRestrictions[index]) ??
              false;
        });
      });
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
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

      // Create a list of selected dietary restrictions
      List<String> selectedDietaryRestrictions = [];
      for (int i = 0; i < _selectedRestrictions.length; i++) {
        if (_selectedRestrictions[i]) {
          selectedDietaryRestrictions.add(_dietaryRestrictions[i]);
        }
      }

      Map<String, dynamic> userData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'dob': _dobController.text,
        'bio': _bioController.text,
        'dietaryRestrictions': selectedDietaryRestrictions,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(userData);

      showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('Profile updated successfully'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pop(context, true); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Error saving profile: $e');
    }
  }

  void _handleLogout() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              isDefaultAction: true,
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/startup', (route) => false);
              },
              isDestructiveAction: true,
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            children: [
              const Text(
                  'This action cannot be undone. To confirm, please type "DELETE" and enter your password.'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _deleteConfirmController,
                placeholder: 'Type DELETE',
                padding: const EdgeInsets.all(8),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _passwordController,
                placeholder: 'Enter password',
                obscureText: true,
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                _deleteConfirmController.clear();
                _passwordController.clear();
                Navigator.of(context).pop();
              },
              isDefaultAction: true,
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                if (_deleteConfirmController.text != 'DELETE') {
                  _showErrorDialog('Please type "DELETE" to confirm');
                  return;
                }

                try {
                  // Re-authenticate user
                  final user = _auth.currentUser!;
                  final email = user.email!;
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: _passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Delete user data from Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete();

                  // Delete user account
                  await user.delete();

                  // Clear controllers
                  _deleteConfirmController.clear();
                  _passwordController.clear();

                  // Navigate to startup screen
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/startup', (route) => false);
                } catch (e) {
                  Navigator.of(context).pop(); // Close the dialog
                  _showErrorDialog('Error deleting account: ${e.toString()}');
                }
              },
              isDestructiveAction: true,
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Account Settings'),
        backgroundColor: Color(0xFFFAF8F5),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '@$_username',
                style: const TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _firstNameController,
                placeholder: 'First Name',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _lastNameController,
                placeholder: 'Last Name',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _dobController,
                placeholder: 'Date of Birth (DD/MM/YYYY)',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _bioController,
                placeholder: 'Bio',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dietary Restrictions:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF25242A),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_dietaryRestrictions.length, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: CupertinoColors.systemGrey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _selectedRestrictions[index] =
                            !_selectedRestrictions[index];
                      });
                    },
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          _selectedRestrictions[index]
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: _selectedRestrictions[index]
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGrey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _dietaryRestrictions[index],
                          style: TextStyle(
                            color: _selectedRestrictions[index]
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _saveUserProfile,
                child: const Text('Save Profile'),
              ),
              const SizedBox(height: 40),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                onPressed: _handleLogout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.destructiveRed),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                onPressed: _handleDeleteAccount,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.destructiveRed),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Delete Account',
                      style: TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
