import 'package:flutter/material.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/profile_page.dart';
import 'package:fluttertest/pages/accountSettings_page.dart';
import 'package:fluttertest/pages/discover_page.dart';
import 'package:fluttertest/pages/friends_page.dart';
import 'package:fluttertest/pages/ingredientsInput_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _navigateBottomBar(int index) {
    if (index == 1) {
      Navigator.pushNamed(context, '/newPost');
      return;
    }
    setState(() {
      _selectedIndex = index == 2 ? 1 : 0;
    });
  }

  final List _pages = [
    FriendsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex == 0 ? 0 : 2,
        onTap: _navigateBottomBar,
        selectedItemColor: const Color(0xFF25242A),
        unselectedItemColor: const Color(0xFFB0B0B0),
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 5.0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'New Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}