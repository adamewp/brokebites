import 'package:flutter/cupertino.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/profile_page.dart';
import 'package:fluttertest/pages/accountSettings_page.dart';
import 'package:fluttertest/pages/friends_page.dart';
import 'package:fluttertest/pages/ingredientsInput_page.dart';
import 'package:fluttertest/pages/newPost_flow.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainPageContent();
  }
}

class MainPageContent extends StatefulWidget {
  const MainPageContent({super.key});

  @override
  _MainPageContentState createState() => _MainPageContentState();
}

class _MainPageContentState extends State<MainPageContent> {
  int _selectedIndex = 0;
  
  static const List<Widget> _pages = [
    FriendsPage(),
    ProfilePage(),
  ];

  void _navigateBottomBar(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => const NewPostFlow(),
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index == 2 ? 1 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      child: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
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