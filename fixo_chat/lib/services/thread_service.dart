import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing threads with your exact schema
class ThreadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or get thread between tradie and homeowner
  Future<String> getOrCreateThread({
    required int tradieId,
    required int homeownerId,
  }) async {
    // Query for existing thread
    final existingThread = await _firestore
        .collection('threads')
        .where('tradie_id', isEqualTo: tradieId)
        .where('homeowner_id', isEqualTo: homeownerId)
        .limit(1)
        .get();

    if (existingThread.docs.isNotEmpty) {
      return existingThread.docs.first.id;
    }

    // Create new thread
    final threadId = await _getNextThreadId();
    final threadDocName = 'thread_$threadId';

    await _firestore.collection('threads').doc(threadDocName).set({
      'thread_id': threadId,
      'sender_1': tradieId, // tradie_id
      'sender_2': homeownerId, // homeowner_id
      'tradie_id': tradieId,
      'homeowner_id': homeownerId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': '',
      'last_message_time': FieldValue.serverTimestamp(),
      'is_archived': false,
      'is_deleted': false,
    });

    return threadDocName;
  }

  /// Send message to thread
  Future<void> sendMessage({
    required String threadDocName,
    required int senderId,
    required String senderType,
    required String content,
  }) async {
    // Get next message ID
    final messageId = await _getNextMessageId(threadDocName);

    // Add message to subcollection
    await _firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .doc('msg_$messageId')
        .set({
          'sender_id': senderId,
          'sender_type': senderType,
          'content': content,
          'date': FieldValue.serverTimestamp(),
        });

    // Update thread last message
    await _firestore.collection('threads').doc(threadDocName).update({
      'last_message': content,
      'last_message_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages from thread
  Stream<QuerySnapshot> getMessages(String threadDocName) {
    return _firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .snapshots();
  }

  /// Get threads for user
  Stream<QuerySnapshot> getThreadsForUser({
    required int userId,
    required String userType,
  }) {
    if (userType == 'tradie') {
      return _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: userId)
          .snapshots();
    } else {
      return _firestore
          .collection('threads')
          .where('homeowner_id', isEqualTo: userId)
          .snapshots();
    }
  }

  /// Get next thread ID
  Future<int> _getNextThreadId() async {
    final threadsSnapshot = await _firestore.collection('threads').get();

    int highestId = 10000; // Start from 10001

    for (final doc in threadsSnapshot.docs) {
      final data = doc.data();
      final threadId = data['thread_id'] as int? ?? 10000;
      if (threadId > highestId) {
        highestId = threadId;
      }
    }

    return highestId + 1;
  }

  /// Get next message ID for thread
  Future<int> _getNextMessageId(String threadDocName) async {
    final messagesSnapshot = await _firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .get();

    int highestId = 0;

    for (final doc in messagesSnapshot.docs) {
      final docId = doc.id;
      if (docId.startsWith('msg_')) {
        final idStr = docId.substring(4);
        final id = int.tryParse(idStr) ?? 0;
        if (id > highestId) {
          highestId = id;
        }
      }
    }

    return highestId + 1;
  }

  /// Archive thread
  Future<void> archiveThread(String threadDocName) async {
    await _firestore.collection('threads').doc(threadDocName).update({
      'is_archived': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete thread
  Future<void> deleteThread(String threadDocName) async {
    await _firestore.collection('threads').doc(threadDocName).update({
      'is_deleted': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
