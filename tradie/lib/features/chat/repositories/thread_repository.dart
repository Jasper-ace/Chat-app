import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified Thread Service that ensures ONE thread per tradie-homeowner conversation
/// Each conversation gets a unique threadID starting from 1
class UnifiedThreadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Utility Functions ---

  // --- Core Thread Operations ---

  /// Get or create thread between tradie and homeowner.
  /// This method ensures BOTH users always get the SAME thread with incremental threadID
  /// Uses transaction to prevent race conditions
  Future<String> getOrCreateThread({
    required int tradieId,
    required int homeownerId,
  }) async {
    print(
      '🔍 TRADIE: getOrCreateThread called with tradieId=$tradieId, homeownerId=$homeownerId',
    );

    // Validation: Check for invalid same-user scenario
    if (tradieId == homeownerId) {
      print('⚠️ WARNING: tradieId and homeownerId are the same ($tradieId)');
      print('⚠️ This indicates an authentication or data retrieval issue');
      print('⚠️ Proceeding anyway for debugging purposes...');
      // Temporarily allow this to proceed so we can debug
      // throw Exception('❌ Invalid thread: tradieId and homeownerId cannot be the same ($tradieId). This indicates a data integrity issue where both users have the same autoId.');
    }

    // Debug: Check what threads already exist
    final allThreads = await _firestore.collection('threads').get();
    print('   📊 Existing threads in Firebase:');
    for (var doc in allThreads.docs) {
      final data = doc.data();
      print(
        '     - ${doc.id}: tradie_id=${data['tradie_id']}, homeowner_id=${data['homeowner_id']}',
      );
    }

    // Use transaction to prevent race conditions
    return await _firestore.runTransaction<String>((transaction) async {
      // 1. Check for existing thread with multiple field name combinations
      // This handles both new format (tradie_id/homeowner_id) and old format (sender_1/sender_2)

      // Try new format first
      final existingThread1 = await _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: tradieId)
          .where('homeowner_id', isEqualTo: homeownerId)
          .limit(1)
          .get();

      final existingThread2 = await _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: homeownerId)
          .where('homeowner_id', isEqualTo: tradieId)
          .limit(1)
          .get();

      // Try old format (sender_1/sender_2) as fallback
      final existingThread3 = await _firestore
          .collection('threads')
          .where('sender_1', isEqualTo: tradieId)
          .where('sender_2', isEqualTo: homeownerId)
          .limit(1)
          .get();

      final existingThread4 = await _firestore
          .collection('threads')
          .where('sender_1', isEqualTo: homeownerId)
          .where('sender_2', isEqualTo: tradieId)
          .limit(1)
          .get();

      // Check all combinations
      final allResults = [
        existingThread1,
        existingThread2,
        existingThread3,
        existingThread4,
      ];

      print('   🔍 Query results:');
      for (int i = 0; i < allResults.length; i++) {
        print('     Query ${i + 1}: ${allResults[i].docs.length} results');
        if (allResults[i].docs.isNotEmpty) {
          final threadDoc = allResults[i].docs.first;
          final data = threadDoc.data();
          print('       Found thread: ${threadDoc.id} with data: $data');

          // Get thread ID from document
          int threadId;
          if (data.containsKey('thread_id')) {
            threadId = data['thread_id'] as int;
          } else {
            // Extract from document name as fallback
            threadId =
                int.tryParse(threadDoc.id.replaceAll('thread_', '')) ?? 1;
          }

          final threadDocName = 'thread_$threadId';
          print(
            '✅ TRADIE: Found existing thread (combo ${i + 1}): $threadDocName',
          );

          // Update thread with correct field names if needed
          if (!data.containsKey('tradie_id') ||
              !data.containsKey('homeowner_id')) {
            print('   🔧 Updating thread with correct field names');
            transaction.update(threadDoc.reference, {
              'tradie_id': tradieId,
              'homeowner_id': homeownerId,
              'thread_id': threadId,
            });
          }

          return threadDocName;
        }
      }

      print(
        '📝 TRADIE: No existing thread found via queries, checking all threads...',
      );

      // Fallback: Check all existing threads and see if any could be for this conversation
      final allThreadsQuery = await _firestore.collection('threads').get();
      print(
        '   📊 Found ${allThreadsQuery.docs.length} total threads in database',
      );

      for (var doc in allThreadsQuery.docs) {
        final data = doc.data();
        print('   📋 Thread ${doc.id}: $data');

        // Check if this thread could be for our conversation
        // Look for any combination of our user IDs in any field
        final allValues = data.values.toList();
        final hasOurIds =
            allValues.contains(tradieId) && allValues.contains(homeownerId);

        if (hasOurIds) {
          print('   ✅ Found matching thread by ID values: ${doc.id}');

          // Update this thread with correct field names
          transaction.update(doc.reference, {
            'tradie_id': tradieId,
            'homeowner_id': homeownerId,
            'thread_id': int.tryParse(doc.id.replaceAll('thread_', '')) ?? 1,
          });

          return doc.id;
        }
      }

      print('📝 TRADIE: No matching thread found, creating new one...');

      // 2. Get next thread ID using transaction
      final counterRef = _firestore
          .collection('counters')
          .doc('thread_counter');
      final counterDoc = await transaction.get(counterRef);

      int nextId = 1;
      if (counterDoc.exists) {
        nextId = (counterDoc.data()?['current_id'] as int? ?? 0) + 1;
      }

      final threadDocName = 'thread_$nextId';
      final threadRef = _firestore.collection('threads').doc(threadDocName);

      print('📝 TRADIE: Creating thread: $threadDocName (ID: $nextId)');

      // 3. Create thread document
      transaction.set(threadRef, {
        'thread_id': nextId,
        'tradie_id': tradieId,
        'homeowner_id': homeownerId,
        'sender_1': tradieId, // For compatibility
        'sender_2': homeownerId, // For compatibility
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_time': FieldValue.serverTimestamp(),
        'is_archived': false,
        'is_deleted': false,
        'message_count': 0, // Initialize message counter for sequential IDs
      });

      // 4. Update counter
      transaction.set(counterRef, {
        'current_id': nextId,
      }, SetOptions(merge: true));

      print('✅ TRADIE: Thread created successfully: $threadDocName');
      return threadDocName;
    });
  }

  /// Send message - works for both tradie and homeowner
  /// Explicitly accepts threadId for clarity and performance.
  Future<void> sendMessage({
    required int senderId,
    required String senderType, // 'tradie' or 'homeowner'
    required int receiverId,
    required String receiverType, // 'tradie' or 'homeowner'
    required String content,
    String? threadId, // ADDED for explicit thread targeting
  }) async {
    print('🔄 UnifiedThreadService.sendMessage called');
    print('   📊 Input: senderId=$senderId, senderType=$senderType');
    print('   📊 Input: receiverId=$receiverId, receiverType=$receiverType');

    // 1. Determine tradie and homeowner IDs consistently
    int tradieId, homeownerId;
    if (senderType == 'tradie') {
      tradieId = senderId;
      homeownerId = receiverId;
    } else if (senderType == 'homeowner') {
      tradieId = receiverId;
      homeownerId = senderId;
    } else {
      throw Exception('Invalid sender type: $senderType');
    }

    print('   📊 Determined: tradieId=$tradieId, homeownerId=$homeownerId');

    // 2. Get or create the SAME thread using incremental ID
    final threadDocName =
        threadId ??
        await getOrCreateThread(tradieId: tradieId, homeownerId: homeownerId);

    print('   Thread: $threadDocName');

    final threadRef = _firestore.collection('threads').doc(threadDocName);

    // 3. Use a Transaction to safely get the next sequential message ID
    await _firestore.runTransaction((transaction) async {
      final freshThreadDoc = await transaction.get(threadRef);
      final currentCount = freshThreadDoc.data()?['message_count'] as int? ?? 0;
      final newMessageId = currentCount + 1;
      final messageDocName = 'msg_$newMessageId';

      print('   New Message ID: $newMessageId, Doc: $messageDocName');

      // 4. Add message to thread
      final messageRef = threadRef.collection('messages').doc(messageDocName);

      transaction.set(messageRef, {
        'message_id': newMessageId, // Use the sequential integer for ordering
        'sender_id': senderId,
        'sender_type': senderType,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 5. Update thread metadata and increment message counter
      transaction.update(threadRef, {
        'last_message': content,
        'last_message_time': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'message_count': newMessageId, // Update the counter
      });

      print(
        '   ✅ Message added and Thread updated successfully in transaction.',
      );
    });
  }

  // --- Data Retrieval Operations ---

  /// Get unread message count stream for real-time updates
  Stream<int> getUnreadMessageCountStream({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) async* {
    // 1. Determine IDs consistently
    int tradieId, homeownerId;
    if (currentUserType == 'tradie') {
      tradieId = currentUserId;
      homeownerId = otherUserId;
    } else {
      tradieId = otherUserId;
      homeownerId = currentUserId;
    }

    // 2. Listen to thread changes
    await for (final threadQuery
        in _firestore
            .collection('threads')
            .where('tradie_id', isEqualTo: tradieId)
            .where('homeowner_id', isEqualTo: homeownerId)
            .limit(1)
            .snapshots()) {
      if (threadQuery.docs.isEmpty) {
        yield 0;
        continue;
      }

      final threadDoc = threadQuery.docs.first;

      // 3. Listen to unread messages in this thread
      await for (final messagesQuery
          in _firestore
              .collection('threads')
              .doc(threadDoc.id)
              .collection('messages')
              .where('sender_id', isNotEqualTo: currentUserId)
              .where('status', whereIn: ['sent', 'delivered'])
              .snapshots()) {
        yield messagesQuery.docs.length;
        break; // Only yield once per thread update
      }
    }
  }

  /// Get unread message count
  Future<int> getUnreadMessageCount({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) async {
    try {
      // 1. Determine IDs consistently
      int tradieId, homeownerId;
      if (currentUserType == 'tradie') {
        tradieId = currentUserId;
        homeownerId = otherUserId;
      } else {
        tradieId = otherUserId;
        homeownerId = currentUserId;
      }

      // 2. Find thread by tradie and homeowner IDs
      final threadQuery = await _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: tradieId)
          .where('homeowner_id', isEqualTo: homeownerId)
          .limit(1)
          .get();

      if (threadQuery.docs.isEmpty) return 0;

      final threadDocName = threadQuery.docs.first.id;

      // 3. Get unread messages from other user
      final unreadMessages = await _firestore
          .collection('threads')
          .doc(threadDocName)
          .collection('messages')
          .where('sender_id', isEqualTo: otherUserId)
          .where('read', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('   ❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get last message stream for real-time updates
  Stream<Map<String, dynamic>?> getLastMessageStream({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) async* {
    // 1. Determine IDs consistently
    int tradieId, homeownerId;
    if (currentUserType == 'tradie') {
      tradieId = currentUserId;
      homeownerId = otherUserId;
    } else {
      tradieId = otherUserId;
      homeownerId = currentUserId;
    }

    // 2. Listen to thread changes
    await for (final threadQuery
        in _firestore
            .collection('threads')
            .where('tradie_id', isEqualTo: tradieId)
            .where('homeowner_id', isEqualTo: homeownerId)
            .limit(1)
            .snapshots()) {
      if (threadQuery.docs.isEmpty) {
        yield null;
        continue;
      }

      final threadDoc = threadQuery.docs.first;

      // 3. Listen to latest message in this thread
      await for (final messagesQuery
          in _firestore
              .collection('threads')
              .doc(threadDoc.id)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .snapshots()) {
        if (messagesQuery.docs.isEmpty) {
          yield null;
        } else {
          final lastMessage = messagesQuery.docs.first.data();
          yield {
            'content': lastMessage['content'] ?? '',
            'senderName': '',
            'timestamp': lastMessage['timestamp'],
          };
        }
        break; // Only yield once per thread update
      }
    }
  }

  /// Get last message for conversation
  Future<Map<String, dynamic>?> getLastMessage({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
  }) async {
    try {
      // 1. Determine IDs consistently
      int tradieId, homeownerId;
      if (currentUserType == 'tradie') {
        tradieId = currentUserId;
        homeownerId = otherUserId;
      } else {
        tradieId = otherUserId;
        homeownerId = currentUserId;
      }

      // 2. Find thread by tradie and homeowner IDs
      final threadQuery = await _firestore
          .collection('threads')
          .where('tradie_id', isEqualTo: tradieId)
          .where('homeowner_id', isEqualTo: homeownerId)
          .limit(1)
          .get();

      if (threadQuery.docs.isEmpty) return null;

      final threadDoc = threadQuery.docs.first;
      final threadDocName = threadDoc.id;
      final threadData = threadDoc.data();

      // 3. Get most recent message using message_id for ordering
      final messagesQuery = await _firestore
          .collection('threads')
          .doc(threadDocName)
          .collection('messages')
          .orderBy('message_id', descending: true)
          .limit(1)
          .get();

      if (messagesQuery.docs.isEmpty) {
        return {
          'content': threadData['last_message'] ?? '',
          'senderName': 'Unknown',
          'timestamp': threadData['last_message_time'],
        };
      }

      final lastMessage = messagesQuery.docs.first.data();
      final senderId = lastMessage['sender_id'] as int;
      final senderType = lastMessage['sender_type'] as String;

      // 4. Get sender name
      String senderName = 'Unknown';

      // Check if the sender is the current user
      print(
        '🔍 DEBUG UnifiedThread TRADIE: senderId=$senderId, currentUserId=$currentUserId',
      );
      if (senderId == currentUserId) {
        senderName = 'You';
        print('🔍 DEBUG UnifiedThread TRADIE: Setting senderName to "You"');
      } else {
        try {
          final senderCollection = senderType == 'tradie'
              ? 'tradies'
              : 'homeowners';

          final senderDoc = await _firestore
              .collection(senderCollection)
              .where('autoId', isEqualTo: senderId)
              .limit(1)
              .get();

          if (senderDoc.docs.isNotEmpty) {
            final fullName = senderDoc.docs.first.data()['name'] ?? 'Unknown';
            // Extract first name only (e.g., "John M Doe" -> "John")
            senderName = fullName.split(' ').first;
            print(
              '🔍 DEBUG UnifiedThread TRADIE: Other user fullName=$fullName, firstName=$senderName',
            );
          }
        } catch (e) {
          // Use default name
        }
      }

      // Simplified - just return content
      return {
        'content': lastMessage['content'] ?? '',
        'senderName': senderName,
        'timestamp': lastMessage['timestamp'],
      };
    } catch (e) {
      print('   ❌ Error getting last message: $e');
      return null;
    }
  }

  /// Get messages stream for conversation
  Stream<QuerySnapshot> getMessages({
    required int currentUserId,
    required String currentUserType,
    required int otherUserId,
    required String otherUserType,
    String? threadId, // ADDED: Use explicit ID if provided
  }) async* {
    try {
      print('🔍 UnifiedThreadService.getMessages called');

      // 1. Determine IDs consistently
      int tradieId, homeownerId;
      if (currentUserType == 'tradie') {
        tradieId = currentUserId;
        homeownerId = otherUserId;
      } else {
        tradieId = otherUserId;
        homeownerId = currentUserId;
      }

      // 2. Find thread by tradie and homeowner IDs (or use provided threadId)
      String threadDocName;
      if (threadId != null) {
        threadDocName = threadId;
      } else {
        // Use the same robust thread finding logic as getOrCreateThread
        final existingThread1 = await _firestore
            .collection('threads')
            .where('tradie_id', isEqualTo: tradieId)
            .where('homeowner_id', isEqualTo: homeownerId)
            .limit(1)
            .get();

        final existingThread2 = await _firestore
            .collection('threads')
            .where('tradie_id', isEqualTo: homeownerId)
            .where('homeowner_id', isEqualTo: tradieId)
            .limit(1)
            .get();

        final existingThread3 = await _firestore
            .collection('threads')
            .where('sender_1', isEqualTo: tradieId)
            .where('sender_2', isEqualTo: homeownerId)
            .limit(1)
            .get();

        final existingThread4 = await _firestore
            .collection('threads')
            .where('sender_1', isEqualTo: homeownerId)
            .where('sender_2', isEqualTo: tradieId)
            .limit(1)
            .get();

        final allResults = [
          existingThread1,
          existingThread2,
          existingThread3,
          existingThread4,
        ];

        QueryDocumentSnapshot? foundThread;
        for (final result in allResults) {
          if (result.docs.isNotEmpty) {
            foundThread = result.docs.first;
            break;
          }
        }

        if (foundThread == null) {
          print('   No thread exists yet, returning empty stream');
          // Return empty stream for non-existent thread
          yield await _firestore
              .collection('threads')
              .doc('nonexistent')
              .collection('messages')
              .limit(1)
              .get();
          return;
        }

        threadDocName = foundThread.id;
      }

      print('   Found thread: $threadDocName');

      // 3. Stream messages from the thread ordered by message_id
      yield* _firestore
          .collection('threads')
          .doc(threadDocName)
          .collection('messages')
          .orderBy('message_id')
          .snapshots()
          .map((snapshot) {
            print(
              '   📨 Messages stream update: ${snapshot.docs.length} messages',
            );
            return snapshot;
          });
    } catch (e) {
      print('   ❌ Error in messages stream: $e');
      // Return an empty, failed snapshot
      yield await _firestore
          .collection('threads')
          .doc('fail')
          .collection('messages')
          .limit(1)
          .get();
    }
  }
}
