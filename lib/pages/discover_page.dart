import 'package:flutter/material.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/profile_page.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text(
          'Welcome to BrokeBites',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
