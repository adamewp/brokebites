import 'package:flutter/material.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/profile_page.dart';
import 'package:fluttertest/pages/accountSettings_page.dart';
import 'package:fluttertest/pages/discover_page.dart';
import 'package:fluttertest/pages/friends_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State createState() => _MainPageState(); // Specify the type
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List _pages = [
    DiscoverPage(),
    FriendsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Correctly set the body
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _navigateBottomBar,
        selectedItemColor: const Color(0xFF25242A), // Dark color for selected icon
        unselectedItemColor: const Color(0xFFB0B0B0), // Faded gray for unselected icons
        backgroundColor: const Color(0xFFFAF8F5), // Lighter beige background
        elevation: 5.0, // Slight shadow for the bottom bar for separation
        items: [
          // Discover
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Discover',
          ),
          // Friends
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          // Profile
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
