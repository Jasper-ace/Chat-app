import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_api_service.dart';

/// New Chat Repository
/// - Sends messages through Laravel API (Laravel writes to Firestore)
/// - Reads messages directly from Firestore (real-time)
/// - No Firebase Auth needed
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send message through Laravel API
  /// Laravel will write to Firestore using Firebase Admin SDK
  Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String senderType,
    required String receiverType,
    required String message,
  }) async {
    try {
      final result = await ChatApiService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        senderType: senderType,
        receiverType: receiverType,
        message: message,
      );

      return result['success'] == true;
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  /// Get messages from Firestore (real-time)
  /// Flutter only reads, never writes
  Stream<QuerySnapshot> getMessages({
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

    print('📖 Reading messages: tradie=$tradieId, homeowner=$homeownerId');

    // Find thread and stream messages
    return _firestore
        .collection('threads')
        .where('tradie_id', isEqualTo: tradieId)
        .where('homeowner_id', isEqualTo: homeownerId)
        .limit(1)
        .snapshots()
        .asyncExpand((threadSnapshot) {
          if (threadSnapshot.docs.isEmpty) {
            print('📖 No thread found, returning empty stream');
            // Return empty stream
            return Stream.fromFuture(
              _firestore
                  .collection('threads')
                  .doc('nonexistent')
                  .collection('messages')
                  .get(),
            );
          }

          final threadId = threadSnapshot.docs.first.id;
          print('📖 Found thread: $threadId, streaming messages...');

          // Stream messages from thread
          return _firestore
              .collection('threads')
              .doc(threadId)
              .collection('messages')
              .orderBy('date', descending: true)
              .snapshots();
        });
  }

  /// Get threads for current user (real-time)
  Stream<QuerySnapshot> getThreads({
    required int userId,
    required String userType,
  }) {
    if (userType == 'tradie') {
      return _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: userId)
          .orderBy('last_message_time', descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection('threads')
          .where('homeowner_id', isEqualTo: userId)
          .orderBy('last_message_time', descending: true)
          .snapshots();
    }
  }

  /// Create or get chat room through Laravel
  Future<String?> createRoom({
    required int tradieId,
    required int homeownerId,
  }) async {
    try {
      final result = await ChatApiService.createRoom(
        tradieId: tradieId,
        homeownerId: homeownerId,
      );

      if (result['success'] == true) {
        return result['room_id'];
      }
      return null;
    } catch (e) {
      print('Create room error: $e');
      return null;
    }
  }

  /// Block user through Laravel API
  Future<bool> blockUser({
    required int blockerId,
    required int blockedId,
  }) async {
    try {
      final result = await ChatApiService.blockUser(
        blockerId: blockerId,
        blockedId: blockedId,
      );

      return result['success'] == true;
    } catch (e) {
      print('Block user error: $e');
      return false;
    }
  }

  /// Unblock user through Laravel API
  Future<bool> unblockUser({
    required int blockerId,
    required int blockedId,
  }) async {
    try {
      final result = await ChatApiService.unblockUser(
        blockerId: blockerId,
        blockedId: blockedId,
      );

      return result['success'] == true;
    } catch (e) {
      print('Unblock user error: $e');
      return false;
    }
  }

  /// Check if user is blocked (read from Firestore)
  Future<bool> isUserBlocked({
    required int currentUserId,
    required int otherUserId,
  }) async {
    try {
      final profileDoc = await _firestore
          .collection('userProfiles')
          .doc(currentUserId.toString())
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        return blockedUsers.contains(otherUserId.toString());
      }
      return false;
    } catch (e) {
      print('Check if user blocked error: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user (read from Firestore)
  Future<bool> isBlockedByUser({
    required int currentUserId,
    required int otherUserId,
  }) async {
    try {
      final profileDoc = await _firestore
          .collection('userProfiles')
          .doc(otherUserId.toString())
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        return blockedUsers.contains(currentUserId.toString());
      }
      return false;
    } catch (e) {
      print('Check if blocked by user error: $e');
      return false;
    }
  }

  /// Get chat block status
  Future<Map<String, bool>> getBlockStatus({
    required int currentUserId,
    required int otherUserId,
  }) async {
    final userBlocked = await isUserBlocked(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );

    final blockedByUser = await isBlockedByUser(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );

    return {
      'userBlocked': userBlocked,
      'blockedByUser': blockedByUser,
      'canChat': !userBlocked && !blockedByUser,
    };
  }

  /// Listen to block status changes (real-time)
  Stream<DocumentSnapshot> listenToBlockStatus(int userId) {
    return _firestore
        .collection('userProfiles')
        .doc(userId.toString())
        .snapshots();
  }

  /// Get chat statistics
  Future<Map<String, dynamic>?> getChatStats(int userId) async {
    return await ChatApiService.getChatStats(userId);
  }

  /// Get unread count for a thread (read from Firestore)
  Future<int> getUnreadCount({
    required int currentUserId,
    required String threadId,
  }) async {
    try {
      final messages = await _firestore
          .collection('threads')
          .doc(threadId)
          .collection('messages')
          .where('sender_id', isNotEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      return messages.docs.length;
    } catch (e) {
      print('Get unread count error: $e');
      return 0;
    }
  }
}
