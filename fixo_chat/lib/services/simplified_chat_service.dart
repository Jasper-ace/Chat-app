import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/thread_model.dart';
import '../models/message_model.dart';

class SimplifiedChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references - only 2 collections matching SQL structure
  CollectionReference get _threadsCollection =>
      _firestore.collection('threads');
  CollectionReference get _messagesCollection =>
      _firestore.collection('messages');

  // Create or get thread between two users
  Future<String> createOrGetThread({
    required int user1Id,
    required int user2Id,
    required String user1Type, // 'tradie' or 'homeowner'
    required String user2Type,
  }) async {
    // Check if thread already exists (either direction)
    final existingThread = await _threadsCollection
        .where('sender_1', whereIn: [user1Id, user2Id])
        .where('sender_2', whereIn: [user1Id, user2Id])
        .limit(1)
        .get();

    if (existingThread.docs.isNotEmpty) {
      return existingThread.docs.first.id;
    }

    // Create new thread
    final threadRef = await _threadsCollection.add({
      'sender_1': user1Id,
      'sender_2': user2Id,
      'sender_1_type': user1Type,
      'sender_2_type': user2Type,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': null,
      'last_message_time': null,
      'read_status': {user1Id.toString(): true, user2Id.toString(): true},
      'typing_status': {},
      'blocked_status': {user1Id.toString(): false, user2Id.toString(): false},
      'is_archived': false,
    });

    return threadRef.id;
  }

  // Send message
  Future<void> sendMessage({
    required String threadId,
    required int senderId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? imageThumbnail,
  }) async {
    final batch = _firestore.batch();

    // Add message to messages collection
    final messageRef = _messagesCollection.doc();
    batch.set(messageRef, {
      'thread_id': threadId,
      'sender_id': senderId,
      'content': content,
      'messageType': type.name,
      'imageUrl': imageUrl,
      'imageThumbnail': imageThumbnail,
      'date': FieldValue.serverTimestamp(),
      'read': false,
      'isDeleted': false,
      'isUnsent': false,
      'deletedBy': null,
    });

    // Update thread with last message info and reset read status
    final threadRef = _threadsCollection.doc(threadId);
    batch.update(threadRef, {
      'last_message': content,
      'last_message_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'read_status.${senderId.toString()}':
          true, // Sender has read their own message
    });

    // Clear typing status for sender
    batch.update(threadRef, {
      'typing_status.${senderId.toString()}': FieldValue.delete(),
    });

    await batch.commit();
  }

  // Get messages for a thread
  Stream<List<MessageModel>> getMessages(String threadId) {
    return _messagesCollection
        .where('thread_id', isEqualTo: threadId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get threads for a user
  Stream<List<ThreadModel>> getUserThreads(int userId) {
    return _threadsCollection
        .where('sender_1', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot1) async {
          final snapshot2 = await _threadsCollection
              .where('sender_2', isEqualTo: userId)
              .get();

          final allDocs = [...snapshot1.docs, ...snapshot2.docs];
          return allDocs
              .map((doc) => ThreadModel.fromFirestore(doc))
              .where((thread) => !thread.isArchived)
              .toList()
            ..sort(
              (a, b) => (b.lastMessageTime ?? b.updatedAt).compareTo(
                a.lastMessageTime ?? a.updatedAt,
              ),
            );
        });
  }

  // Update typing status
  Future<void> updateTypingStatus(
    String threadId,
    int userId,
    bool isTyping,
  ) async {
    final threadRef = _threadsCollection.doc(threadId);

    if (isTyping) {
      await threadRef.update({
        'typing_status.${userId.toString()}': FieldValue.serverTimestamp(),
      });
    } else {
      await threadRef.update({
        'typing_status.${userId.toString()}': FieldValue.delete(),
      });
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String threadId, int userId) async {
    final batch = _firestore.batch();

    // Update thread read status
    final threadRef = _threadsCollection.doc(threadId);
    batch.update(threadRef, {'read_status.${userId.toString()}': true});

    // Update individual messages
    final unreadMessages = await _messagesCollection
        .where('thread_id', isEqualTo: threadId)
        .where('sender_id', isNotEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  // Block/Unblock user
  Future<void> updateBlockStatus(
    String threadId,
    int userId,
    bool isBlocked,
  ) async {
    await _threadsCollection.doc(threadId).update({
      'blocked_status.${userId.toString()}': isBlocked,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Archive thread
  Future<void> archiveThread(String threadId) async {
    await _threadsCollection.doc(threadId).update({
      'is_archived': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Get thread by ID
  Future<ThreadModel?> getThread(String threadId) async {
    final doc = await _threadsCollection.doc(threadId).get();
    if (doc.exists) {
      return ThreadModel.fromFirestore(doc);
    }
    return null;
  }

  // Delete message
  Future<void> deleteMessage(String messageId, int userId) async {
    await _messagesCollection.doc(messageId).update({
      'isDeleted': true,
      'deletedBy': userId,
    });
  }

  // Unsend message
  Future<void> unsendMessage(String messageId) async {
    await _messagesCollection.doc(messageId).update({
      'isUnsent': true,
      'content': 'This message was unsent',
    });
  }

  // Get unread message count for user
  Future<int> getUnreadMessageCount(int userId) async {
    final threads = await _threadsCollection
        .where('sender_1', isEqualTo: userId)
        .get();

    final threads2 = await _threadsCollection
        .where('sender_2', isEqualTo: userId)
        .get();

    int unreadCount = 0;
    final allThreads = [...threads.docs, ...threads2.docs];

    for (final threadDoc in allThreads) {
      final thread = ThreadModel.fromFirestore(threadDoc);
      if (thread.hasUnreadMessages(userId)) {
        unreadCount++;
      }
    }

    return unreadCount;
  }
}
