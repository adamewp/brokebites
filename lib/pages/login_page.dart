import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogInPage extends StatefulWidget {
  const LogInPage({super.key});

  @override
  _LogInPageState createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _logIn() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Fetch user data after successful login
      await _fetchUserData();

      // Navigate to main page after successful login
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      _showErrorDialog(e.toString());
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
        backgroundColor: const Color(0xFFF4EFDA),
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        child: AutofillGroup(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _logIn,
                  child: const Text('Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}