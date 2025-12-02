import 'package:firebase_database/firebase_database.dart';
import '../services/chat_api_service.dart';

/// Chat Repository using Firebase Realtime Database
/// - Sends messages through Laravel API (Laravel writes to Firebase)
/// - Reads messages directly from Firebase Realtime Database (real-time)
/// - No Firebase Auth needed
class ChatRepository {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ChatApiService _apiService = ChatApiService();

  /// Send message through Laravel API
  /// Laravel will write to Firebase using Admin SDK
  Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String senderType,
    required String receiverType,
    required String message,
    required String chatId,
  }) async {
    try {
      await _apiService.sendMessage(
        chatId: chatId,
        senderId: senderId.toString(),
        senderType: senderType,
        receiverId: receiverId.toString(),
        receiverType: receiverType,
        message: message,
      );

      return true;
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  /// Get messages from Firebase Realtime Database (real-time)
  /// Flutter only reads, never writes
  Stream<List<Map<String, dynamic>>> getMessages({
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

    // Listen to all threads and filter for our conversation
    return _database.child('threads').onValue.asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        print('📖 No threads found');
        return <Map<String, dynamic>>[];
      }

      // Find the thread for this conversation
      String? threadId;
      for (var entry in data.entries) {
        final thread = entry.value as Map<dynamic, dynamic>;
        if (thread['tradie_id'] == tradieId &&
            thread['homeowner_id'] == homeownerId) {
          threadId = entry.key;
          break;
        }
      }

      if (threadId == null) {
        print('📖 No thread found for this conversation');
        return <Map<String, dynamic>>[];
      }

      print('📖 Found thread: $threadId');

      // Get messages from this thread
      final messagesSnapshot = await _database
          .child('threads/$threadId/messages')
          .get();

      final messagesData = messagesSnapshot.value as Map<dynamic, dynamic>?;

      if (messagesData == null) {
        print('📖 No messages in thread');
        return <Map<String, dynamic>>[];
      }

      // Convert to list and sort by date
      final messages = <Map<String, dynamic>>[];
      messagesData.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value as Map);
        msg['id'] = key;
        messages.add(msg);
      });

      // Sort by date (newest first)
      messages.sort((a, b) {
        final aDate = a['date'] as int? ?? 0;
        final bDate = b['date'] as int? ?? 0;
        return bDate.compareTo(aDate);
      });

      print('📖 Loaded ${messages.length} messages');
      return messages;
    });
  }

  /// Get threads for current user (real-time)
  Stream<List<Map<String, dynamic>>> getThreads({
    required int userId,
    required String userType,
  }) {
    return _database.child('threads').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return <Map<String, dynamic>>[];

      final threads = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final thread = Map<String, dynamic>.from(value as Map);
        thread['id'] = key;

        // Filter by user type
        if (userType == 'tradie' && thread['tradie_id'] == userId) {
          threads.add(thread);
        } else if (userType == 'homeowner' &&
            thread['homeowner_id'] == userId) {
          threads.add(thread);
        }
      });

      // Sort by last message time
      threads.sort((a, b) {
        final aTime = a['last_message_time'] as int? ?? 0;
        final bTime = b['last_message_time'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });

      return threads;
    });
  }

  /// Create or get chat room through Laravel
  Future<String?> createRoom({
    required int tradieId,
    required int homeownerId,
  }) async {
    try {
      final result = await _apiService.createChatRoom(
        participant1Id: homeownerId.toString(),
        participant1Type: 'homeowner',
        participant2Id: tradieId.toString(),
        participant2Type: 'tradie',
      );

      return result;
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
      // TODO: Implement block user API
      return true;
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
      // TODO: Implement unblock user API
      return true;
    } catch (e) {
      print('Unblock user error: $e');
      return false;
    }
  }

  /// Check if user is blocked (read from Firebase)
  Future<bool> isUserBlocked({
    required int currentUserId,
    required int otherUserId,
  }) async {
    try {
      final snapshot = await _database
          .child('userProfiles/$currentUserId')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final blockedUsers = List<int>.from(data['blockedUsers'] ?? []);
        return blockedUsers.contains(otherUserId);
      }
      return false;
    } catch (e) {
      print('Check if user blocked error: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user (read from Firebase)
  Future<bool> isBlockedByUser({
    required int currentUserId,
    required int otherUserId,
  }) async {
    try {
      final snapshot = await _database.child('userProfiles/$otherUserId').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final blockedUsers = List<int>.from(data['blockedUsers'] ?? []);
        return blockedUsers.contains(currentUserId);
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
  Stream<Map<dynamic, dynamic>?> listenToBlockStatus(int userId) {
    return _database
        .child('userProfiles/$userId')
        .onValue
        .map((event) => event.snapshot.value as Map<dynamic, dynamic>?);
  }

  /// Get chat statistics
  Future<Map<String, dynamic>?> getChatStats(int userId) async {
    // TODO: Implement get chat stats
    return null;
  }

  /// Get unread count for a thread (read from Firebase)
  Future<int> getUnreadCount({
    required int currentUserId,
    required String threadId,
  }) async {
    try {
      final snapshot = await _database
          .child('threads/$threadId/messages')
          .get();

      if (!snapshot.exists) return 0;

      final messages = snapshot.value as Map<dynamic, dynamic>;
      int unreadCount = 0;

      messages.forEach((key, value) {
        final msg = value as Map<dynamic, dynamic>;
        if (msg['sender_id'] != currentUserId && !(msg['read'] ?? false)) {
          unreadCount++;
        }
      });

      return unreadCount;
    } catch (e) {
      print('Get unread count error: $e');
      return 0;
    }
  }
}
