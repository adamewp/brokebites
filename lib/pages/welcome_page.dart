import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/messaging_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    await MessagingService.initialize();
    await _markWelcomeAsSeen();
  }

  Future<void> _markWelcomeAsSeen() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'hasSeenWelcome': true,
      });
    }
  }

  Future<void> _skipWelcome() async {
    await _markWelcomeAsSeen();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildShareMealsPage();
      case 1:
        return _buildSocialFeedPage();
      case 2:
        return _buildFollowingPage();
      case 3:
        return _buildNotificationsPage();
      case 4:
        return _buildProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildShareMealsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25242A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.camera_fill,
              size: 80,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Share Your Meals',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share photos of your daily meals and inspire others with your ingredient lists',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialFeedPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25242A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.heart_fill,
              size: 80,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Discover & Connect',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Like, comment, and get inspired by meals shared by your friends',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25242A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.person_badge_plus_fill,
              size: 80,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Follow Friends',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap the Follow button on any profile to see their meals in your feed and stay connected',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25242A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_fill,
              size: 80,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Stay Updated',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get notified when friends like your posts, leave comments, or start following you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: _requestNotificationPermission,
              child: const Text(
                'Enable Notifications',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25242A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              size: 80,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Your Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Customize your profile, connect with friends, and manage your settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: () async {
                await _markWelcomeAsSeen();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/main');
                }
              },
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_numPages, (index) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index
                  ? const Color(0xFF25242A)
                  : const Color(0xFF25242A).withOpacity(0.2),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'Skip',
            style: TextStyle(
              color: Color(0xFF25242A),
              fontSize: 17,
            ),
          ),
          onPressed: _skipWelcome,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _numPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(index);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: _buildPageIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
