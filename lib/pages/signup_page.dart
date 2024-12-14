import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match.');
      return;
    }

    // Check if username already exists
    final username = _usernameController.text;
    final existingUser = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    if (existingUser.docs.isNotEmpty) {
      _showErrorDialog('Username already taken. Please choose another one.');
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Save user details to Firestore, including user ID
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'userId': userCredential.user?.uid, // Save the user ID
        'username': username,
        'email': _emailController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'bio': '', // Optional bio field
        'following': [], // Initialize following list
        'followers': []   // Initialize followers list
      });

      // Navigate to main page after successful sign-up
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (Route<dynamic> route) => false, // This removes all previous routes
      );
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
      }
      _showErrorDialog(errorMessage);
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF4EFDA),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sign Up'),
        backgroundColor: Color(0xFFF4EFDA),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _usernameController,
                placeholder: 'Enter username without @',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
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
                controller: _emailController,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _passwordController,
                placeholder: 'Password',
                obscureText: _obscurePassword,
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _confirmPasswordController,
                placeholder: 'Confirm Password',
                obscureText: _obscureConfirmPassword,
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    _obscureConfirmPassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Password must include:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• At least 6 characters'),
              const Text('• At least one uppercase letter'),
              const Text('• At least one lowercase letter'),
              const Text('• At least one numeric character'),
              const Text('• At least one special character'),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _signUp,
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}