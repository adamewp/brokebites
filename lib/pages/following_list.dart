import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingList extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const FollowingList({
    Key? key, 
    required this.userId,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  _FollowingListState createState() => _FollowingListState();
}

class _FollowingListState extends State<FollowingList> {
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      // Get the user's following list
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      List<String> followingIds = List<String>.from(userDoc['following'] ?? []);

      // Get details for each following user
      List<Map<String, dynamic>> followingDetails = [];
      for (String followingId in followingIds) {
        DocumentSnapshot followingDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(followingId)
            .get();

        if (followingDoc.exists) {
          Map<String, dynamic> userData = followingDoc.data() as Map<String, dynamic>;
          followingDetails.add({
            'userId': followingId,
            'username': userData['username'] ?? 'Unknown User',
            'profileImageUrl': userData['profileImageUrl'],
            'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          });
        }
      }

      setState(() {
        _following = followingDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading following: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCurrentUser ? 'My Following' : 'Following'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _following.length,
              itemBuilder: (context, index) {
                final following = _following[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: following['profileImageUrl'] != null
                        ? NetworkImage(following['profileImageUrl'])
                        : null,
                    child: following['profileImageUrl'] == null
                        ? Icon(Icons.person)
                        : null,
                  ),
                  title: Text(following['username']),
                  subtitle: Text(following['name']),
                  onTap: () {
                    if (following['userId'] != FirebaseAuth.instance.currentUser?.uid) {
                      Navigator.pushNamed(
                        context,
                        '/otherProfile',
                        arguments: following['userId'],
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
    );
  }
}
