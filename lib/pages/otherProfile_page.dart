import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<String> _followingUsernames = [];
  List<String> _followerUsernames = [];
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

  Future<void> _checkIfFollowing() async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      List<String> following = List<String>.from(currentUserDoc['following'] ?? []);
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
      DocumentReference currentUserDoc = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentReference otherUserDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot currentUserSnapshot = await transaction.get(currentUserDoc);
        DocumentSnapshot otherUserSnapshot = await transaction.get(otherUserDoc);

        List<String> currentUserFollowing = List<String>.from(currentUserSnapshot['following'] ?? []);
        List<String> otherUserFollowers = List<String>.from(otherUserSnapshot['followers'] ?? []);

        if (_isFollowing) {
          currentUserFollowing.remove(widget.userId);
          otherUserFollowers.remove(currentUserId);
        } else {
          currentUserFollowing.add(widget.userId);
          otherUserFollowers.add(currentUserId);
        }

        transaction.update(currentUserDoc, {'following': currentUserFollowing});
        transaction.update(otherUserDoc, {'followers': otherUserFollowers});
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow status')),
      );
    }
  }

  Future _loadUserProfile() async {
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
        _name = '${userDoc['firstName'] ?? 'Unknown'} ${userDoc['lastName'] ?? 'User'}';
        _bio = userDoc['bio'] ?? 'No bio available';
        _username = userDoc['username'] ?? 'No username';
        _profileImageUrl = userDoc['profileImageUrl'];
      });
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future _loadUserPosts() async {
    try {
      QuerySnapshot postDocs = await FirebaseFirestore.instance
          .collection('mealPosts')
          .where('userId', isEqualTo: widget.userId)
          .get();

      setState(() {
        _posts = postDocs.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'mealTitle': data['mealTitle'] ?? 'Untitled Meal',
            'mealDescription': data['mealDescription'] ?? 'No description',
            'imageUrl': data['imageUrl'],
            'postId': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading user posts: $e');
    }
  }

  Future _loadFollowingAndFollowers() async {
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
    }
  }

  Future<void> _loadUsernamesForList(List<String> ids, List<String> usernames) async {
    usernames.clear();
    for (String id in ids) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          usernames.add(userData['username'] ?? 'Unknown User');
        }
      } catch (e) {
        print('Error loading username for $id: $e');
      }
    }
  }

  void _showListDialog(String listType, List<String> usernames, List<String> userIds) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(listType),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: usernames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/otherProfile',
                        arguments: userIds[index],
                      );
                    },
                    child: Text(usernames[index]),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_username),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: _profileImageUrl != null 
                  ? NetworkImage(_profileImageUrl!)
                  : null,
                child: _profileImageUrl == null
                    ? Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _name,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 5),
            Text(
              '$_username',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              _bio,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleFollow,
              child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => _showListDialog('Following', _followingUsernames, _following),
                  child: Column(
                    children: [
                      Text(
                        'Following',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        '${_following.length}',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showListDialog('Followers', _followerUsernames, _followers),
                  child: Column(
                    children: [
                      Text(
                        'Followers',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        '${_followers.length}',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Posts (${_posts.length})',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/inspectPost',
                          arguments: _posts[index]['postId'],
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_posts[index]['imageUrl'] != null && _posts[index]['imageUrl'].isNotEmpty)
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(_posts[index]['imageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ListTile(
                            title: Text(_posts[index]['mealTitle']),
                            subtitle: Text(_posts[index]['mealDescription']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
