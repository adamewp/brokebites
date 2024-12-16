import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      String userId = _auth.currentUser!.uid;
      QuerySnapshot notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> notifications = [];
      for (var doc in notificationsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Get sender's information
        DocumentSnapshot senderDoc =
            await _firestore.collection('users').doc(data['senderId']).get();

        Map<String, dynamic> senderData =
            senderDoc.data() as Map<String, dynamic>;

        notifications.add({
          'id': doc.id,
          'type': data['type'], // 'like', 'comment', 'follow'
          'timestamp': data['timestamp'],
          'senderName': senderData['username'] ?? 'Unknown User',
          'senderProfileImage': senderData['profileImageUrl'],
          'postId': data['postId'],
          'message': data['message'],
          'read': data['read'] ?? false,
        });
      }

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    Duration difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inDays > 7) {
      return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    IconData icon;
    Color iconColor;
    switch (notification['type']) {
      case 'like':
        icon = CupertinoIcons.heart_fill;
        iconColor = CupertinoColors.systemRed;
        break;
      case 'comment':
        icon = CupertinoIcons.chat_bubble_fill;
        iconColor = CupertinoColors.systemBlue;
        break;
      case 'follow':
        icon = CupertinoIcons.person_fill;
        iconColor = CupertinoColors.systemGreen;
        break;
      default:
        icon = CupertinoIcons.bell_fill;
        iconColor = CupertinoColors.systemGrey;
    }

    return GestureDetector(
      onTap: () {
        if (notification['postId'] != null) {
          Navigator.pushNamed(
            context,
            '/inspectPost',
            arguments: notification['postId'],
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification['read']
              ? CupertinoColors.white
              : const Color(0xFFF5F5F5),
          border: const Border(
            bottom: BorderSide(
              color: CupertinoColors.systemGrey5,
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
                image: notification['senderProfileImage'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          notification['senderProfileImage'],
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: notification['senderProfileImage'] == null
                  ? const Icon(CupertinoIcons.person_fill)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notification['message'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF25242A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeAgo(notification['timestamp']),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Notifications'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationItem(_notifications[index]);
                  },
                ),
    );
  }
}
