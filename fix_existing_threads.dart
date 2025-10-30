// Migration script to fix existing thread documents
// This will ensure all threads have the correct field structure

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> fixExistingThreads() async {
  final firestore = FirebaseFirestore.instance;

  print('🔧 Fixing existing thread documents...');

  try {
    final threadsSnapshot = await firestore.collection('threads').get();

    for (var doc in threadsSnapshot.docs) {
      final data = doc.data();
      final docId = doc.id;

      print('\n--- Checking thread: $docId ---');

      // Check if thread has the required fields
      bool needsUpdate = false;
      Map<String, dynamic> updates = {};

      // Check for tradie_id and homeowner_id
      if (!data.containsKey('tradie_id') || !data.containsKey('homeowner_id')) {
        print('  ❌ Missing tradie_id or homeowner_id fields');

        // Try to determine from sender_1/sender_2 or messages
        if (data.containsKey('sender_1') && data.containsKey('sender_2')) {
          // Assume sender_1 is tradie, sender_2 is homeowner (this might need adjustment)
          updates['tradie_id'] = data['sender_1'];
          updates['homeowner_id'] = data['sender_2'];
          needsUpdate = true;
          print(
            '  🔧 Will set tradie_id=${data['sender_1']}, homeowner_id=${data['sender_2']}',
          );
        } else {
          // Try to determine from messages
          final messagesSnapshot = await doc.reference
              .collection('messages')
              .limit(1)
              .get();
          if (messagesSnapshot.docs.isNotEmpty) {
            final firstMessage = messagesSnapshot.docs.first.data();
            final senderId = firstMessage['sender_id'];
            final senderType = firstMessage['sender_type'];

            print('  📝 Found message from $senderType with ID $senderId');

            // We need both tradie and homeowner IDs, so this is incomplete
            // For now, just log what we found
            print('  ⚠️  Need manual intervention to set correct IDs');
          }
        }
      } else {
        print('  ✅ Has tradie_id and homeowner_id fields');
      }

      // Add other required fields if missing
      if (!data.containsKey('thread_id')) {
        // Extract thread number from document ID (e.g., "thread_1" -> 1)
        final threadNumber = int.tryParse(docId.replaceAll('thread_', ''));
        if (threadNumber != null) {
          updates['thread_id'] = threadNumber;
          needsUpdate = true;
          print('  🔧 Will set thread_id=$threadNumber');
        }
      }

      if (!data.containsKey('message_count')) {
        // Count existing messages
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .get();
        updates['message_count'] = messagesSnapshot.docs.length;
        needsUpdate = true;
        print('  🔧 Will set message_count=${messagesSnapshot.docs.length}');
      }

      // Apply updates if needed
      if (needsUpdate) {
        await doc.reference.update(updates);
        print('  ✅ Updated thread $docId');
      } else {
        print('  ✅ Thread $docId is already correct');
      }
    }

    print('\n🎉 Thread migration completed!');
  } catch (e) {
    print('❌ Error during migration: $e');
  }
}

// Call this function to run the migration
// fixExistingThreads();
