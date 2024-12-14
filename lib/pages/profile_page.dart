import 'package:flutter/cupertino.dart';
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
      _showErrorMessage('Failed to update profile picture');
    }
  }

  void _showListDialog(String listType, List<String> usernames) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(listType),
          content: Container(
            height: 200,
            width: double.maxFinite,
            child: CupertinoScrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: usernames.length,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      usernames[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
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
      
      _showErrorMessage('Post deleted successfully');
    } catch (e) {
      print('Error deleting post: $e');
      _showErrorMessage('Failed to delete post');
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
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/inspectPost',
          arguments: post['postId'],
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['mealTitle'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF25242A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post['mealDescription'],
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
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      color: CupertinoColors.systemGrey,
                    ),
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.pop(context);
                                _deletePost(post['postId']);
                              },
                              isDestructiveAction: true,
                              child: const Text('Delete'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFAF8F5),
        middle: Text(_username),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.settings,
            color: Color(0xFF25242A),
          ),
          onPressed: () => Navigator.pushNamed(context, '/accountSettings'),
        ),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _refreshProfile,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _updateProfileImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.systemGrey5,
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
                  const SizedBox(height: 16),
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF25242A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bio,
                    style: const TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
                              style: const TextStyle(
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
                            'userId': _auth.currentUser!.uid,
                            'isCurrentUser': true,
                          },
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Followers',
                              style: const TextStyle(
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
                      return _buildPostItem(_posts[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.pushNamed(context, '/inspectPost', arguments: post['postId']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                post['imageUrls'][0],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['mealTitle'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF25242A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post['mealDescription'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
