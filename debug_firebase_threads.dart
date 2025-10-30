// Debug script to check Firebase thread structure
// Run this to see what's in your existing thread documents

import 'package:cloud_firestore/cloud_firestore.dart';

void debugFirebaseThreads() async {
  final firestore = FirebaseFirestore.instance;

  print('🔍 Checking existing threads in Firebase...');

  try {
    final threadsSnapshot = await firestore.collection('threads').get();

    print('📊 Found ${threadsSnapshot.docs.length} thread documents:');

    for (var doc in threadsSnapshot.docs) {
      print('\n--- Thread: ${doc.id} ---');
      final data = doc.data();

      // Print all fields in the document
      data.forEach((key, value) {
        print('  $key: $value');
      });

      // Check if this thread has messages
      final messagesSnapshot = await doc.reference.collection('messages').get();
      print('  Messages count: ${messagesSnapshot.docs.length}');

      if (messagesSnapshot.docs.isNotEmpty) {
        print('  Sample messages:');
        for (var msgDoc in messagesSnapshot.docs.take(2)) {
          final msgData = msgDoc.data();
          print(
            '    - ${msgDoc.id}: ${msgData['content']} (from ${msgData['sender_type']})',
          );
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
