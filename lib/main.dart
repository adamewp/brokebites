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
import 'package:fluttertest/pages/ingredientsInput_page.dart';
import 'package:fluttertest/pages/main_page.dart';
import 'package:fluttertest/pages/newPost_flow.dart';
import 'package:fluttertest/pages/postDetails_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertest/pages/otherProfile_page.dart';
import 'package:fluttertest/pages/inspectPost_page.dart';
import 'package:fluttertest/pages/followers_list.dart';
import 'package:fluttertest/pages/following_list.dart';

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
        primaryColor: const Color(0xFFFAF8F5),
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF8F5),
          foregroundColor: Color(0xFF25242A),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF25242A)),
          bodyMedium: TextStyle(color: Color(0xFF25242A)),
          bodySmall: TextStyle(color: Color(0xFF25242A)),
          titleLarge: TextStyle(color: Color(0xFF25242A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF25242A),
            foregroundColor: Color(0xFFFAF8F5),
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF25242A),
          ),
        ),
        iconTheme: IconThemeData(
          color: Color(0xFF25242A),
        ),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF25242A),
          secondary: const Color(0xFFFAF8F5),
          onPrimary: const Color(0xFFFAF8F5),
          onSecondary: const Color(0xFF25242A),
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
        '/newPost': (context) => IngredientsPage(
          onNext: (ingredients, portions) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailsPage(
                  ingredients: ingredients,
                  portions: portions,
                ),
              ),
            );
          },
        ),
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
        '/followers': (context) {
          final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return FollowersList(
            userId: args['userId'],
            isCurrentUser: args['isCurrentUser'],
          );
        },
        '/following': (context) {
          final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return FollowingList(
            userId: args['userId'],
            isCurrentUser: args['isCurrentUser'],
          );
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