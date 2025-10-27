import 'package:cloud_firestore/cloud_firestore.dart';

class StructureMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Migrate from old structure to simplified 2-collection structure
  Future<void> migrateToSimplifiedStructure() async {
    print('Starting migration to simplified Firebase structure...');

    try {
      // Step 1: Migrate chats to threads
      await _migrateChatsToThreads();

      // Step 2: Update messages to use thread_id
      await _updateMessagesToUseThreadId();

      // Step 3: Migrate typing indicators to thread documents
      await _migrateTypingIndicatorsToThreads();

      // Step 4: Clean up old collections (optional - commented out for safety)
      // await _cleanupOldCollections();

      print('Migration completed successfully!');
    } catch (e) {
      print('Migration failed: $e');
      rethrow;
    }
  }

  // Step 1: Convert chats collection to threads collection
  Future<void> _migrateChatsToThreads() async {
    print('Migrating chats to threads...');

    final chatsSnapshot = await _firestore.collection('chats').get();
    final batch = _firestore.batch();
    int batchCount = 0;

    for (final chatDoc in chatsSnapshot.docs) {
      final chatData = chatDoc.data();
      final participants = List<String>.from(chatData['participants'] ?? []);

      if (participants.length >= 2) {
        // Create thread document
        final threadRef = _firestore.collection('threads').doc(chatDoc.id);

        // Determine user types (you may need to adjust this logic)
        final sender1Type = await _getUserType(
          int.tryParse(participants[0]) ?? 0,
        );
        final sender2Type = await _getUserType(
          int.tryParse(participants[1]) ?? 0,
        );

        final threadData = {
          'sender_1': participants[0],
          'sender_2': participants[1],
          'sender_1_type': sender1Type,
          'sender_2_type': sender2Type,
          'created_at': chatData['createdAt'] ?? FieldValue.serverTimestamp(),
          'updated_at':
              chatData['lastMessageTimestamp'] ?? FieldValue.serverTimestamp(),
          'last_message': chatData['lastMessage'],
          'last_message_time': chatData['lastMessageTimestamp'],
          'read_status': _convertReadStatus(
            chatData['readStatus'],
            participants,
          ),
          'typing_status': {},
          'blocked_status': _convertBlockedStatus(
            chatData['blockedUsers'],
            participants,
          ),
          'is_archived': chatData['isArchived'] ?? false,
        };

        batch.set(threadRef, threadData);
        batchCount++;

        // Commit batch every 500 operations
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    print('Chats to threads migration completed');
  }

  // Step 2: Update messages to use thread_id instead of chatId
  Future<void> _updateMessagesToUseThreadId() async {
    print('Updating messages to use thread_id...');

    final messagesSnapshot = await _firestore.collection('messages').get();
    final batch = _firestore.batch();
    int batchCount = 0;

    for (final messageDoc in messagesSnapshot.docs) {
      final messageData = messageDoc.data();

      // Update field names to match SQL structure
      final updatedData = {
        'thread_id': messageData['chatId'], // chatId becomes thread_id
        'sender_id': messageData['senderId'], // Keep sender_id
        'content':
            messageData['message'] ??
            messageData['content'], // message becomes content
        'date':
            messageData['timestamp'] ??
            FieldValue.serverTimestamp(), // timestamp becomes date
        'messageType': messageData['messageType'] ?? 'text',
        'imageUrl': messageData['imageUrl'],
        'imageThumbnail': messageData['imageThumbnail'],
        'read': messageData['read'] ?? false,
        'isDeleted': messageData['isDeleted'] ?? false,
        'isUnsent': messageData['isUnsent'] ?? false,
        'deletedBy': messageData['deletedBy'],
      };

      // Remove old fields
      final fieldsToRemove = [
        'chatId',
        'message',
        'timestamp',
        'receiverId',
        'senderUserType',
        'receiverUserType',
      ];
      for (final field in fieldsToRemove) {
        updatedData[field] = FieldValue.delete();
      }

      batch.update(messageDoc.reference, updatedData);
      batchCount++;

      // Commit batch every 500 operations
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    print('Messages update completed');
  }

  // Step 3: Migrate typing indicators to thread documents
  Future<void> _migrateTypingIndicatorsToThreads() async {
    print('Migrating typing indicators to threads...');

    try {
      final typingSnapshot = await _firestore.collection('typing').get();
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final typingDoc in typingSnapshot.docs) {
        final typingData = typingDoc.data();
        final chatId = typingDoc.id;

        // Find corresponding thread
        final threadRef = _firestore.collection('threads').doc(chatId);
        final threadDoc = await threadRef.get();

        if (threadDoc.exists) {
          final typingStatus = <String, dynamic>{};

          // Convert typing data to embedded format
          if (typingData['typingUsers'] != null) {
            final typingUsers = Map<String, dynamic>.from(
              typingData['typingUsers'],
            );
            for (final entry in typingUsers.entries) {
              if (entry.value == true) {
                typingStatus[entry.key] = FieldValue.serverTimestamp();
              }
            }
          }

          batch.update(threadRef, {'typing_status': typingStatus});
          batchCount++;

          // Commit batch every 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print(
        'Typing indicators migration failed (collection may not exist): $e',
      );
    }

    print('Typing indicators migration completed');
  }

  // Helper: Determine user type (tradie or homeowner)
  Future<String> _getUserType(int userId) async {
    // Check if user exists in tradies collection
    final tradieDoc = await _firestore
        .collection('tradies')
        .doc(userId.toString())
        .get();
    if (tradieDoc.exists) {
      return 'tradie';
    }

    // Check if user exists in homeowners collection
    final homeownerDoc = await _firestore
        .collection('homeowners')
        .doc(userId.toString())
        .get();
    if (homeownerDoc.exists) {
      return 'homeowner';
    }

    // Default fallback
    return 'user';
  }

  // Helper: Convert read status format
  Map<String, bool> _convertReadStatus(
    dynamic readStatus,
    List<String> participants,
  ) {
    final result = <String, bool>{};

    if (readStatus is Map) {
      for (final participant in participants) {
        result[participant] = readStatus[participant] ?? false;
      }
    } else {
      // Default all to unread
      for (final participant in participants) {
        result[participant] = false;
      }
    }

    return result;
  }

  // Helper: Convert blocked status format
  Map<String, bool> _convertBlockedStatus(
    dynamic blockedUsers,
    List<String> participants,
  ) {
    final result = <String, bool>{};

    if (blockedUsers is List) {
      for (final participant in participants) {
        result[participant] = blockedUsers.contains(participant);
      }
    } else {
      // Default all to not blocked
      for (final participant in participants) {
        result[participant] = false;
      }
    }

    return result;
  }

  // Step 4: Clean up old collections (use with caution!)
  Future<void> _cleanupOldCollections() async {
    print(
      'WARNING: This will delete old collections. Make sure you have backups!',
    );
    print('Cleaning up old collections...');

    // Delete old collections
    final collectionsToDelete = ['chats', 'typing', 'typing_indicators'];

    for (final collectionName in collectionsToDelete) {
      try {
        final snapshot = await _firestore.collection(collectionName).get();
        final batch = _firestore.batch();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        print('Deleted collection: $collectionName');
      } catch (e) {
        print('Failed to delete collection $collectionName: $e');
      }
    }

    print('Cleanup completed');
  }

  // Verify migration integrity
  Future<void> verifyMigration() async {
    print('Verifying migration...');

    final threadsCount = await _firestore.collection('threads').count().get();
    final messagesCount = await _firestore.collection('messages').count().get();

    print('Threads count: ${threadsCount.count}');
    print('Messages count: ${messagesCount.count}');

    // Check if messages have correct field names
    final sampleMessage = await _firestore
        .collection('messages')
        .limit(1)
        .get();
    if (sampleMessage.docs.isNotEmpty) {
      final messageData = sampleMessage.docs.first.data();
      final hasCorrectFields =
          messageData.containsKey('thread_id') &&
          messageData.containsKey('sender_id') &&
          messageData.containsKey('content') &&
          messageData.containsKey('date');

      print('Messages have correct field structure: $hasCorrectFields');
    }

    print('Migration verification completed');
  }
}
