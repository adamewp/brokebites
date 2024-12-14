import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
      _showErrorMessage("Failed to load comments.");
    }
  }

  Future<void> _addComment() async {
    String userId = _auth.currentUser!.uid;
    String comment = _commentController.text.trim();

    if (comment.isEmpty) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      String username = userDoc.exists && userDoc['username'] != null 
          ? userDoc['username'] 
          : 'Anonymous';
      Timestamp timestamp = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId)
          .update({
        'comments': FieldValue.arrayUnion([
          {
            'username': username,
            'text': comment,
            'timestamp': timestamp,
          }
        ]),
      });

      setState(() {
        _comments.add({
          'username': username,
          'text': comment,
          'timestamp': timestamp,
        });
      });

      _commentController.clear();
    } catch (e) {
      print("Error adding comment: $e");
      _showErrorMessage("Failed to add comment.");
    }
  }

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

  Future<bool> _isMyComment(String commentUsername) async {
    String userId = _auth.currentUser!.uid;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return userDoc['username'] == commentUsername;
  }

  Future<void> _deleteComment(Map<String, dynamic> commentToDelete) async {
    try {
      DocumentReference postRef = FirebaseFirestore.instance
          .collection('mealPosts')
          .doc(widget.postId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        
        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        List<dynamic> comments = List.from(postSnapshot['comments'] ?? []);
        comments.removeWhere((comment) =>
          comment['username'] == commentToDelete['username'] &&
          comment['text'] == commentToDelete['text'] &&
          comment['timestamp'] == commentToDelete['timestamp']
        );

        transaction.update(postRef, {'comments': comments});
        setState(() {
          _comments.remove(commentToDelete);
        });
      });

      _showSuccessMessage("Comment deleted successfully");
    } catch (e) {
      print("Error deleting comment: $e");
      _showErrorMessage("Failed to delete comment");
    }
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Success'),
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Comments'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  var comment = _comments[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.systemGrey.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CupertinoColors.systemGrey.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Text(
                              comment['username'][0].toUpperCase(),
                              style: const TextStyle(
                                color: CupertinoColors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    comment['username'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future: _isMyComment(comment['username']),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data == true) {
                                        return CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            showCupertinoDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return CupertinoAlertDialog(
                                                  title: const Text('Delete Comment'),
                                                  content: const Text(
                                                    'Are you sure you want to delete this comment?'
                                                  ),
                                                  actions: [
                                                    CupertinoDialogAction(
                                                      onPressed: () => 
                                                          Navigator.of(context).pop(),
                                                      child: const Text('Cancel'),
                                                      isDefaultAction: true,
                                                    ),
                                                    CupertinoDialogAction(
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                        _deleteComment(comment);
                                                      },
                                                      child: const Text('Delete'),
                                                      isDestructiveAction: true,
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: const Icon(
                                            CupertinoIcons.delete,
                                            size: 20,
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment['text'],
                                style: const TextStyle(
                                  color: CupertinoColors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _timeAgo(comment['timestamp']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.systemGrey.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _commentController,
                      placeholder: 'Add a comment...',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: _addComment,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Icon(CupertinoIcons.arrow_up_circle_fill),
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
