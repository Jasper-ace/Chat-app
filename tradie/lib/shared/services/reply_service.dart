import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ReplyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get next thread ID (sequential)
  static Future<int> _getNextThreadId() async {
    // Get all threads to find highest thread_id
    final threadsSnapshot = await _firestore.collection('threads').get();

    int highestId = 0; // Start from 1

    for (final doc in threadsSnapshot.docs) {
      final data = doc.data();
      final threadId = data['thread_id'] as int? ?? 0;
      if (threadId > highestId) {
        highestId = threadId;
      }
    }

    return highestId + 1;
  }

  /// Send a reply message
  static Future<bool> sendReplyMessage({
    required String threadId,
    required int senderId,
    required String senderType,
    required int receiverId,
    required String receiverType,
    required String message,
    required MessageModel replyToMessage,
  }) async {
    try {
      // Create reply message document
      final messageDoc = {
        'sender_id': senderId,
        'sender_type': senderType,
        'receiver_id': receiverId,
        'receiver_type': receiverType,
        'content': message,
        'date': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'sent',
        'message_type': 'reply',
        'reply_to': {
          'message_id': replyToMessage.id,
          'content': replyToMessage.content,
          'sender_id': replyToMessage.senderId,
          'sender_type': replyToMessage.senderType,
          'date': replyToMessage.date,
        },
      };

      // Add to thread messages subcollection
      await _firestore
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .add(messageDoc);

      // Update thread's last message info
      await _firestore.collection('threads').doc(threadId).update({
        'last_message': message,
        'last_message_time': FieldValue.serverTimestamp(),
        'last_sender_id': senderId,
        'last_sender_type': senderType,
      });

      print('✅ Reply message sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending reply message: $e');
      return false;
    }
  }

  /// Get thread ID for users
  static Future<String?> getThreadId({
    required int tradieId,
    required int homeownerId,
  }) async {
    try {
      final threadQuery = await _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: tradieId)
          .where('homeowner_id', isEqualTo: homeownerId)
          .limit(1)
          .get();

      if (threadQuery.docs.isNotEmpty) {
        return threadQuery.docs.first.id;
      }

      // Create new thread if doesn't exist using sequential ID
      final threadId = await _getNextThreadId();
      final threadDocName = 'threadID_$threadId';

      await _firestore.collection('threads').doc(threadDocName).set({
        'thread_id': threadId,
        'tradie_id': tradieId,
        'homeowner_id': homeownerId,
        'sender_1': tradieId,
        'sender_2': homeownerId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_time': FieldValue.serverTimestamp(),
        'is_archived': false,
        'is_deleted': false,
      });

      return threadDocName;
    } catch (e) {
      print('❌ Error getting thread ID: $e');
      return null;
    }
  }

  /// Check if a message is a reply
  static bool isReplyMessage(Map<String, dynamic> messageData) {
    return messageData['message_type'] == 'reply' &&
        messageData['reply_to'] != null;
  }

  /// Get reply information from message data
  static Map<String, dynamic>? getReplyInfo(Map<String, dynamic> messageData) {
    if (isReplyMessage(messageData)) {
      return messageData['reply_to'] as Map<String, dynamic>?;
    }
    return null;
  }
}
