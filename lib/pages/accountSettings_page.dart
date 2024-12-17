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
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

    try {
      String userId = _auth.currentUser!.uid;

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
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Error saving profile: $e');
    } finally {
      setState(() => _isLoading = false);
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
                  final user = _auth.currentUser!;
                  final email = user.email!;
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: _passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete();

                  await user.delete();

                  _deleteConfirmController.clear();
                  _passwordController.clear();

                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/startup', (route) => false);
                } catch (e) {
                  Navigator.of(context).pop();
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool isLastField = false,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5,
            width: isLastField ? 0 : 0.5,
          ),
        ),
      ),
      child: CupertinoTextField.borderless(
        controller: controller,
        placeholder: placeholder,
        padding: const EdgeInsets.all(16),
        obscureText: obscureText,
        style: const TextStyle(
          color: Color(0xFF25242A),
          fontSize: 17,
        ),
        placeholderStyle: TextStyle(
          color: const Color(0xFF25242A).withOpacity(0.4),
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Account Settings'),
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '@$_username',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF25242A),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'PROFILE INFORMATION',
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      placeholder: 'First Name',
                    ),
                    _buildTextField(
                      controller: _lastNameController,
                      placeholder: 'Last Name',
                    ),
                    _buildTextField(
                      controller: _dobController,
                      placeholder: 'Date of Birth (DD/MM/YYYY)',
                    ),
                    _buildTextField(
                      controller: _bioController,
                      placeholder: 'Bio',
                      isLastField: true,
                    ),
                  ],
                ),
                _buildSection(
                  title: 'DIETARY RESTRICTIONS',
                  children: List.generate(_dietaryRestrictions.length, (index) {
                    bool isLast = index == _dietaryRestrictions.length - 1;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isLast
                                ? CupertinoColors.white
                                : CupertinoColors.systemGrey5,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _selectedRestrictions[index] =
                                !_selectedRestrictions[index];
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dietaryRestrictions[index],
                                style: const TextStyle(
                                  color: Color(0xFF25242A),
                                  fontSize: 17,
                                ),
                              ),
                              Icon(
                                _selectedRestrictions[index]
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.circle,
                                color: _selectedRestrictions[index]
                                    ? const Color(0xFF25242A)
                                    : CupertinoColors.systemGrey3,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          onPressed: _isLoading ? null : _saveUserProfile,
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white)
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _handleLogout,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                color: Color(0xFF25242A),
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _handleDeleteAccount,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: CupertinoColors.destructiveRed,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Delete Account',
                              style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
