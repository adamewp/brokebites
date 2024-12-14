import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertest/pages/comments_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InspectPostPage extends StatefulWidget {
  final String postId;

  const InspectPostPage({super.key, required this.postId});

  @override
  _InspectPostPageState createState() => _InspectPostPageState();
}

class _InspectPostPageState extends State<InspectPostPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _postData;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadPostData();
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

  Future<void> _loadPostData() async {
    try {
      DocumentSnapshot postDoc = await FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId)
          .get();

      if (!postDoc.exists) {
        _showErrorMessage('Post not found');
        Navigator.pop(context);
        return;
      }

      var postData = postDoc.data() as Map<String, dynamic>;
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(postData['userId'])
          .get();

      setState(() {
        _postData = postData;
        _userData = userDoc.data() as Map<String, dynamic>;
      });
    } catch (e) {
      print('Error loading post data: $e');
      _showErrorMessage('Error loading post');
    }
  }

  Future<void> _likePost() async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      DocumentReference postRef = FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        List<dynamic> likes = List.from(postSnapshot['likes'] ?? []);

        if (likes.contains(currentUserId)) {
          likes.remove(currentUserId);
        } else {
          likes.add(currentUserId);
        }

        transaction.update(postRef, {'likes': likes});

        setState(() {
          _postData!['likes'] = likes;
        });
      });
    } catch (e) {
      print('Error liking/unliking post: $e');
      _showErrorMessage('Failed to update like');
    }
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

  Widget _buildIngredientsList() {
    if (_postData!['ingredients'] == null || (_postData!['ingredients'] as List).isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No ingredients available.',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingredients',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF25242A),
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (_postData!['ingredients'] as List).length,
            itemBuilder: (context, index) {
              final ingredient = _postData!['ingredients'][index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ingredient['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF25242A),
                        ),
                      ),
                    ),
                    Text(
                      '${ingredient['amount']} ${ingredient['unit']}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_postData == null || _userData == null) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Post'),
          backgroundColor: Color(0xFFFAF8F5),
        ),
        backgroundColor: Color(0xFFFAF8F5),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final timestamp = _postData!['timestamp'] is DateTime
        ? (_postData!['timestamp'] as DateTime)
        : (_postData!['timestamp'] as Timestamp).toDate();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Post'),
        backgroundColor: Color(0xFFFAF8F5),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_postData!['userId'] != _auth.currentUser!.uid) {
                          Navigator.pushNamed(context, '/otherProfile', arguments: _postData!['userId']);
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: _userData!['profileImageUrl'] != null
                              ? DecorationImage(
                                  image: NetworkImage(_userData!['profileImageUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: _userData!['profileImageUrl'] == null
                              ? CupertinoColors.systemGrey
                              : null,
                        ),
                        child: _userData!['profileImageUrl'] == null
                            ? Center(
                                child: Text(
                                  (_userData!['username'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_postData!['userId'] != _auth.currentUser!.uid) {
                          Navigator.pushNamed(context, '/otherProfile',
                              arguments: _postData!['userId']);
                        }
                      },
                      child: Text(
                        _userData!['username'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF25242A),
                        ),
                      ),
                    ),
                    const Spacer(),
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
              if (_postData!['imageUrls'] != null &&
                  (_postData!['imageUrls'] as List).isNotEmpty)
                AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    itemCount: (_postData!['imageUrls'] as List).length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: _postData!['imageUrls'][index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CupertinoActivityIndicator()),
                        errorWidget: (context, url, error) =>
                            const Icon(CupertinoIcons.exclamationmark_triangle),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _likePost,
                      child: Icon(
                        (_postData!['likes'] ?? []).contains(_auth.currentUser!.uid)
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        size: 28,
                        color: (_postData!['likes'] ?? []).contains(_auth.currentUser!.uid)
                            ? CupertinoColors.systemRed
                            : const Color(0xFF25242A),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.chat_bubble,
                        size: 28,
                        color: Color(0xFF25242A),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => CommentsPage(postId: widget.postId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${(_postData!['likes'] ?? []).length} likes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF25242A),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF25242A)),
                    children: [
                      TextSpan(
                        text: '${_userData!['username']} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: _postData!['mealTitle'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '\n'),
                      TextSpan(
                        text: _postData!['mealDescription'] ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              _buildIngredientsList(),
            ],
          ),
        ),
      ),
    );
  }
}
