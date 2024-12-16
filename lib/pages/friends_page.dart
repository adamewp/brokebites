import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertest/pages/searchFriends_page.dart';
import 'package:fluttertest/pages/comments_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart' show CircleAvatar;


class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final List<Map<String, dynamic>> _mealPosts = [];
  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _following = [];

  @override
  void initState() {
    super.initState();
    _loadFollowingAndPosts();
  }

  Future<void> _loadPosts() async {
    try {
      // First load following list
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!userDoc.exists) return;

      _following = List<String>.from(userDoc.data()?['following'] ?? []);
      
      // Add current user's ID to the list of IDs to query
      List<String> userIdsToQuery = [..._following];
      userIdsToQuery.add(_auth.currentUser!.uid);

      // Then load posts from following users AND current user
      final QuerySnapshot postDocs = await FirebaseFirestore.instance
          .collection('mealPosts')
          .where('userId', whereIn: userIdsToQuery)  // Use the combined list
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final posts = postDocs.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'postId': doc.id,
          'userId': data['userId'],
          'mealTitle': data['mealTitle'],
          'mealDescription': data['mealDescription'],
          'imageUrls': data['imageUrls'],
          'timestamp': data['timestamp'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _mealPosts.clear();
          _mealPosts.addAll(posts);
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      rethrow;
    }
  }

  Future<void> _loadFollowingAndPosts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadPosts();
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to load posts'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPostImage(String? imageUrl) {
    // Check if imageUrl is null, empty, or invalid
    if (imageUrl == null || imageUrl.isEmpty || !Uri.parse(imageUrl).isAbsolute) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 40,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CupertinoActivityIndicator(
              radius: 20,
              color: CupertinoColors.systemGrey.withOpacity(0.6),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: CupertinoColors.systemGrey6,
            child: const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 40,
                color: CupertinoColors.systemGrey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final timestamp = post['timestamp'] is DateTime 
        ? post['timestamp'] as DateTime
        : (post['timestamp'] as Timestamp).toDate();

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // Navigate to inspect post page
        Navigator.pushNamed(
          context,
          '/inspectPost',
          arguments: post['postId'],
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: post['userId'] != FirebaseAuth.instance.currentUser?.uid
                        ? () {
                            // Navigate to other profile page
                            Navigator.pushNamed(
                              context,
                              '/otherProfile',
                              arguments: post['userId'],
                            );
                          }
                        : null,
                    child: Row(
                      children: [
                        _buildUserAvatar(post['userId']),
                        const SizedBox(width: 8),
                        _buildUserInfo(post['userId']),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _getTimeAgo(timestamp),
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (post['imageUrls'] != null && 
                (post['imageUrls'] as List).isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: (post['imageUrls'] as List).length,
                  itemBuilder: (context, index) {
                    final imageUrl = post['imageUrls'][index];
                    return _buildPostImage(imageUrl);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['mealTitle'] ?? 'Untitled Meal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (post['mealDescription'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        post['mealDescription'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircleAvatar(
            radius: 20,
            backgroundColor: CupertinoColors.systemGrey5,
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final profileImageUrl = userData['profileImageUrl'] as String?;

        if (profileImageUrl == null || profileImageUrl.isEmpty) {
          return const CircleAvatar(
            radius: 20,
            backgroundColor: CupertinoColors.systemGrey5,
            child: Icon(
              CupertinoIcons.person_fill,
              color: CupertinoColors.systemGrey2,
            ),
          );
        }

        return CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(profileImageUrl),
          onBackgroundImageError: (_, __) {
            print('Error loading profile image');  // Just log the error
          },
        );
      },
    );
  }

  Widget _buildUserInfo(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CupertinoActivityIndicator();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userData['username'] ?? 'Unknown User',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFAF8F5),
        middle: const Text('Feed'),
        transitionBetweenRoutes: false,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.search),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const SearchFriendsPage(),
              ),
            );
          },
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _loadFollowingAndPosts,
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 8.0,
                    right: 8.0,
                    top: 8.0,
                    bottom: 85.0,
                  ),
                  sliver: _mealPosts.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No posts yet',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildPostCard(_mealPosts[index]),
                            childCount: _mealPosts.length,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}