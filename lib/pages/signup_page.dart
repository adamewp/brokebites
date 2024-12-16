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
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _emailsMatch = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to email and password fields
    _emailController.addListener(_checkEmailsMatch);
    _confirmEmailController.addListener(_checkEmailsMatch);
    _passwordController.addListener(_checkPasswordsMatch);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  @override
  void dispose() {
    // Remove listeners when disposing
    _emailController.removeListener(_checkEmailsMatch);
    _confirmEmailController.removeListener(_checkEmailsMatch);
    _passwordController.removeListener(_checkPasswordsMatch);
    _confirmPasswordController.removeListener(_checkPasswordsMatch);
    super.dispose();
  }

  void _checkEmailsMatch() {
    final emailsMatch = _emailController.text.isNotEmpty &&
        _confirmEmailController.text.isNotEmpty &&
        _emailController.text == _confirmEmailController.text;
    if (emailsMatch != _emailsMatch) {
      setState(() {
        _emailsMatch = emailsMatch;
      });
    }
  }

  void _checkPasswordsMatch() {
    final passwordsMatch = _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
    if (passwordsMatch != _passwordsMatch) {
      setState(() {
        _passwordsMatch = passwordsMatch;
      });
    }
  }

  Future<void> _signUp() async {
    // Validate all fields first
    if (!_emailsMatch) {
      _showErrorDialog('Emails do not match.');
      return;
    }

    if (!_passwordsMatch) {
      _showErrorDialog('Passwords do not match.');
      return;
    }

    if (_usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      _showErrorDialog('All fields are required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if username already exists
      final username = _usernameController.text;
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showErrorDialog('Username already taken. Please choose another one.');
        setState(() => _isLoading = false);
        return;
      }

      // Check if email already exists before creating account
      final emailExists = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_emailController.text);
      if (emailExists.isNotEmpty) {
        _showErrorDialog('Email already in use. Please use a different email.');
        setState(() => _isLoading = false);
        return;
      }

      // Create user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Save user details to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'userId': userCredential.user?.uid,
        'username': username,
        'email': _emailController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'bio': '',
        'following': [],
        'followers': []
      });

      // Navigate to main page after successful sign-up
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button and title
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.back,
                        color: Color(0xFF201F24),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                
                // Form section
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Image.asset(
                          'lib/images/bb_text_image.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 30),
                        CupertinoTextField(
                          controller: _usernameController,
                          placeholder: 'Username',
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _firstNameController,
                          placeholder: 'First Name',
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _lastNameController,
                          placeholder: 'Last Name',
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _emailController,
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _confirmEmailController,
                          placeholder: 'Confirm Email',
                          keyboardType: TextInputType.emailAddress,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffix: Icon(
                            _confirmEmailController.text.isEmpty
                                ? null
                                : _emailsMatch
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.xmark_circle_fill,
                            color: _confirmEmailController.text.isEmpty
                                ? null
                                : _emailsMatch
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _passwordController,
                          placeholder: 'Password',
                          obscureText: _obscurePassword,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.only(right: 10),
                            child: Icon(
                              _obscurePassword 
                                  ? CupertinoIcons.eye 
                                  : CupertinoIcons.eye_slash,
                              color: CupertinoColors.systemGrey,
                            ),
                            onPressed: () => setState(() => 
                                _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _confirmPasswordController,
                          placeholder: 'Confirm Password',
                          obscureText: _obscureConfirmPassword,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffix: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _confirmPasswordController.text.isEmpty
                                    ? null
                                    : _passwordsMatch
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.xmark_circle_fill,
                                color: _confirmPasswordController.text.isEmpty
                                    ? null
                                    : _passwordsMatch
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemRed,
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  _obscureConfirmPassword 
                                      ? CupertinoIcons.eye 
                                      : CupertinoIcons.eye_slash,
                                  color: CupertinoColors.systemGrey,
                                ),
                                onPressed: () => setState(() => 
                                    _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Password must include:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF201F24),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text('• At least 6 characters'),
                              Text('• At least one uppercase letter'),
                              Text('• At least one lowercase letter'),
                              Text('• At least one numeric character'),
                              Text('• At least one special character'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                
                // Sign up button section
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : _signUp,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white)
                          : const Text('Create Account'),
                    ),
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