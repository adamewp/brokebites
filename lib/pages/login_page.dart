import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/keychain_service.dart';
import '../services/passkey_service.dart';

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
  final _keychainService = KeychainService();
  final _passkeyService = PasskeyService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _isPasskeyAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkPasskeyAvailability();
  }

  Future<void> _checkPasskeyAvailability() async {
    final isAvailable = await _passkeyService.isPasskeyAvailable();
    setState(() {
      _isPasskeyAvailable = isAvailable;
    });
  }

  Future<void> _loadSavedCredentials() async {
    // Try to get credentials from Passkey first
    if (_isPasskeyAvailable) {
      final credentials = await _passkeyService.getCredentialsWithPasskey();
      if (credentials.isNotEmpty) {
        setState(() {
          _loginController.text =
              credentials['username'] ?? credentials['email'] ?? '';
          _passwordController.text = credentials['password'] ?? '';
        });
        return;
      }
    }

    // Fall back to keychain if Passkey is not available or has no credentials
    final hasCredentials = await _keychainService.hasStoredCredentials();
    if (hasCredentials) {
      final email = await _keychainService.getSavedEmail();
      final password = await _keychainService.getSavedPassword();
      setState(() {
        _loginController.text = email ?? '';
        _passwordController.text = password ?? '';
      });
    }
  }

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

      // If login successful, offer to save with Passkey
      if (_isPasskeyAvailable) {
        await _showPasskeyPrompt(
            email, _passwordController.text, _loginController.text);
      } else if (_rememberMe) {
        // Fall back to keychain if Passkey is not available
        await _keychainService.saveCredentials(
          email: email,
          password: _passwordController.text,
          username: email.contains('@') ? null : _loginController.text,
        );
      } else {
        await _keychainService.deleteAllCredentials();
      }

      await _fetchUserData();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main',
        (Route<dynamic> route) => false,
      );
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

  Future<void> _showPasskeyPrompt(
      String email, String password, String username) async {
    final bool? shouldSave = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Save with Passkey'),
          content: const Text(
              'Would you like to save your credentials securely using Passkey? This will allow you to sign in quickly using biometrics next time.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              isDefaultAction: true,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      await _passkeyService.saveCredentialsWithPasskey(
        email: email,
        password: password,
        username: username,
      );
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({
          'following': [],
          'username':
              FirebaseAuth.instance.currentUser!.displayName ?? 'Unnamed User',
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
                    const Expanded(
                      child: Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() => _rememberMe = !_rememberMe);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _rememberMe
                                      ? CupertinoIcons.checkmark_square_fill
                                      : CupertinoIcons.square,
                                  color: _rememberMe
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.systemGrey,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(
                                    color: CupertinoColors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
