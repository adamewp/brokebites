import 'package:flutter/cupertino.dart';
import 'package:fluttertest/pages/startup_page.dart';
import 'package:fluttertest/pages/signup_page.dart';
import 'package:fluttertest/pages/login_page.dart';
import 'package:fluttertest/pages/profile_page.dart';
import 'package:fluttertest/pages/accountSettings_page.dart';
import 'package:fluttertest/pages/friends_page.dart';
import 'package:fluttertest/pages/searchFriends_page.dart';
import 'package:fluttertest/pages/comments_page.dart';
import 'package:fluttertest/pages/main_page.dart';
import 'package:fluttertest/pages/newPost_flow.dart';
import 'package:fluttertest/pages/notifications_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertest/pages/otherProfile_page.dart';
import 'package:fluttertest/pages/inspectPost_page.dart';
import 'package:fluttertest/pages/followers_list.dart';
import 'package:fluttertest/pages/following_list.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:fluttertest/pages/welcome_page.dart';

// Create a global analytics instance
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable analytics collection
  await analytics.setAnalyticsCollectionEnabled(true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF25242A),
        scaffoldBackgroundColor: Color(0xFFFAF8F5),
        barBackgroundColor: Color(0xFFFAF8F5),
        textTheme: CupertinoTextThemeData(
          primaryColor: Color(0xFF25242A),
          textStyle: TextStyle(
            color: Color(0xFF25242A),
            fontFamily: '.SF Pro Text',
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            User? user = snapshot.data;
            if (user == null) {
              return const StartUpPage();
            } else {
              return FutureBuilder<void>(
                future: _initializeUserDocument(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return const MainPage();
                  } else {
                    return const CupertinoActivityIndicator();
                  }
                },
              );
            }
          }
          return const CupertinoActivityIndicator();
        },
      ),
      routes: {
        '/startup': (context) => const StartUpPage(),
        '/main': (context) => const MainPage(),
        '/login': (context) => const LogInPage(),
        '/signup': (context) => const SignUpPage(),
        '/profile': (context) => const ProfilePage(),
        '/newPost': (context) => const NewPostFlow(),
        '/accountSettings': (context) => const AccountSettingsPage(),
        '/friends': (context) => const FriendsPage(),
        '/notifications': (context) => const NotificationsPage(),
        '/searchFriends_page': (context) => const SearchFriendsPage(),
        '/comments': (context) {
          final String postId =
              ModalRoute.of(context)!.settings.arguments as String;
          return CommentsPage(postId: postId);
        },
        '/otherProfile': (context) {
          final String userId =
              ModalRoute.of(context)!.settings.arguments as String;
          return OtherProfilePage(userId: userId);
        },
        '/inspectPost': (context) {
          final String postId =
              ModalRoute.of(context)!.settings.arguments as String;
          return InspectPostPage(postId: postId);
        },
        '/followers': (context) {
          final Map<String, dynamic> args = ModalRoute.of(context)!
              .settings
              .arguments as Map<String, dynamic>;
          return FollowersList(
            userId: args['userId'],
            isCurrentUser: args['isCurrentUser'],
          );
        },
        '/following': (context) {
          final Map<String, dynamic> args = ModalRoute.of(context)!
              .settings
              .arguments as Map<String, dynamic>;
          return FollowingList(
            userId: args['userId'],
            isCurrentUser: args['isCurrentUser'],
          );
        },
        '/welcome': (context) => const WelcomePage(),
      },
    );
  }

  Future<void> _initializeUserDocument(String userId) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'following': [],
        'username':
            FirebaseAuth.instance.currentUser!.displayName ?? 'Unnamed User',
      });
    }
  }
}
