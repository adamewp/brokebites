import 'package:flutter/material.dart';
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
  Map<String, String> _followStatus = {}; // Track follow status
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  // Get current user's ID to fetch their following list
  Future<void> _getCurrentUserId() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        currentUserId = currentUser.uid;
      });
      await _fetchFollowingList();
    }
  }

  // Fetch the current user's following list
  Future<void> _fetchFollowingList() async {
    try {
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (currentUserSnapshot.exists) {
        List<dynamic> following = currentUserSnapshot['following'] ?? [];
        setState(() {
          for (var userId in following) {
            _followStatus[userId] = "Following"; // Set status to "Following"
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
        // Remove @ if user included it in search
        String searchTerm = _searchQuery.startsWith('@') 
            ? _searchQuery.substring(1) 
            : _searchQuery;
        
        QuerySnapshot userDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: searchTerm)
            .where('username', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .get();

        if (mounted) {
          setState(() {
            _searchResults = userDocs.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return {
                'userId': doc['userId'],
                'username': data['username'], // Stored without @
              };
            }).toList();
          });
        }
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

      // Check if the current user is already following this user
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (!currentUserSnapshot.exists) {
        print("Current user does not exist in Firestore");
        return;
      }

      List<dynamic> following = currentUserSnapshot['following'] ?? [];

      // If the user is not already followed, add the user to the following list
      if (!following.contains(userIdToFollow)) {
        following.add(userIdToFollow);

        await currentUserRef.update({
          'following': following,
        });

        // Optionally, you can also update the user's follower list
        DocumentReference followedUserRef = FirebaseFirestore.instance.collection('users').doc(userIdToFollow);
        await followedUserRef.update({
          'followers': FieldValue.arrayUnion([currentUserId]),
        });

        setState(() {
          // Update follow status to "Following" for the user
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

      // Check if the current user is following this user
      DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      DocumentSnapshot currentUserSnapshot = await currentUserRef.get();

      if (!currentUserSnapshot.exists) {
        print("Current user does not exist in Firestore");
        return;
      }

      List<dynamic> following = currentUserSnapshot['following'] ?? [];

      // If the user is already following, remove the user from the following list
      if (following.contains(userIdToUnfollow)) {
        following.remove(userIdToUnfollow);

        await currentUserRef.update({
          'following': following,
        });

        // Optionally, you can also update the user's follower list
        DocumentReference followedUserRef = FirebaseFirestore.instance.collection('users').doc(userIdToUnfollow);
        await followedUserRef.update({
          'followers': FieldValue.arrayRemove([currentUserId]),
        });

        setState(() {
          // Update follow status to "Follow" for the user
          _followStatus[userIdToUnfollow] = "Follow";
        });
      }
    } catch (e) {
      print("Error unfollowing user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text.trim();
                    });
                    _searchUsers();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _searchResults.isNotEmpty
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      String userId = _searchResults[index]['userId'];
                      bool isFollowing = _followStatus[userId] == "Following";

                      return ListTile(
                        title: Text('@${_searchResults[index]['username']}'), // Add @ when displaying
                        trailing: ElevatedButton(
                          onPressed: isFollowing
                              ? () => _unfollowUser(userId)
                              : () => _followUser(userId),
                          child: Text(isFollowing ? "Following" : "Follow"),
                        ),
                      );
                    },
                  )
                : Center(child: const Text('No users found.')),
          ),
        ],
      ),
    );
  }
}
