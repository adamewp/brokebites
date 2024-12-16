import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchFriendsPage extends StatefulWidget {
  const SearchFriendsPage({Key? key}) : super(key: key);

  @override
  _SearchFriendsPageState createState() => _SearchFriendsPageState();
}

class _SearchFriendsPageState extends State<SearchFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  Map<String, String> _followStatus = {};
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        currentUserId = currentUser.uid;
      });
      await _fetchFollowingList();
    }
  }

  Future<void> _fetchFollowingList() async {
    try {
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (currentUserSnapshot.exists) {
        List<dynamic> following = currentUserSnapshot['following'] ?? [];
        setState(() {
          for (var userId in following) {
            _followStatus[userId] = "Following";
          }
        });
      }
    } catch (e) {
      print("Error fetching following list: $e");
    }
  }

  Future<void> _searchUsers() async {
    try {
      if (_searchQuery.isNotEmpty) {
        String searchTerm = _searchQuery.toLowerCase();
        
        // Query users where username or name contains the search term
        QuerySnapshot userDocs = await FirebaseFirestore.instance
            .collection('users')
            .get();

        if (mounted) {
          setState(() {
            _searchResults = userDocs.docs
                .where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (doc.exists && data != null && data['userId'] != currentUserId) {
                    String username = (data['username'] ?? '').toLowerCase();
                    String firstName = (data['firstName'] ?? '').toLowerCase();
                    String lastName = (data['lastName'] ?? '').toLowerCase();
                    return username.contains(searchTerm) || 
                           firstName.contains(searchTerm) || 
                           lastName.contains(searchTerm);
                  }
                  return false;
                })
                .map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return {
                    'userId': data['userId'],
                    'username': data['username'],
                    'profileImageUrl': data['profileImageUrl'],
                    'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
                  };
                })
                .toList();
          });
        }
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      print("Error searching users: $e");
    }
  }

  Future<void> _followUser(String userIdToFollow) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in");
        return;
      }

      String currentUserId = currentUser.uid;
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (!currentUserSnapshot.exists) {
        print("Current user does not exist in Firestore");
        return;
      }

      List<dynamic> following = currentUserSnapshot['following'] ?? [];

      if (!following.contains(userIdToFollow)) {
        following.add(userIdToFollow);

        await currentUserRef.update({
          'following': following,
        });

        DocumentReference followedUserRef = FirebaseFirestore.instance.collection('users').doc(userIdToFollow);
        await followedUserRef.update({
          'followers': FieldValue.arrayUnion([currentUserId]),
        });

        setState(() {
          _followStatus[userIdToFollow] = "Following";
        });
      }
    } catch (e) {
      print("Error following user: $e");
    }
  }

  Future<void> _unfollowUser(String userIdToUnfollow) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in");
        return;
      }

      String currentUserId = currentUser.uid;
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (!currentUserSnapshot.exists) {
        print("Current user does not exist in Firestore");
        return;
      }

      List<dynamic> following = currentUserSnapshot['following'] ?? [];

      if (following.contains(userIdToUnfollow)) {
        following.remove(userIdToUnfollow);

        await currentUserRef.update({
          'following': following,
        });

        DocumentReference followedUserRef = FirebaseFirestore.instance.collection('users').doc(userIdToUnfollow);
        await followedUserRef.update({
          'followers': FieldValue.arrayRemove([currentUserId]),
        });

        setState(() {
          _followStatus[userIdToUnfollow] = "Follow";
        });
      }
    } catch (e) {
      print("Error unfollowing user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Search Friends'),
        backgroundColor: const Color(0xFFFAF8F5),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                onSubmitted: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                  _searchUsers();
                },
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                  _searchUsers();
                },
              ),
            ),
            Expanded(
              child: _searchResults.isNotEmpty
                  ? ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        String userId = user['userId'];
                        bool isFollowing = _followStatus[userId] == "Following";

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                                  image: user['profileImageUrl'] != null
                                      ? DecorationImage(
                                          image: NetworkImage(user['profileImageUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: user['profileImageUrl'] == null
                                      ? CupertinoColors.systemGrey
                                      : null,
                                ),
                                child: user['profileImageUrl'] == null
                                    ? Center(
                                        child: Text(
                                          (user['username'] ?? 'U')[0].toUpperCase(),
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
                                      user['username'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF25242A),
                                      ),
                                    ),
                                    if (user['name'].isNotEmpty)
                                      Text(
                                        user['name'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: isFollowing
                                    ? () => _unfollowUser(userId)
                                    : () => _followUser(userId),
                                child: Text(
                                  isFollowing ? "Following" : "Follow",
                                  style: TextStyle(
                                    color: isFollowing
                                        ? CupertinoColors.systemGrey
                                        : CupertinoColors.activeBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(color: CupertinoColors.label),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}