import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/keychain_service.dart';
import '../services/passkey_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

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
  final _keychainService = KeychainService();
  final _passkeyService = PasskeyService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _emailsMatch = false;
  bool _passwordsMatch = false;
  bool _rememberMe = true;
  bool _isPasskeyAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkPasskeyAvailability();
    // Add listeners to email and password fields
    _emailController.addListener(_checkEmailsMatch);
    _confirmEmailController.addListener(_checkEmailsMatch);
    _passwordController.addListener(_checkPasswordsMatch);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  Future<void> _checkPasskeyAvailability() async {
    final isAvailable = await _passkeyService.isPasskeyAvailable();
    setState(() {
      _isPasskeyAvailable = isAvailable;
    });
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
      await FirebaseAnalytics.instance.logEvent(
        name: 'signup_error',
        parameters: {
          'error_type': 'email_mismatch',
        },
      );
      return;
    }

    if (!_passwordsMatch) {
      _showErrorDialog('Passwords do not match.');
      await FirebaseAnalytics.instance.logEvent(
        name: 'signup_error',
        parameters: {
          'error_type': 'password_mismatch',
        },
      );
      return;
    }

    if (_usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      _showErrorDialog('All fields are required.');
      await FirebaseAnalytics.instance.logEvent(
        name: 'signup_error',
        parameters: {
          'error_type': 'missing_fields',
        },
      );
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
        await FirebaseAnalytics.instance.logEvent(
          name: 'signup_error',
          parameters: {
            'error_type': 'username_taken',
          },
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if email already exists before creating account
      final emailExists = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(_emailController.text);
      if (emailExists.isNotEmpty) {
        _showErrorDialog('Email already in use. Please use a different email.');
        await FirebaseAnalytics.instance.logEvent(
          name: 'signup_error',
          parameters: {
            'error_type': 'email_exists',
          },
        );
        setState(() => _isLoading = false);
        return;
      }

      // Create user account
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Log successful account creation
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');

      // Save user details to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'userId': userCredential.user?.uid,
        'username': username,
        'email': _emailController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'bio': '',
        'following': [],
        'followers': [],
        'hasSeenWelcome': false,
      });

      // If Passkey is available, show prompt to save credentials
      if (_isPasskeyAvailable) {
        await _showPasskeyPrompt(
            _emailController.text, _passwordController.text, username);
        await FirebaseAnalytics.instance.logEvent(
          name: 'passkey_prompt_shown',
          parameters: {
            'user_id': userCredential.user?.uid ?? 'unknown',
          },
        );
      } else if (_rememberMe) {
        // Fall back to keychain if Passkey is not available
        await _keychainService.saveCredentials(
          email: _emailController.text,
          password: _passwordController.text,
          username: username,
        );
        await FirebaseAnalytics.instance.logEvent(
          name: 'credentials_saved_to_keychain',
          parameters: {
            'user_id': userCredential.user?.uid ?? 'unknown',
          },
        );
      }

      // Navigate to welcome page after successful sign-up
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/welcome',
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? errorMessage;
        await FirebaseAnalytics.instance.logEvent(
          name: 'signup_error',
          parameters: {
            'error_type': 'auth_error',
            'error_code': e.code,
            'error_message': e.message ?? 'Unknown error',
          },
        );
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
                          textCapitalization: TextCapitalization.words,
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
                          textCapitalization: TextCapitalization.words,
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
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
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
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword),
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
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                        const SizedBox(height: 20),
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
