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
        String searchTerm = _searchQuery.startsWith('@') 
            ? _searchQuery.substring(1).toLowerCase() 
            : _searchQuery.toLowerCase();
        
        QuerySnapshot userDocs = await FirebaseFirestore.instance
            .collection('users')
            .orderBy('username')
            .startAt([searchTerm])
            .endAt(['$searchTerm\uf8ff'])
            .limit(10)
            .get();

        if (mounted) {
          setState(() {
            _searchResults = userDocs.docs
                .where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return doc.exists && data != null && data.containsKey('userId') && data['userId'] != currentUserId;
                })
                .map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return {
                    'userId': data['userId'],
                    'username': data['username'],
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Search Friends'),
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
                        String userId = _searchResults[index]['userId'];
                        bool isFollowing = _followStatus[userId] == "Following";

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: CupertinoColors.separator,
                                width: 0.0,
                              ),
                            ),
                          ),
                          child: CupertinoListTile(
                            title: Text(
                              '@${_searchResults[index]['username']}',
                              style: const TextStyle(
                                color: CupertinoColors.label,
                              ),
                            ),
                            trailing: CupertinoButton(
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