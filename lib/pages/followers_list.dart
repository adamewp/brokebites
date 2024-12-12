import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowersList extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const FollowersList({
    Key? key, 
    required this.userId,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  _FollowersListState createState() => _FollowersListState();
}

class _FollowersListState extends State<FollowersList> {
  List<Map<String, dynamic>> _followers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      // Get the user's followers list
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      List<String> followerIds = List<String>.from(userDoc['followers'] ?? []);

      // Get details for each follower
      List<Map<String, dynamic>> followerDetails = [];
      for (String followerId in followerIds) {
        DocumentSnapshot followerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(followerId)
            .get();

        if (followerDoc.exists) {
          Map<String, dynamic> userData = followerDoc.data() as Map<String, dynamic>;
          followerDetails.add({
            'userId': followerId,
            'username': userData['username'] ?? 'Unknown User',
            'profileImageUrl': userData['profileImageUrl'],
            'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          });
        }
      }

      setState(() {
        _followers = followerDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading followers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCurrentUser ? 'My Followers' : 'Followers'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _followers.length,
              itemBuilder: (context, index) {
                final follower = _followers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: follower['profileImageUrl'] != null
                        ? NetworkImage(follower['profileImageUrl'])
                        : null,
                    child: follower['profileImageUrl'] == null
                        ? Icon(Icons.person)
                        : null,
                  ),
                  title: Text(follower['username']),
                  subtitle: Text(follower['name']),
                  onTap: () {
                    if (follower['userId'] != FirebaseAuth.instance.currentUser?.uid) {
                      Navigator.pushNamed(
                        context,
                        '/otherProfile',
                        arguments: follower['userId'],
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
