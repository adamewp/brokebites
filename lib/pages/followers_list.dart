import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowersList extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const FollowersList({
    super.key,
    required this.userId,
    required this.isCurrentUser,
  });

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
          Map<String, dynamic> userData =
              followerDoc.data() as Map<String, dynamic>;
          followerDetails.add({
            'userId': followerId,
            'username': userData['username'] ?? 'Unknown User',
            'profileImageUrl': userData['profileImageUrl'],
            'name':
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                    .trim(),
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
      _showErrorMessage('Failed to load followers list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.isCurrentUser ? 'My Followers' : 'Followers'),
        backgroundColor: const Color(0xFFFAF8F5),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView.builder(
                itemCount: _followers.length,
                itemBuilder: (context, index) {
                  final follower = _followers[index];
                  return GestureDetector(
                    onTap: () {
                      if (follower['userId'] !=
                          FirebaseAuth.instance.currentUser?.uid) {
                        Navigator.pushNamed(
                          context,
                          '/otherProfile',
                          arguments: follower['userId'],
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.systemGrey.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: follower['profileImageUrl'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          follower['profileImageUrl']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: follower['profileImageUrl'] == null
                                  ? CupertinoColors.systemGrey
                                  : null,
                            ),
                            child: follower['profileImageUrl'] == null
                                ? Center(
                                    child: Text(
                                      (follower['username'] ?? 'U')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  follower['username'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF25242A),
                                  ),
                                ),
                                if (follower['name'].isNotEmpty)
                                  Text(
                                    follower['name'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: CupertinoColors.systemGrey,
                            size: 20,
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
}
