import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertest/pages/searchFriends_page.dart';
import 'package:fluttertest/pages/comments_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class FriendsPage extends StatefulWidget {
  const FriendsPage({Key? key}) : super(key: key);

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _following = [];
  List<Map<String, dynamic>> _mealPosts = [];
  final String _followingCacheKey = 'following_cache';
  final String _postsDataCacheKey = 'posts_cache';

  @override
  void initState() {
    super.initState();
    _loadFollowingAndPosts();
  }

  Future<void> _loadFollowingAndPosts() async {
    await _loadFollowing();
    await _loadFriendsMealPosts();
  }

  Future<void> _loadFollowing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedFollowing = prefs.getStringList(_followingCacheKey);
      
      if (cachedFollowing != null && mounted) {
        setState(() {
          _following = cachedFollowing;
        });
      }

      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (mounted) {
        final following = List<String>.from(userDoc['following'] ?? []);
        setState(() {
          _following = following;
        });
        
        await prefs.setStringList(_followingCacheKey, following);
      }
    } catch (e) {
      print("Error loading following list: $e");
      if (mounted) {
        _showErrorMessage("Failed to load following list.");
      }
    }
  }

  Future<void> _loadFriendsMealPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPosts = prefs.getString(_postsDataCacheKey);
      
      if (cachedPosts != null && mounted) {
        final decodedPosts = List<Map<String, dynamic>>.from(
          jsonDecode(cachedPosts).map((x) => Map<String, dynamic>.from(x))
        );
        setState(() {
          _mealPosts = decodedPosts;
        });
      }

      if (_following.isNotEmpty) {
        List<Map<String, dynamic>> allPosts = [];
        for (int i = 0; i < _following.length; i += 10) {
          var chunk = _following.sublist(
            i,
            i + 10 > _following.length ? _following.length : i + 10,
          );

          QuerySnapshot mealPostsSnapshot = await FirebaseFirestore.instance
              .collection('mealPosts')
              .where('userId', whereIn: chunk)
              .get();

          allPosts.addAll(
            mealPostsSnapshot.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String timestamp = data['timestamp'] != null 
                  ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
                  : DateTime.now().toIso8601String();
                
              return {
                'id': doc.id,
                'userId': data['userId'] ?? 'Unknown',
                'mealDescription': data['mealDescription'] ?? 'No Description',
                'mealTitle': data['mealTitle'] ?? 'No Title',
                'imageUrls': data['imageUrls'] ?? [],
                'likes': data['likes'] ?? [],
                'comments': data['comments'] ?? [],
                'timestamp': timestamp,
              };
            }).toList(),
          );
        }

        if (mounted) {
          allPosts.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
          setState(() {
            _mealPosts = allPosts;
          });
          await prefs.setString(_postsDataCacheKey, jsonEncode(allPosts));
        }
      }
    } catch (e) {
      print("Error loading friends' meal posts: $e");
      if (mounted && _mealPosts.isEmpty) {
        _showErrorMessage("Failed to load meal posts. Please try again.");
      }
    }
  }

  Future<void> _likePost(String postId) async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      DocumentReference postRef = FirebaseFirestore.instance.collection('mealPosts').doc(postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        List<dynamic> likes = List.from(postSnapshot['likes'] ?? []);

        if (likes.contains(currentUserId)) {
          likes.remove(currentUserId);
        } else {
          likes.add(currentUserId);
        }

        transaction.update(postRef, {
          'likes': likes,
        });

        setState(() {
          int postIndex = _mealPosts.indexWhere((post) => post['id'] == postId);
          if (postIndex != -1) {
            _mealPosts[postIndex]['likes'] = likes;
          }
        });
      });
    } catch (e) {
      print("Error liking/unliking post: $e");
      _showErrorMessage("Failed to like/unlike post. Please try again.");
    }
  }

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFAF8F5),
        middle: const Text('Feed'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.search,
            color: Color(0xFF25242A),
          ),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const SearchFriendsPage()),
            );
          },
        ),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _loadFollowingAndPosts,
          ),
          SliverToBoxAdapter(
            child: _mealPosts.isEmpty
                ? Container(
                    padding: const EdgeInsets.only(top: 100),
                    child: const Center(
                      child: Text(
                        'No meal posts from friends yet.',
                        style: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: _mealPosts.map((post) {
                        final timestamp = DateTime.parse(post['timestamp'] as String);
                        return _buildPostCard(post, timestamp);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(post['userId'])
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CupertinoActivityIndicator();
                      }
                      if (snapshot.hasData && snapshot.data!.exists) {
                        var userData = snapshot.data!.data() as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/otherProfile',
                            arguments: post['userId'],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: userData['profileImageUrl'] != null
                                      ? DecorationImage(
                                          image: NetworkImage(userData['profileImageUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: userData['profileImageUrl'] == null
                                    ? const Icon(CupertinoIcons.person_fill)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userData['username'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF25242A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const Text('Unknown User');
                    },
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: (post['imageUrls'] as List).length,
                itemBuilder: (context, imageIndex) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post['imageUrls'][imageIndex],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            color: CupertinoColors.systemGrey,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['mealTitle'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF25242A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post['mealDescription'],
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        post['likes'].contains(_auth.currentUser!.uid)
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: post['likes'].contains(_auth.currentUser!.uid)
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemGrey,
                      ),
                      onPressed: () => _likePost(post['id']),
                    ),
                    Text('${post['likes'].length}'),
                    const SizedBox(width: 16),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.chat_bubble,
                        color: CupertinoColors.systemGrey,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => CommentsPage(postId: post['id']),
                          ),
                        );
                      },
                    ),
                    Text('${post['comments'].length}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}