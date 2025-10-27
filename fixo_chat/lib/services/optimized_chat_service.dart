import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/optimized_chat_model.dart';

class OptimizedChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate consistent chat ID
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'chat_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Get user type from user profile
  Future<String> _getUserType(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data()?['user_type'] ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  // Send message with integrated typing cleanup
  Future<String> sendMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaThumbnail,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final chatId = _generateChatId(currentUser.uid, receiverId);
    final senderType = await _getUserType(currentUser.uid);
    final receiverType = await _getUserType(receiverId);

    // Check if users are blocked
    final isBlocked = await _isUserBlocked(receiverId);
    if (isBlocked) {
      throw Exception('Cannot send message: User is blocked');
    }

    final messageData = {
      'chat_id': chatId,
      'sender_id': currentUser.uid,
      'sender_type': senderType,
      'content': content,
      'message_type': messageType,
      'timestamp': FieldValue.serverTimestamp(),
      'read_by': {currentUser.uid: FieldValue.serverTimestamp()},
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaThumbnail != null) 'media_thumbnail': mediaThumbnail,
    };

    // Add message
    final messageRef = await _firestore.collection('messages').add(messageData);

    // Update or create chat document
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUser.uid, receiverId],
      'participant_types': [senderType, receiverType],
      'last_message': content,
      'last_message_timestamp': FieldValue.serverTimestamp(),
      'last_sender_id': currentUser.uid,
      'typing_status.${currentUser.uid}': null, // Clear typing status
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return messageRef.id;
  }

  // Update typing status (integrated into chat document)
  Future<void> updateTypingStatus(String receiverId, bool isTyping) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).update({
      'typing_status.${currentUser.uid}': isTyping
          ? FieldValue.serverTimestamp()
          : null,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Get chat with typing status
  Stream<OptimizedChatModel?> getChatStream(String receiverId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(null);

    final chatId = _generateChatId(currentUser.uid, receiverId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map(
          (doc) => doc.exists ? OptimizedChatModel.fromFirestore(doc) : null,
        );
  }

  // Get messages for a chat
  Stream<List<OptimizedMessageModel>> getMessagesStream(String receiverId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    final chatId = _generateChatId(currentUser.uid, receiverId);

    return _firestore
        .collection('messages')
        .where('chat_id', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OptimizedMessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get user's chats
  Stream<List<OptimizedChatModel>> getUserChatsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OptimizedChatModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String receiverId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, receiverId);

    // Get unread messages
    final unreadMessages = await _firestore
        .collection('messages')
        .where('chat_id', isEqualTo: chatId)
        .where('sender_id', isEqualTo: receiverId)
        .get();

    // Batch update read status
    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'read_by.${currentUser.uid}': FieldValue.serverTimestamp(),
      });
    }

    // Update unread count in chat
    batch.update(_firestore.collection('chats').doc(chatId), {
      'unread_count.${currentUser.uid}': 0,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Block user
  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    await _firestore.collection('user_profiles').doc(currentUser.uid).update({
      'blocked_users': FieldValue.arrayUnion([userId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Unblock user
  Future<void> unblockUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    await _firestore.collection('user_profiles').doc(currentUser.uid).update({
      'blocked_users': FieldValue.arrayRemove([userId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Check if user is blocked
  Future<bool> _isUserBlocked(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(currentUser.uid)
          .get();
      if (doc.exists) {
        final blockedUsers = List<String>.from(
          doc.data()?['blocked_users'] ?? [],
        );
        return blockedUsers.contains(userId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Archive chat
  Future<void> archiveChat(String receiverId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).update({
      'is_archived': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({
      'deleted_at': FieldValue.serverTimestamp(),
    });
  }

  // Edit message
  Future<void> editMessage(String messageId, String newContent) async {
    await _firestore.collection('messages').doc(messageId).update({
      'content': newContent,
      'edited_at': FieldValue.serverTimestamp(),
    });
  }

  // Get total unread count for user
  Future<int> getTotalUnreadCount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    try {
      final chats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      int totalUnread = 0;
      for (final doc in chats.docs) {
        final data = doc.data();
        final unreadCount = data['unread_count'] as Map<String, dynamic>? ?? {};
        totalUnread += (unreadCount[currentUser.uid] as int? ?? 0);
      }

      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  // Search messages
  Future<List<OptimizedMessageModel>> searchMessages(String query) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // Get user's chats first
    final chats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    final chatIds = chats.docs.map((doc) => doc.id).toList();

    if (chatIds.isEmpty) return [];

    // Search messages in user's chats
    final messages = await _firestore
        .collection('messages')
        .where('chat_id', whereIn: chatIds)
        .where('content', isGreaterThanOrEqualTo: query)
        .where('content', isLessThanOrEqualTo: '$query\uf8ff')
        .orderBy('content')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    return messages.docs
        .map((doc) => OptimizedMessageModel.fromFirestore(doc))
        .toList();
  }
}
