import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for thread message operations (edit, delete, unsend)
class ThreadMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find a message in thread subcollections
  static Future<DocumentReference?> _findMessageInThreads(
    String messageId,
  ) async {
    try {
      final threadsSnapshot = await _firestore.collection('threads').get();

      for (final threadDoc in threadsSnapshot.docs) {
        final messageDoc = await _firestore
            .collection('threads')
            .doc(threadDoc.id)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          return messageDoc.reference;
        }
      }

      return null;
    } catch (e) {
      print('Error finding message in threads: $e');
      return null;
    }
  }

  /// Edit a message in thread system
  static Future<bool> editMessage(String messageId, String newContent) async {
    try {
      // Try to find message in thread subcollections
      final messageRef = await _findMessageInThreads(messageId);

      if (messageRef != null) {
        await messageRef.update({
          'content': newContent,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message edited successfully in thread system');
        return true;
      }

      // Fallback: try old messages collection
      try {
        await _firestore.collection('messages').doc(messageId).update({
          'content': newContent,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message edited successfully in old system');
        return true;
      } catch (e) {
        print('❌ Message not found in old system: $e');
      }

      return false;
    } catch (e) {
      print('❌ Edit message error: $e');
      return false;
    }
  }

  /// Delete message for current user only
  static Future<bool> deleteMessageForMe(
    String messageId,
    String currentUserId,
  ) async {
    try {
      // Try to find message in thread subcollections
      final messageRef = await _findMessageInThreads(messageId);

      if (messageRef != null) {
        await messageRef.update({
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
          'deletedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message deleted for user successfully in thread system');
        return true;
      }

      // Fallback: try old messages collection
      try {
        await _firestore.collection('messages').doc(messageId).update({
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
          'deletedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message deleted for user successfully in old system');
        return true;
      } catch (e) {
        print('❌ Message not found in old system: $e');
      }

      return false;
    } catch (e) {
      print('❌ Delete message error: $e');
      return false;
    }
  }

  /// Unsend message (delete for everyone)
  static Future<bool> unsendMessage(String messageId) async {
    try {
      // Try to find message in thread subcollections
      final messageRef = await _findMessageInThreads(messageId);

      if (messageRef != null) {
        await messageRef.update({
          'isUnsent': true,
          'content': 'This message was unsent',
          'editedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message unsent successfully in thread system');
        return true;
      }

      // Fallback: try old messages collection
      try {
        await _firestore.collection('messages').doc(messageId).update({
          'isUnsent': true,
          'content': 'This message was unsent',
          'editedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Message unsent successfully in old system');
        return true;
      } catch (e) {
        print('❌ Message not found in old system: $e');
      }

      return false;
    } catch (e) {
      print('❌ Unsend message error: $e');
      return false;
    }
  }

  /// Get message details for operations
  static Future<Map<String, dynamic>?> getMessageDetails(
    String messageId,
  ) async {
    try {
      // Try to find message in thread subcollections
      final threadsSnapshot = await _firestore.collection('threads').get();

      for (final threadDoc in threadsSnapshot.docs) {
        final messageDoc = await _firestore
            .collection('threads')
            .doc(threadDoc.id)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          return {
            'data': messageDoc.data(),
            'threadId': threadDoc.id,
            'messageId': messageId,
            'location': 'thread_system',
          };
        }
      }

      // Fallback: try old messages collection
      final oldMessageDoc = await _firestore
          .collection('messages')
          .doc(messageId)
          .get();
      if (oldMessageDoc.exists) {
        return {
          'data': oldMessageDoc.data(),
          'messageId': messageId,
          'location': 'old_system',
        };
      }

      return null;
    } catch (e) {
      print('Error getting message details: $e');
      return null;
    }
  }
}
