import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  const CommentsPage({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  // Function to load comments from Firestore
  Future<void> _loadComments() async {
    try {
      DocumentSnapshot postDoc = await FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId)
          .get();

      if (postDoc.exists) {
        List<dynamic> comments = postDoc['comments'] ?? [];
        setState(() {
          _comments = List<Map<String, dynamic>>.from(
            comments.map((comment) {
              return {
                'username': comment['username'],
                'text': comment['text'],
                'timestamp': comment['timestamp'],
              };
            }),
          );
        });
      }
    } catch (e) {
      print("Error loading comments: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load comments.")),
      );
    }
  }

// Function to add a new comment to Firestore
Future<void> _addComment() async {
  String userId = _auth.currentUser!.uid;
  String comment = _commentController.text.trim();

  if (comment.isEmpty) return;

  try {
    // Get the username for the comment from Firestore, fallback to 'Anonymous' if not found
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String username = userDoc.exists && userDoc['username'] != null ? userDoc['username'] : 'Anonymous';
    Timestamp timestamp = Timestamp.now();

    // Add the new comment to the Firestore document
    await FirebaseFirestore.instance.collection('mealPosts').doc(widget.postId).update({
      'comments': FieldValue.arrayUnion([
        {
          'username': username,
          'text': comment,
          'timestamp': timestamp,
        }
      ]),
    });

    // Update local state with the new comment
    setState(() {
      _comments.add({
        'username': username,
        'text': comment,
        'timestamp': timestamp,
      });
    });

    // Clear the comment input field
    _commentController.clear();
  } catch (e) {
    print("Error adding comment: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to add comment.")),
    );
  }
}
  // Helper function to format time ago
  String _timeAgo(Timestamp timestamp) {
    DateTime now = DateTime.now();
    DateTime commentTime = timestamp.toDate();
    Duration diff = now.difference(commentTime);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} days ago';
    } else {
      return '${(diff.inDays / 30).floor()} months ago';
    }
  }

  // Add this method to check if a comment belongs to the current user
  Future<bool> _isMyComment(String commentUsername) async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc['username'] == commentUsername;
  }

  // Add this method to delete a comment
  Future<void> _deleteComment(Map<String, dynamic> commentToDelete) async {
    try {
      // Get the current post document
      DocumentReference postRef = FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        
        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        List<dynamic> comments = List.from(postSnapshot['comments'] ?? []);
        
        // Find and remove the comment
        comments.removeWhere((comment) =>
          comment['username'] == commentToDelete['username'] &&
          comment['text'] == commentToDelete['text'] &&
          comment['timestamp'] == commentToDelete['timestamp']
        );

        // Update the post with the new comments list
        transaction.update(postRef, {'comments': comments});
        
        // Update local state
        setState(() {
          _comments.remove(commentToDelete);
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Comment deleted successfully")),
      );
    } catch (e) {
      print("Error deleting comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete comment")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                var comment = _comments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Picture
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/otherProfile',
                                arguments: comment['userId'],
                              );
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: comment['profileImageUrl'] != null && comment['profileImageUrl'].isNotEmpty
                                  ? NetworkImage(comment['profileImageUrl'])
                                  : null,
                              child: comment['profileImageUrl'] == null || comment['profileImageUrl'].isEmpty
                                  ? Text(comment['username'][0].toUpperCase())
                                  : null,
                            ),
                          ),
                          SizedBox(width: 12),
                          // Comment Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/otherProfile',
                                          arguments: comment['userId'],
                                        );
                                      },
                                      child: Text(
                                        comment['username'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    FutureBuilder<bool>(
                                      future: _isMyComment(comment['username']),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data == true) {
                                          return IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Delete Comment'),
                                                    content: const Text('Are you sure you want to delete this comment?'),
                                                    actions: [
                                                      TextButton(
                                                        child: const Text('Cancel'),
                                                        onPressed: () => Navigator.of(context).pop(),
                                                      ),
                                                      TextButton(
                                                        child: const Text('Delete'),
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                          _deleteComment(comment);
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(comment['text']),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    _timeAgo(comment['timestamp']),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
