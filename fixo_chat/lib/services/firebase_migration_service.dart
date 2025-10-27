import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Migrate typing data from separate collection to chat documents
  Future<void> migrateTypingData() async {
    print('🔄 Starting typing data migration...');

    try {
      final typingCollection = _firestore.collection('typing');
      final chatsCollection = _firestore.collection('chats');

      final typingDocs = await typingCollection.get();
      print('📊 Found ${typingDocs.docs.length} typing documents to migrate');

      int migratedCount = 0;

      for (final doc in typingDocs.docs) {
        final typingData = doc.data();
        final chatId = doc.id;

        // Convert old typing structure to new format
        Map<String, dynamic> typingStatus = {};
        if (typingData['typingUsers'] != null) {
          final typingUsers = typingData['typingUsers'] as Map<String, dynamic>;
          typingUsers.forEach((userId, timestamp) {
            typingStatus[userId] = timestamp;
          });
        }

        // Update chat document with typing status
        await chatsCollection.doc(chatId).update({
          'typing_status': typingStatus,
          'updated_at': FieldValue.serverTimestamp(),
        });

        migratedCount++;
        print('✅ Migrated typing data for chat: $chatId');
      }

      print('🎉 Successfully migrated $migratedCount typing documents');
      print(
        '⚠️  Remember to manually delete the typing collection after verification',
      );
    } catch (e) {
      print('❌ Error during typing migration: $e');
      rethrow;
    }
  }

  // Migrate old message structure to new optimized structure
  Future<void> migrateMessageStructure() async {
    print('🔄 Starting message structure migration...');

    try {
      final messagesCollection = _firestore.collection('messages');

      // Process messages in batches
      Query query = messagesCollection.orderBy('timestamp').limit(500);

      bool hasMore = true;
      int totalMigrated = 0;

      while (hasMore) {
        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        final batch = _firestore.batch();

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Create new structure
          Map<String, dynamic> newData = {
            'chat_id': data['chatId'] ?? data['chat_id'],
            'sender_id': data['senderId'] ?? data['sender_id'],
            'sender_type': data['senderUserType'] ?? data['sender_type'],
            'content': data['message'] ?? data['content'],
            'message_type': data['messageType'] ?? 'text',
            'timestamp': data['timestamp'],
          };

          // Migrate read status
          if (data['read'] != null) {
            newData['read_by'] = {
              data['receiverId'] ?? data['receiver_id']: data['read'] == true
                  ? data['timestamp']
                  : null,
            };
          }

          // Add media fields if they exist
          if (data['imageUrl'] != null) {
            newData['media_url'] = data['imageUrl'];
            newData['message_type'] = 'image';
          }
          if (data['imageThumbnail'] != null) {
            newData['media_thumbnail'] = data['imageThumbnail'];
          }

          // Update document
          batch.update(doc.reference, newData);
        }

        await batch.commit();
        totalMigrated += snapshot.docs.length;

        print(
          '✅ Migrated ${snapshot.docs.length} messages (Total: $totalMigrated)',
        );

        // Set up next batch
        query = messagesCollection
            .orderBy('timestamp')
            .startAfterDocument(snapshot.docs.last)
            .limit(500);
      }

      print('🎉 Successfully migrated $totalMigrated messages');
    } catch (e) {
      print('❌ Error during message migration: $e');
      rethrow;
    }
  }

  // Migrate user data to unified user_profiles collection
  Future<void> migrateUserProfiles() async {
    print('🔄 Starting user profiles migration...');

    try {
      final userProfilesCollection = _firestore.collection('user_profiles');

      // Migrate homeowners
      final homeowners = await _firestore.collection('homeowners').get();
      print('📊 Found ${homeowners.docs.length} homeowners to migrate');

      for (final doc in homeowners.docs) {
        final data = doc.data();

        final profileData = {
          'mysql_id': int.tryParse(doc.id) ?? 0,
          'user_type': 'homeowner',
          'display_name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'avatar_url': data['avatar'],
          'phone': data['phone'],
          'location': data['location'],
          'is_verified': data['isVerified'] ?? false,
          'blocked_users': [],
          'created_at': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        await userProfilesCollection
            .doc('homeowner_${doc.id}')
            .set(profileData);
        print('✅ Migrated homeowner: ${data['name']}');
      }

      // Migrate tradies
      final tradies = await _firestore.collection('tradies').get();
      print('📊 Found ${tradies.docs.length} tradies to migrate');

      for (final doc in tradies.docs) {
        final data = doc.data();

        final profileData = {
          'mysql_id': int.tryParse(doc.id) ?? 0,
          'user_type': 'tradie',
          'display_name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'avatar_url': data['avatar'],
          'phone': data['phone'],
          'trade_type': data['tradeType'],
          'is_verified': data['isVerified'] ?? false,
          'rating': data['rating'] ?? 0.0,
          'completed_jobs': data['completedJobs'] ?? 0,
          'blocked_users': [],
          'created_at': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        await userProfilesCollection.doc('tradie_${doc.id}').set(profileData);
        print('✅ Migrated tradie: ${data['name']}');
      }

      print('🎉 Successfully migrated user profiles');
      print('⚠️  Remember to update user authentication to use new IDs');
    } catch (e) {
      print('❌ Error during user profiles migration: $e');
      rethrow;
    }
  }

  // Update chat documents to use new structure
  Future<void> migrateChatsStructure() async {
    print('🔄 Starting chats structure migration...');

    try {
      final chatsCollection = _firestore.collection('chats');
      final chats = await chatsCollection.get();

      print('📊 Found ${chats.docs.length} chats to migrate');

      for (final doc in chats.docs) {
        final data = doc.data();

        Map<String, dynamic> updates = {};

        // Update field names to snake_case
        if (data['lastMessage'] != null) {
          updates['last_message'] = data['lastMessage'];
        }
        if (data['lastTimestamp'] != null) {
          updates['last_message_timestamp'] = data['lastTimestamp'];
        }
        if (data['lastSenderId'] != null) {
          updates['last_sender_id'] = data['lastSenderId'];
        }
        if (data['participantTypes'] != null) {
          updates['participant_types'] = data['participantTypes'];
        }
        if (data['isArchived'] != null) {
          updates['is_archived'] = data['isArchived'];
        }
        if (data['createdAt'] != null) {
          updates['created_at'] = data['createdAt'];
        }
        if (data['updatedAt'] != null) {
          updates['updated_at'] = data['updatedAt'];
        }

        // Initialize new fields
        if (data['unread_count'] == null) {
          updates['unread_count'] = {};
        }
        if (data['typing_status'] == null) {
          updates['typing_status'] = {};
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          print('✅ Updated chat structure: ${doc.id}');
        }
      }

      print('🎉 Successfully migrated chats structure');
    } catch (e) {
      print('❌ Error during chats migration: $e');
      rethrow;
    }
  }

  // Run complete migration
  Future<void> runCompleteMigration() async {
    print('🚀 Starting complete Firebase migration...');

    try {
      // Step 1: Migrate user profiles
      await migrateUserProfiles();

      // Step 2: Migrate chats structure
      await migrateChatsStructure();

      // Step 3: Migrate typing data
      await migrateTypingData();

      // Step 4: Migrate message structure
      await migrateMessageStructure();

      print('🎉 Complete migration finished successfully!');
      print('');
      print('📋 Post-migration checklist:');
      print('1. ✅ Test the new optimized chat service');
      print('2. ✅ Update Flutter app to use new models');
      print('3. ✅ Update Laravel backend to use new structure');
      print('4. ⚠️  Manually delete old collections after verification:');
      print('   - typing collection');
      print('   - homeowners collection (optional)');
      print('   - tradies collection (optional)');
      print('5. ✅ Update Firebase security rules');
      print('6. ✅ Update Firebase indexes');
    } catch (e) {
      print('❌ Migration failed: $e');
      rethrow;
    }
  }

  // Verify migration results
  Future<void> verifyMigration() async {
    print('🔍 Verifying migration results...');

    try {
      // Check user profiles
      final userProfiles = await _firestore.collection('user_profiles').get();
      print('✅ User profiles: ${userProfiles.docs.length} documents');

      // Check chats
      final chats = await _firestore.collection('chats').get();
      print('✅ Chats: ${chats.docs.length} documents');

      // Check messages
      final messages = await _firestore.collection('messages').get();
      print('✅ Messages: ${messages.docs.length} documents');

      // Check presence
      final presence = await _firestore.collection('user_presence').get();
      print('✅ User presence: ${presence.docs.length} documents');

      // Check for typing collection (should be empty after migration)
      final typing = await _firestore.collection('typing').get();
      if (typing.docs.isNotEmpty) {
        print(
          '⚠️  Typing collection still has ${typing.docs.length} documents - consider deletion',
        );
      } else {
        print('✅ Typing collection is empty or deleted');
      }

      print('🎉 Migration verification complete!');
    } catch (e) {
      print('❌ Error during verification: $e');
    }
  }
}
