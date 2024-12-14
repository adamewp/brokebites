import 'package:flutter/cupertino.dart';
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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      child: Stack(
        children: [
          _pages[_selectedIndex],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CupertinoTabBar(
              currentIndex: _selectedIndex == 0 ? 0 : 2,
              onTap: _navigateBottomBar,
              activeColor: const Color(0xFF25242A),
              inactiveColor: const Color(0xFFB0B0B0),
              backgroundColor: const Color(0xFFFAF8F5),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.list_bullet),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.add_circled),
                  label: 'New Post',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}