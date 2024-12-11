import 'package:flutter/material.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';

class StartUpPage extends StatelessWidget {
  const StartUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Color(0xFFF4EFDA),
              child: Center( // Center the image
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the image vertically
                  children: [
                    Image.asset(
                      'lib/images/bb_logo.png',
                      fit: BoxFit.contain, // Adjusts the image to fit within the container
                    ),
                    const SizedBox(height: 20), // Space below the logo
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Color(0xFF201F24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: Container(
                      height: 50,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFF201F23), // Background color of the button
                        border: Border.all(color: Color(0xFFF4EFDA), width: 1), // Thin border matching the background color
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: Container(
                      height: 50,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Color(0xFFF4EFDA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}