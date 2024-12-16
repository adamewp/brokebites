import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId;

  const OtherProfilePage({super.key, required this.userId});

  @override
  _OtherProfilePageState createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _name = '';
  String _bio = '';
  String _username = '';
  List<Map<String, dynamic>> _posts = [];
  List<String> _following = [];
  List<String> _followers = [];
  final List<String> _followingUsernames = [];
  final List<String> _followerUsernames = [];
  String? _profileImageUrl;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserPosts();
    _loadFollowingAndFollowers();
    _checkIfFollowing();
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

  Future<void> _checkIfFollowing() async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      List<String> following =
          List<String>.from(currentUserDoc['following'] ?? []);
      setState(() {
        _isFollowing = following.contains(widget.userId);
      });
    } catch (e) {
      print('Error checking following status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      DocumentReference currentUserDoc =
          FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentReference otherUserDoc =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot currentUserSnapshot =
            await transaction.get(currentUserDoc);
        DocumentSnapshot otherUserSnapshot =
            await transaction.get(otherUserDoc);

        List<String> currentUserFollowing =
            List<String>.from(currentUserSnapshot['following'] ?? []);
        List<String> otherUserFollowers =
            List<String>.from(otherUserSnapshot['followers'] ?? []);

        bool isFollowing = !_isFollowing;

        if (_isFollowing) {
          currentUserFollowing.remove(widget.userId);
          otherUserFollowers.remove(currentUserId);
        } else {
          currentUserFollowing.add(widget.userId);
          otherUserFollowers.add(currentUserId);
        }

        transaction.update(currentUserDoc, {'following': currentUserFollowing});
        transaction.update(otherUserDoc, {'followers': otherUserFollowers});

        if (isFollowing) {
          await NotificationService.createFollowNotification(
            followerId: currentUserId,
            followedUserId: widget.userId,
          );
        }
      });

      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followers.add(currentUserId);
        } else {
          _followers.remove(currentUserId);
        }
      });

      _loadFollowingAndFollowers();
    } catch (e) {
      print('Error toggling follow: $e');
      _showErrorMessage('Failed to update follow status');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        print('User document does not exist');
        return;
      }

      setState(() {
        _name =
            '${userDoc['firstName'] ?? 'Unknown'} ${userDoc['lastName'] ?? 'User'}';
        _bio = userDoc['bio'] ?? 'No bio available';
        _username = userDoc['username'] ?? 'No username';
        _profileImageUrl = userDoc['profileImageUrl'];
      });
    } catch (e) {
      print('Error loading user profile: $e');
      _showErrorMessage('Error loading user profile');
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      QuerySnapshot postDocs = await FirebaseFirestore.instance
          .collection('mealPosts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _posts = postDocs.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'postId': doc.id,
            'mealTitle': data['mealTitle'] ?? 'Untitled Meal',
            'mealDescription': data['mealDescription'] ?? 'No description',
            'imageUrls': data['imageUrls'] ?? [],
            'timestamp': data['timestamp'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading user posts: $e');
      _showErrorMessage('Failed to load posts');
    }
  }

  Future<void> _loadFollowingAndFollowers() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        print('User document does not exist');
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      setState(() {
        _following = List<String>.from(userData['following'] ?? []);
        _followers = List<String>.from(userData['followers'] ?? []);
      });

      await _loadUsernamesForList(_following, _followingUsernames);
      await _loadUsernamesForList(_followers, _followerUsernames);
    } catch (e) {
      print('Error loading following and followers: $e');
      _showErrorMessage('Error loading following and followers');
    }
  }

  Future<void> _loadUsernamesForList(
      List<String> ids, List<String> usernames) async {
    usernames.clear();
    for (String id in ids) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          usernames.add(userData['username'] ?? 'Unknown User');
        }
      } catch (e) {
        print('Error loading username for $id: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        middle: Text(_username),
        backgroundColor: const Color(0xFFFAF8F5),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoColors.systemGrey.withOpacity(0.3),
                      image: _profileImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImageUrl == null
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            size: 50,
                            color: CupertinoColors.systemGrey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF25242A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _username,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _bio,
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey.darkColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CupertinoButton(
                  onPressed: _toggleFollow,
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isFollowing
                          ? CupertinoColors.systemGrey6
                          : CupertinoColors.activeBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: _isFollowing
                            ? CupertinoColors.black
                            : CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/following',
                        arguments: {
                          'userId': widget.userId,
                          'isCurrentUser': false,
                        },
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Following',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF25242A),
                            ),
                          ),
                          Text(
                            '${_following.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/followers',
                        arguments: {
                          'userId': widget.userId,
                          'isCurrentUser': false,
                        },
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Followers',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF25242A),
                            ),
                          ),
                          Text(
                            '${_followers.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Posts (${_posts.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF25242A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/inspectPost',
                          arguments: _posts[index]['postId'],
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  CupertinoColors.systemGrey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_posts[index]['imageUrls'] != null &&
                                (_posts[index]['imageUrls'] as List).isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                height: 300,
                                child: PageView.builder(
                                  itemCount:
                                      (_posts[index]['imageUrls'] as List)
                                          .length,
                                  itemBuilder: (context, imageIndex) {
                                    return Image.network(
                                      _posts[index]['imageUrls'][imageIndex],
                                      width: double.infinity,
                                      height: 300,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _posts[index]['mealTitle'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF25242A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _posts[index]['mealDescription'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
