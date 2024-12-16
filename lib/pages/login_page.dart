import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogInPage extends StatefulWidget {
  final bool showBackButton;
  
  const LogInPage({
    super.key,
    this.showBackButton = true,
  });

  @override
  _LogInPageState createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _logIn() async {
    setState(() => _isLoading = true);
    
    try {
      String email = _loginController.text;
      
      // Check if input is not an email
      if (!email.contains('@')) {
        // Query Firestore to get email by username
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: _loginController.text)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          _showErrorDialog('Username not found');
          setState(() => _isLoading = false);
          return;
        }

        email = userQuery.docs.first.get('email');
      }

      // Attempt login with email
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      await _fetchUserData();
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      String errorMessage = 'Login failed';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email/username';
            break;
          case 'wrong-password':
            errorMessage = 'Wrong password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email format';
            break;
          default:
            errorMessage = e.message ?? 'Login failed';
        }
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!userDoc.exists) {
        // Create the user document if it doesn't exist
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
          'following': [],
          'username': FirebaseAuth.instance.currentUser!.displayName ?? 'Unnamed User',
        });
      } else {
        // Populate your fields with user data here if needed
        String username = userDoc['username'];
        // Use this data in your app as needed
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
                    if (widget.showBackButton)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(
                          CupertinoIcons.back,
                          color: Color(0xFF201F24),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.showBackButton)
                      const SizedBox(width: 40), // Balance the back button
                  ],
                ),
                
                // Logo and form section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'lib/images/bb_text_image.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 40),
                      CupertinoTextField(
                        controller: _loginController,
                        placeholder: 'Email or Username',
                        keyboardType: TextInputType.emailAddress,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textInputAction: TextInputAction.next,
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
                    ],
                  ),
                ),
                
                // Sign in button section
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : _logIn,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white)
                          : const Text('Sign In'),
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