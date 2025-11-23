import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../../../core/services/laravel_api_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate consistent chat ID between two users (for backward compatibility)
  String _getChatId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '$userId-$otherUserId'
        : '$otherUserId-$userId';
  }

  /// Find or create a thread between tradie and homeowner
  /// Returns the thread document ID
  Future<String> _findOrCreateThread({
    required int tradieId,
    required int homeownerId,
  }) async {
    // Query for existing thread with these participants
    final existingThread = await _firestore
        .collection('threads')
        .where('tradie_id', isEqualTo: tradieId)
        .where('homeowner_id', isEqualTo: homeownerId)
        .limit(1)
        .get();

    if (existingThread.docs.isNotEmpty) {
      return existingThread.docs.first.id;
    }

    // Generate thread_id (sequential number)
    final threadId = await _getNextThreadId();

    // Create thread document name: threadID_1, threadID_2, etc.
    final threadDocName = 'threadID_$threadId';

    // Create new thread with your exact schema
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

  /// Get next thread ID (sequential)
  Future<int> _getNextThreadId() async {
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

  /// Send a message between tradie and homeowner (new thread system)
  Future<void> sendMessageThread({
    required int senderId, // Auto-increment ID from users
    required String senderType, // 'tradie' or 'homeowner'
    required int receiverId, // Auto-increment ID from users
    required String receiverType, // 'tradie' or 'homeowner'
    required String message,
  }) async {
    try {
      // Determine tradie and homeowner IDs
      int tradieId, homeownerId;
      if (senderType == 'tradie') {
        tradieId = senderId;
        homeownerId = receiverId;
      } else {
        tradieId = receiverId;
        homeownerId = senderId;
      }

      // Find or create thread
      final threadDocName = await _findOrCreateThread(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      final now = DateTime.now();

      // Get next message ID for this thread
      final messageId = await _getNextMessageId(threadDocName);

      // Add message to thread's messages subcollection
      await _firestore
          .collection('threads')
          .doc(threadDocName)
          .collection('messages')
          .doc('msg_$messageId')
          .set({
            'sender_id': senderId,
            'sender_type': senderType,
            'content': message,
            'date': Timestamp.fromDate(now),
          });

      // Update thread with last message info
      await _firestore.collection('threads').doc(threadDocName).update({
        'last_message': message,
        'last_message_time': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      });

      // Also save to Laravel database
      await LaravelApiService.saveMessageToLaravel(
        senderFirebaseUid: senderId.toString(),
        receiverFirebaseUid: receiverId.toString(),
        senderType: senderType,
        receiverType: receiverType,
        message: message,
      );
    } catch (e) {
      print('Send message error: $e');
      rethrow;
    }
  }

  /// Get next message ID for a thread
  Future<int> _getNextMessageId(String threadDocName) async {
    final messagesSnapshot = await _firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .get();

    int highestId = 0;

    for (final doc in messagesSnapshot.docs) {
      // Extract number from msg_1, msg_2, etc.
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

  /// Send a message (backward compatible method)
  Future<void> sendMessage({
    required String receiverId,
    required String message,
    required String senderUserType, // 'homeowner' or 'tradie'
    required String receiverUserType, // 'homeowner' or 'tradie'
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // For backward compatibility, use the old message format
      final chatId = _getChatId(currentUser.uid, receiverId);

      // Add message to messages collection (old format for compatibility)
      await _firestore.collection('messages').add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'senderUserType': senderUserType,
        'receiverUserType': receiverUserType,
        'message': message,
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'date': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Also save to Laravel database
      await LaravelApiService.saveMessageToLaravel(
        senderFirebaseUid: currentUser.uid,
        receiverFirebaseUid: receiverId,
        senderType: senderUserType,
        receiverType: receiverUserType,
        message: message,
      );
    } catch (e) {
      print('Send message error: $e');
      rethrow;
    }
  }

  /// Get messages for a thread between tradie and homeowner (new system)
  Stream<QuerySnapshot> getMessagesThread({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) {
    // Determine tradie and homeowner IDs
    int tradieId, homeownerId;
    if (currentUserType == 'tradie') {
      tradieId = currentUserId;
      homeownerId = otherUserId;
    } else {
      tradieId = otherUserId;
      homeownerId = currentUserId;
    }

    print(
      '🔍 Getting messages for thread: tradie=$tradieId, homeowner=$homeownerId',
    );

    // Return a stream that switches to the correct message stream when thread is found
    return _firestore
        .collection('threads')
        .where('tradie_id', isEqualTo: tradieId)
        .where('homeowner_id', isEqualTo: homeownerId)
        .limit(1)
        .snapshots()
        .asyncExpand((threadSnapshot) {
          if (threadSnapshot.docs.isEmpty) {
            print('🔍 No thread found, returning empty snapshot stream');
            // No thread exists, return a stream with an empty snapshot
            return Stream.fromFuture(
              _firestore
                  .collection('threads')
                  .doc('nonexistent')
                  .collection('messages')
                  .get(),
            );
          }

          final threadDocName = threadSnapshot.docs.first.id;
          print('🔍 Found thread: $threadDocName, streaming messages...');

          // Return real-time stream of messages from thread's subcollection
          return _firestore
              .collection('threads')
              .doc(threadDocName)
              .collection('messages')
              .orderBy('date', descending: true)
              .snapshots();
        });
  }

  /// Get messages for a chat (backward compatible)
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final chatId = _getChatId(currentUser.uid, otherUserId);

    // Simplified query without orderBy to avoid index requirement
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .snapshots();
  }

  /// Get threads for a user (tradie or homeowner)
  Stream<QuerySnapshot> getThreadsForUser({
    required int userId,
    required String userType,
  }) {
    if (userType == 'tradie') {
      // Get threads where user is tradie_id
      return _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: userId)
          .snapshots();
    } else {
      // Get threads where user is homeowner_id
      return _firestore
          .collection('threads')
          .where('homeowner_id', isEqualTo: userId)
          .snapshots();
    }
  }

  /// Get users of opposite type for chat
  Stream<QuerySnapshot> getAvailableUsers(String currentUserType) {
    String targetCollection = currentUserType == 'homeowner'
        ? 'tradies'
        : 'homeowners';

    // Simplified query without orderBy to avoid index requirement
    return _firestore.collection(targetCollection).snapshots();
  }

  /// Get recent threads for a user
  Stream<QuerySnapshot> getRecentThreads({
    required int userId,
    required String userType,
  }) {
    return getThreadsForUser(userId: userId, userType: userType);
  }

  /// Mark messages as read in a thread (new system)
  Future<void> markMessagesAsReadThread({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) async {
    try {
      // Determine tradie and homeowner IDs
      int tradieId, homeownerId;
      if (currentUserType == 'tradie') {
        tradieId = currentUserId;
        homeownerId = otherUserId;
      } else {
        tradieId = otherUserId;
        homeownerId = currentUserId;
      }

      // Find thread
      final threadQuery = await _firestore
          .collection('thread')
          .where('sender_1', isEqualTo: tradieId)
          .where('sender_2', isEqualTo: homeownerId)
          .limit(1)
          .get();

      if (threadQuery.docs.isEmpty) return;

      final threadId = threadQuery.docs.first.id;
      final threadIdInt = int.parse(
        threadId.hashCode.toString().substring(0, 8),
      );

      // Get unread messages from other user in this thread
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('thread_id', isEqualTo: threadIdInt)
          .where('sender_id', isEqualTo: otherUserId)
          .where('read', isEqualTo: false)
          .get();

      // Mark them as read
      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Also mark as read in Laravel
      await LaravelApiService.markMessagesAsRead(
        senderFirebaseUid: otherUserId.toString(),
        receiverFirebaseUid: currentUserId.toString(),
      );
    } catch (e) {
      print('Mark messages as read error: $e');
      rethrow;
    }
  }

  /// Mark messages as read (backward compatible)
  Future<void> markMessagesAsRead(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = _getChatId(currentUser.uid, otherUserId);

      // Get unread messages from other user
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      // Mark them as read
      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Also mark as read in Laravel
      await LaravelApiService.markMessagesAsRead(
        senderFirebaseUid: otherUserId,
        receiverFirebaseUid: currentUser.uid,
      );
    } catch (e) {
      print('Mark messages as read error: $e');
      rethrow;
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Get unread count error: $e');
      return 0;
    }
  }

  // Get user info from either collection
  Future<DocumentSnapshot?> getUserInfo(String userId, String userType) async {
    try {
      String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
      return await _firestore.collection(collection).doc(userId).get();
    } catch (e) {
      print('Get user info error: $e');
      return null;
    }
  }

  // Search users by name
  Stream<QuerySnapshot> searchUsers(
    String currentUserType,
    String searchQuery,
  ) {
    String targetCollection = currentUserType == 'homeowner'
        ? 'tradies'
        : 'homeowners';

    return _firestore
        .collection(targetCollection)
        .where('name', isGreaterThanOrEqualTo: searchQuery)
        .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
        .snapshots();
  }

  // Delete message for current user only in thread system
  Future<void> deleteMessageForMe(String messageId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Try to find the message in thread subcollections
      final threadsSnapshot = await _firestore.collection('threads').get();

      for (final threadDoc in threadsSnapshot.docs) {
        final messageDoc = await _firestore
            .collection('threads')
            .doc(threadDoc.id)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          await messageDoc.reference.update({
            'isDeleted': true,
            'deletedBy': currentUser.uid,
          });
          return;
        }
      }

      // Fallback: try old messages collection
      await _firestore.collection('messages').doc(messageId).update({
        'isDeleted': true,
        'deletedBy': currentUser.uid,
      });
    } catch (e) {
      print('Delete message for me error: $e');
      rethrow;
    }
  }

  // Unsend message (delete for everyone) in thread system
  /// Unsend message (delete for everyone)
  Future<void> unsendMessage(String messageId) async {
    try {
      // Try to find the message in thread subcollections
      final threadsSnapshot = await _firestore.collection('threads').get();

      for (final threadDoc in threadsSnapshot.docs) {
        final messageDoc = await _firestore
            .collection('threads')
            .doc(threadDoc.id)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          await messageDoc.reference.update({
            'isUnsent': true,
            'content': 'This message was unsent',
            'editedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      }

      // Fallback: try old messages collection
      await _firestore.collection('messages').doc(messageId).update({
        'isUnsent': true,
        'content': 'This message was unsent',
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Unsend message error: $e');
      rethrow;
    }
  }

  /// Edit a message in thread system
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      // Try to find the message in thread subcollections
      final threadsSnapshot = await _firestore.collection('threads').get();

      for (final threadDoc in threadsSnapshot.docs) {
        final messageDoc = await _firestore
            .collection('threads')
            .doc(threadDoc.id)
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          await messageDoc.reference.update({
            'content': newContent,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      }

      // Fallback: try old messages collection
      await _firestore.collection('messages').doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Edit message error: $e');
      rethrow;
    }
  }

  // Enhanced ChatService methods for new features

  // Archive a chat - using user preferences instead of chats collection
  Future<void> archiveChat(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Store archive preference in user profile
      await _firestore.collection('userProfiles').doc(currentUser.uid).set({
        'archivedChats': FieldValue.arrayUnion([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Archive chat error: $e');
      rethrow;
    }
  }

  // Unarchive a chat
  Future<void> unarchiveChat(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Remove archive preference from user profile
      await _firestore.collection('userProfiles').doc(currentUser.uid).set({
        'archivedChats': FieldValue.arrayRemove([otherUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Unarchive chat error: $e');
      rethrow;
    }
  }

  // Block a user
  Future<void> blockUser(String userId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Block user - using user profiles only

      // Add to user's blocked list (create profile if doesn't exist)
      await _firestore.collection('userProfiles').doc(currentUser.uid).set({
        'blockedUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Block user error: $e');
      rethrow;
    }
  }

  // Unblock a user
  Future<void> unblockUser(String userId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Unblock user - using user profiles only

      // Remove from user's blocked list (create profile if doesn't exist)
      await _firestore.collection('userProfiles').doc(currentUser.uid).set({
        'blockedUsers': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Unblock user error: $e');
      rethrow;
    }
  }

  // Typing indicators removed - using typing_collection_service instead

  // Delete chat with confirmation
  Future<void> deleteChat(
    String otherUserId, {
    bool deleteForBoth = false,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = _getChatId(currentUser.uid, otherUserId);

      if (deleteForBoth) {
        // Delete entire chat and all messages
        final batch = _firestore.batch();

        // Delete all messages in the chat
        final messagesQuery = await _firestore
            .collection('messages')
            .where('chatId', isEqualTo: chatId)
            .get();

        for (final doc in messagesQuery.docs) {
          batch.delete(doc.reference);
        }

        // Chat and typing collections removed - only delete messages

        await batch.commit();
      } else {
        // Mark as deleted in user profile
        await _firestore.collection('userProfiles').doc(currentUser.uid).set({
          'deletedChats': FieldValue.arrayUnion([otherUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Delete chat error: $e');
      rethrow;
    }
  }

  // Unread count tracking removed - using messages collection directly

  // Get unread count for specific chat
  Future<int> getUnreadCountForChat(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final chatId = _getChatId(currentUser.uid, otherUserId);

      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Get unread count for chat error: $e');
      return 0;
    }
  }

  // Send image message
  Future<void> sendImageMessage({
    required String receiverId,
    required String imageUrl,
    required String imageThumbnail,
    required String senderUserType,
    required String receiverUserType,
    String? caption,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = _getChatId(currentUser.uid, receiverId);

      // Add image message to messages collection
      await _firestore.collection('messages').add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'senderUserType': senderUserType,
        'receiverUserType': receiverUserType,
        'message': caption ?? 'Image',
        'messageType': MessageType.image.name,
        'imageUrl': imageUrl,
        'imageThumbnail': imageThumbnail,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Chat metadata removed - using messages collection only
    } catch (e) {
      print('Send image message error: $e');
      rethrow;
    }
  }

  // Report a user
  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    required String description,
    String? chatId,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _firestore.collection('reports').add({
        'reporterId': currentUser.uid,
        'reportedUserId': reportedUserId,
        'chatId': chatId,
        'reason': reason,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Report user error: $e');
      rethrow;
    }
  }

  // Helper method to ensure user profile exists
  Future<void> _ensureUserProfileExists(String userId) async {
    try {
      await _firestore.collection('userProfiles').doc(userId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'blockedUsers': [],
        'isBlocked': false,
        'isOnline': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Ensure user profile exists error: $e');
      // Don't rethrow as this is a helper method
    }
  }

  // Check if a user is blocked by current user
  Future<bool> isUserBlocked(String userId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final profileDoc = await _firestore
          .collection('userProfiles')
          .doc(currentUser.uid)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        return blockedUsers.contains(userId);
      }
      return false;
    } catch (e) {
      print('Check if user blocked error: $e');
      return false;
    }
  }

  // Check if current user is blocked by another user
  Future<bool> _isBlockedByUser(String userId) async {
    try {
      final profileDoc = await _firestore
          .collection('userProfiles')
          .doc(userId)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        User? currentUser = _auth.currentUser;
        return currentUser != null && blockedUsers.contains(currentUser.uid);
      }
      return false;
    } catch (e) {
      print('Check if blocked by user error: $e');
      return false;
    }
  }

  // Get chat block status
  Future<Map<String, dynamic>> getChatBlockStatus(String otherUserId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'isBlocked': false, 'blockedBy': null, 'canChat': true};
      }

      // Check blocking status from user profiles only
      bool isBlocked = false;
      String? blockedBy;

      // Also check user profiles for blocking
      final userBlocked = await isUserBlocked(otherUserId);
      final blockedByUser = await _isBlockedByUser(otherUserId);

      final canChat = !isBlocked && !userBlocked && !blockedByUser;

      return {
        'isBlocked': isBlocked || userBlocked || blockedByUser,
        'blockedBy': blockedBy,
        'canChat': canChat,
        'userBlocked': userBlocked,
        'blockedByUser': blockedByUser,
      };
    } catch (e) {
      print('Get chat block status error: $e');
      return {'isBlocked': false, 'blockedBy': null, 'canChat': true};
    }
  }
}
