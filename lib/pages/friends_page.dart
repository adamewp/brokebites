import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load following list.")),
      );
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
          setState(() {
            _mealPosts = allPosts;
          });
          
          await prefs.setString(_postsDataCacheKey, jsonEncode(allPosts));
        }
      }
    } catch (e) {
      print("Error loading friends' meal posts: $e");
      if (mounted && _mealPosts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load meal posts. Please try again.")),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to like/unlike post. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchFriendsPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFollowingAndPosts,
        child: _mealPosts.isEmpty
            ? ListView(  // Wrap with ListView to make RefreshIndicator work when empty
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Text('No meal posts from friends yet.'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _mealPosts.length,
                itemBuilder: (context, index) {
                  final post = _mealPosts[index];
                  final timestamp = DateTime.parse(post['timestamp'] as String);

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/inspectPost',
                          arguments: post['id'],
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                      return const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Loading...'),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Error loading username'),
                                      );
                                    }
                                    if (snapshot.hasData && snapshot.data!.exists) {
                                      var userData = snapshot.data!.data() as Map<String, dynamic>;
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/otherProfile',
                                                  arguments: post['userId'],
                                                );
                                              },
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.grey[300],
                                                backgroundImage: userData['profileImageUrl'] != null && 
                                                               userData['profileImageUrl'].toString().isNotEmpty
                                                        ? NetworkImage(userData['profileImageUrl'])
                                                        : null,
                                                child: userData['profileImageUrl'] == null || 
                                                       userData['profileImageUrl'].toString().isEmpty
                                                        ? Text(
                                                            (userData['username'] ?? 'U')[0].toUpperCase(),
                                                            style: const TextStyle(color: Colors.black54),
                                                          )
                                                        : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/otherProfile',
                                                    arguments: post['userId'],
                                                  );
                                                },
                                                child: Text(
                                                  userData['username'] ?? 'Unknown User',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Unknown User'),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _formatTimestamp(timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              post['mealTitle'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(post['mealDescription']),
                          ),
                          if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty)
                            Container(
                              height: 300,
                              child: PageView.builder(
                                itemCount: (post['imageUrls'] as List).length,
                                itemBuilder: (context, imageIndex) {
                                  return Image.network(
                                    post['imageUrls'][imageIndex],
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  post['likes'].contains(_auth.currentUser!.uid)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: post['likes'].contains(_auth.currentUser!.uid)
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                onPressed: () => _likePost(post['id']),
                              ),
                              Text('${post['likes'].length}'),
                              IconButton(
                                icon: const Icon(Icons.comment),
                                onPressed: () {
                                  // Navigate to the CommentsPage, passing the postId
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
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
                  );
                },
              ),
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