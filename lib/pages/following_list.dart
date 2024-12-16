import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingList extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const FollowingList({
    super.key,
    required this.userId,
    required this.isCurrentUser,
  });

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
          Map<String, dynamic> userData =
              followingDoc.data() as Map<String, dynamic>;
          followingDetails.add({
            'userId': followingId,
            'username': userData['username'] ?? 'Unknown User',
            'profileImageUrl': userData['profileImageUrl'],
            'name':
                '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                    .trim(),
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
      _showErrorMessage('Failed to load following list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.isCurrentUser ? 'My Following' : 'Following'),
        backgroundColor: const Color(0xFFFAF8F5),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView.builder(
                itemCount: _following.length,
                itemBuilder: (context, index) {
                  final following = _following[index];
                  return GestureDetector(
                    onTap: () {
                      if (following['userId'] !=
                          FirebaseAuth.instance.currentUser?.uid) {
                        Navigator.pushNamed(
                          context,
                          '/otherProfile',
                          arguments: following['userId'],
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
                              image: following['profileImageUrl'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          following['profileImageUrl']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: following['profileImageUrl'] == null
                                  ? CupertinoColors.systemGrey
                                  : null,
                            ),
                            child: following['profileImageUrl'] == null
                                ? Center(
                                    child: Text(
                                      (following['username'] ?? 'U')[0]
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
                                  following['username'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF25242A),
                                  ),
                                ),
                                if (following['name'].isNotEmpty)
                                  Text(
                                    following['name'],
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
