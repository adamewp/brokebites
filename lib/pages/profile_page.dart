import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image/image.dart' as Im;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScaffold();
  }
}

class ProfileScaffold extends StatelessWidget {
  const ProfileScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      child: ProfileContent(),
    );
  }
}

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  _ProfileContentState createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
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
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  final int _postsPerPage = 10;
  DocumentSnapshot? _lastDocument;
  final String _postsDataCacheKey = 'postsDataCacheKey';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserPosts();
    _loadFollowingAndFollowers();
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
          .limit(_postsPerPage)
          .get();

      if (postDocs.docs.isNotEmpty) {
        _lastDocument = postDocs.docs.last;
      }

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
    setState(() {
      _posts = [];
      _lastDocument = null;
      _hasMorePosts = true;
    });
    
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
                    return WillPopScope(
                      onWillPop: () async {
                        Navigator.of(context).pop();
                        return false;
                      },
                      child: Hero(
                        tag: 'post-${post['postId']}-image-$imageIndex-list-${post['postId']}',
                        child: CachedNetworkImage(
                          imageUrl: post['imageUrls'][imageIndex] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CupertinoActivityIndicator()),
                          errorWidget: (context, url, error) {
                            if (url.isEmpty) {
                              return const Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 40,
                                  color: CupertinoColors.systemGrey,
                                ),
                              );
                            }
                            return const Icon(CupertinoIcons.exclamationmark_triangle);
                          },
                        ),
                      ),
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

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      String userId = _auth.currentUser!.uid;
      Query query = FirebaseFirestore.instance
          .collection('mealPosts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMorePosts = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<Map<String, dynamic>> newPosts = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'postId': doc.id,
          ...data,
        };
      }).toList();

      setState(() {
        _posts.addAll(newPosts);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more posts: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    int rand = Random().nextInt(10000);

    Im.Image? image = Im.decodeImage(file.readAsBytesSync());
    if (image == null) return file;
    
    Im.Image smallerImage = Im.copyResize(image, width: 1024); // Fixed width, maintain aspect ratio
    
    final compressedImage = File('$path/img_$rand.jpg')
      ..writeAsBytesSync(Im.encodeJpg(smallerImage, quality: 85));
      
    return compressedImage;
  }

  Future<void> _loadFollowing() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      setState(() {
        _following = List<String>.from(userDoc.data()?['following'] ?? []);
      });

      // Load usernames for following
      _followingUsernames = [];
      for (String userId in _following) {
        final followingDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (followingDoc.exists) {
          setState(() {
            _followingUsernames.add(followingDoc.data()?['username'] ?? '');
          });
        }
      }
    } catch (e) {
      print('Error loading following: $e');
    }
  }

  Future<void> _updateProfileImageWithCropper() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      print("Image picked: ${image.path}"); // Debug log

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Image',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
            rotateButtonsHidden: true,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) {
        print("No cropped file"); // Debug log
        return;
      }

      print("Image cropped: ${croppedFile.path}"); // Debug log

      String userId = _auth.currentUser!.uid;
      File imageFile = File(croppedFile.path);
      
      // Compress the image
      File compressedImage = await _compressImage(imageFile);
      
      print("Image compressed"); // Debug log

      // Upload image to Firebase Storage
      String fileName = 'profile_images/$userId.jpg';
      await _storage.ref(fileName).putFile(compressedImage);
      
      print("Image uploaded to storage"); // Debug log

      // Get download URL
      String downloadUrl = await _storage.ref(fileName).getDownloadURL();
      
      print("Got download URL: $downloadUrl"); // Debug log

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileImageUrl': downloadUrl});
      
      print("Firestore updated"); // Debug log

      setState(() {
        _profileImageUrl = downloadUrl;
      });

      print("State updated"); // Debug log
    } catch (e, stackTrace) {
      print('Error updating profile image: $e');
      print('Stack trace: $stackTrace');
      _showErrorMessage('Failed to update profile picture: ${e.toString()}');
    }
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
                    onTap: _updateProfileImageWithCropper,
                    child: CachedNetworkImage(
                      imageUrl: _profileImageUrl ?? '',
                      imageBuilder: (context, imageProvider) => Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.systemGrey5,
                        ),
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.systemGrey5,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          size: 50,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
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
                      if (index >= _posts.length - 5 && !_isLoadingMore && _hasMorePosts) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadMorePosts();
                        });
                      }
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
