import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a notification when someone likes a post
  static Future<void> createLikeNotification({
    required String postId,
    required String postOwnerId,
    required String likerId,
    required String postTitle,
  }) async {
    if (postOwnerId == likerId)
      return; // Don't notify if user likes their own post

    try {
      // Create the notification document
      DocumentReference notificationRef =
          await _firestore.collection('notifications').add({
        'type': 'like',
        'recipientId': postOwnerId,
        'senderId': likerId,
        'postId': postId,
        'message': 'liked your post "$postTitle"',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'pushSent':
            false, // Add this field for tracking push notification status
      });

      // Get the recipient's FCM tokens
      DocumentSnapshot recipientDoc =
          await _firestore.collection('users').doc(postOwnerId).get();

      // Get the sender's username
      DocumentSnapshot senderDoc =
          await _firestore.collection('users').doc(likerId).get();

      String senderUsername = senderDoc['username'] ?? 'Someone';

      // Create a push notification trigger document
      await _firestore.collection('pushNotifications').add({
        'notificationId': notificationRef.id,
        'recipientId': postOwnerId,
        'title': 'New Like',
        'body': '$senderUsername liked your post "$postTitle"',
        'tokens': recipientDoc['fcmTokens'] ?? [],
        'data': {
          'type': 'post',
          'postId': postId,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error creating like notification: $e');
    }
  }

  // Create a notification when someone comments on a post
  static Future<void> createCommentNotification({
    required String postId,
    required String postOwnerId,
    required String commenterId,
    required String postTitle,
    required String comment,
  }) async {
    if (postOwnerId == commenterId)
      return; // Don't notify if user comments on their own post

    try {
      // Create the notification document
      DocumentReference notificationRef =
          await _firestore.collection('notifications').add({
        'type': 'comment',
        'recipientId': postOwnerId,
        'senderId': commenterId,
        'postId': postId,
        'message':
            'commented on your post "$postTitle": "${comment.length > 50 ? '${comment.substring(0, 47)}...' : comment}"',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'pushSent': false,
      });

      // Get the recipient's FCM tokens
      DocumentSnapshot recipientDoc =
          await _firestore.collection('users').doc(postOwnerId).get();

      // Get the sender's username
      DocumentSnapshot senderDoc =
          await _firestore.collection('users').doc(commenterId).get();

      String senderUsername = senderDoc['username'] ?? 'Someone';

      // Create a push notification trigger document
      await _firestore.collection('pushNotifications').add({
        'notificationId': notificationRef.id,
        'recipientId': postOwnerId,
        'title': 'New Comment',
        'body': '$senderUsername commented on your post "$postTitle"',
        'tokens': recipientDoc['fcmTokens'] ?? [],
        'data': {
          'type': 'post',
          'postId': postId,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error creating comment notification: $e');
    }
  }

  // Create a notification when someone follows a user
  static Future<void> createFollowNotification({
    required String followerId,
    required String followedUserId,
  }) async {
    try {
      // Create the notification document
      DocumentReference notificationRef =
          await _firestore.collection('notifications').add({
        'type': 'follow',
        'recipientId': followedUserId,
        'senderId': followerId,
        'message': 'started following you',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'pushSent': false,
      });

      // Get the recipient's FCM tokens
      DocumentSnapshot recipientDoc =
          await _firestore.collection('users').doc(followedUserId).get();

      // Get the sender's username
      DocumentSnapshot senderDoc =
          await _firestore.collection('users').doc(followerId).get();

      String senderUsername = senderDoc['username'] ?? 'Someone';

      // Create a push notification trigger document
      await _firestore.collection('pushNotifications').add({
        'notificationId': notificationRef.id,
        'recipientId': followedUserId,
        'title': 'New Follower',
        'body': '$senderUsername started following you',
        'tokens': recipientDoc['fcmTokens'] ?? [],
        'data': {
          'type': 'profile',
          'userId': followerId,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error creating follow notification: $e');
    }
  }

  // Mark a notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get unread notifications count
  static Stream<int> getUnreadNotificationsCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
