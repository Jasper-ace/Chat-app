import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

class MessageStatusService {
  static Future<void> updateMessageStatus(
    String threadId,
    String messageId,
    MessageStatus status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .doc(messageId)
          .update({
            'status': status.name,
            'status_updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error updating message status: $e');
    }
  }

  static Future<void> markMessageAsDelivered(
    String threadId,
    String messageId,
  ) async {
    await updateMessageStatus(threadId, messageId, MessageStatus.delivered);
  }

  static Future<void> markMessageAsRead(
    String threadId,
    String messageId,
  ) async {
    await updateMessageStatus(threadId, messageId, MessageStatus.read);
  }

  static Future<void> markAllMessagesAsRead(
    String threadId,
    int currentUserId,
  ) async {
    try {
      // Get all unread messages from the other user
      final messagesQuery = await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .where('sender_id', isNotEqualTo: currentUserId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {
          'status': MessageStatus.read.name,
          'status_updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  static MessageStatus getMessageStatusFromString(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  static String getStatusDisplayText(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.failed:
        return 'Failed';
    }
  }

  static Widget getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 16, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: Colors.grey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 16, color: Colors.blue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
  }

  static Future<int> getUnreadMessageCount(
    String threadId,
    int currentUserId,
  ) async {
    try {
      final messagesQuery = await FirebaseFirestore.instance
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .where('sender_id', isNotEqualTo: currentUserId)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      return messagesQuery.docs.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  static Stream<int> getUnreadMessageCountStream(
    String threadId,
    int currentUserId,
  ) {
    return FirebaseFirestore.instance
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .where('sender_id', isNotEqualTo: currentUserId)
        .where('status', whereIn: ['sent', 'delivered'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
