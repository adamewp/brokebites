import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
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
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserPosts();
    _loadFollowingAndFollowers();
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/startup');
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  Future _loadUserProfile() async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

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
      String userId = _auth.currentUser!.uid;
      QuerySnapshot postDocs = await FirebaseFirestore.instance
          .collection('mealPosts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _posts = postDocs.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'mealTitle': data['mealTitle'] ?? 'Untitled Meal',
            'mealDescription': data['mealDescription'] ?? 'No description',
            'imageUrls': data['imageUrls'],
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
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

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
    for (String id in ids) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          usernames.add(userData['username'] ?? 'Unknown User');
        }
      } catch (e) {
        print('Error loading username for $id: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        
        String userId = _auth.currentUser!.uid;
        Reference ref = _storage.ref().child('profile_images').child('$userId.jpg');
        await ref.putFile(_profileImage!);
        
        String downloadUrl = await ref.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'profileImageUrl': downloadUrl,
        });
        
        setState(() {
          _profileImageUrl = downloadUrl;
        });
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile picture'))
      );
    }
  }

  void _showListDialog(String listType, List<String> usernames) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$listType'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: usernames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(usernames[index]),
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

  Future<void> _deletePost(String postId) async {
    try {
      // Get the post data first
      DocumentSnapshot postDoc = await FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(postId)
          .get();
      
      Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;
      
      // Delete all images from storage if they exist
      if (postData['imageUrls'] != null) {
        for (String imageUrl in List<String>.from(postData['imageUrls'])) {
          try {
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
          } catch (e) {
            print('Error deleting image: $e');
          }
        }
      }

      // Delete the post document
      await FirebaseFirestore.instance.collection('mealPosts').doc(postId).delete();
      
      setState(() {
        _posts.removeWhere((post) => post['postId'] == postId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post deleted')),
      );
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post')),
      );
    }
  }

  Future<void> _navigateToSettings() async {
    final result = await Navigator.pushNamed(context, '/accountSettings');
    if (result == true) {
      _loadUserProfile();
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadUserProfile(),
      _loadUserPosts(),
      _loadFollowingAndFollowers(),
    ]);
  }

  Future<void> _updateProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      String userId = _auth.currentUser!.uid;
      File imageFile = File(image.path);
      
      // Upload image to Firebase Storage
      String fileName = 'profile_images/$userId.jpg';
      await _storage.ref(fileName).putFile(imageFile);
      
      // Get download URL
      String downloadUrl = await _storage.ref(fileName).getDownloadURL();
      
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileImageUrl': downloadUrl});
      
      setState(() {
        _profileImageUrl = downloadUrl;
      });
    } catch (e) {
      print('Error updating profile image: $e');
    }
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/inspectPost',
            arguments: post['postId'],
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['imageUrls'] != null && 
                (post['imageUrls'] as List).isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: (post['imageUrls'] as List).length,
                  itemBuilder: (context, imageIndex) {
                    return Image.network(
                      post['imageUrls'][imageIndex],
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ListTile(
              title: Text(post['mealTitle']),
              subtitle: Text(post['mealDescription']),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deletePost(post['postId']);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@$_username'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Image
                Center(
                  child: GestureDetector(
                    onTap: _updateProfileImage,
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
                ),
                SizedBox(height: 20),
                
                // Name and Username
                Text(
                  _name,
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 5),
                Text(
                  '@$_username',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 10),
                
                // Bio
                Text(
                  _bio,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                
                // Following/Followers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/following',
                        arguments: {
                          'userId': _auth.currentUser!.uid,
                          'isCurrentUser': true,
                        },
                      ),
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
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/followers',
                        arguments: {
                          'userId': _auth.currentUser!.uid,
                          'isCurrentUser': true,
                        },
                      ),
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
                
                // Posts Section
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
                
                // Posts List
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostItem(_posts[index]);
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
