import 'package:flutter/material.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/discover_page.dart';
import 'package:fluttertest/pages/profile_page.dart';
import 'package:fluttertest/pages/accountSettings_page.dart';
import 'package:fluttertest/pages/friends_page.dart';
import 'package:fluttertest/pages/searchFriends_page.dart';
import 'package:fluttertest/pages/comments_page.dart';
import 'package:fluttertest/pages/newPost_page.dart';
import 'package:fluttertest/pages/main_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertest/pages/otherProfile_page.dart';
import 'package:fluttertest/pages/inspectPost_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFFFAF8F5), // Lighter, sleeker beige
  scaffoldBackgroundColor: const Color(0xFFFAF8F5), // Matches the primary background
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFAF8F5), // AppBar blends with the background
    foregroundColor: Color(0xFF25242A), // Dark text for contrast
    elevation: 0, // Remove shadow for a cleaner look
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF25242A)), // Main text color
    bodyMedium: TextStyle(color: Color(0xFF25242A)), // Regular text color
    bodySmall: TextStyle(color: Color(0xFF25242A)), // Smaller text
    titleLarge: TextStyle(color: Color(0xFF25242A)), // Titles in AppBar and cards
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF25242A), // Dark background for buttons
      foregroundColor: Color(0xFFFAF8F5), // Light text for contrast
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFF25242A), // Dark text for text buttons
    ),
  ),
  iconTheme: IconThemeData(
    color: Color(0xFF25242A), // Dark icons
  ),
  colorScheme: ColorScheme.light(
    primary: const Color(0xFF25242A), // Dark color for primary elements
    secondary: const Color(0xFFFAF8F5), // Light color for secondary elements
    onPrimary: const Color(0xFFFAF8F5), // Light text on primary color
    onSecondary: const Color(0xFF25242A), // Dark text on secondary color
  ),
),


      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            User? user = snapshot.data;
            if (user == null) {
              return StartUpPage();
            } else {
              return FutureBuilder<void>(
                future: _initializeUserDocument(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return MainPage();
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              );
            }
          }
          return const Center(child: CircularProgressIndicator()); 
        },
      ),
      routes: {
        '/startup': (context) => const StartUpPage(),
        '/main': (context) => const MainPage(),
        '/login': (context) => const LogInPage(),
        '/signup': (context) => const SignUpPage(),
        '/discover': (context) => const DiscoverPage(),
        '/profile': (context) => const ProfilePage(),
        '/newPost': (context) => const NewPostPage(),
        '/accountSettings': (context) => const AccountSettingsPage(),
        '/friends': (context) => const FriendsPage(),
        '/searchFriends_page': (context) => const SearchFriendsPage(),
        '/comments': (context) {
          final String postId = ModalRoute.of(context)!.settings.arguments as String;
          return CommentsPage(postId: postId);
        },
        '/otherProfile': (context) {
          final String userId = ModalRoute.of(context)!.settings.arguments as String;
          return OtherProfilePage(userId: userId);
        },
        '/inspectPost': (context) {
          final String postId = ModalRoute.of(context)!.settings.arguments as String;
          return InspectPostPage(postId: postId);
        },
      },
    );
  }

  Future<void> _initializeUserDocument(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'following': [],
        'username': FirebaseAuth.instance.currentUser!.displayName ?? 'Unnamed User',
      });
    }
  }
}
