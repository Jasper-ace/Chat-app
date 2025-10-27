import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Setup script to initialize Firebase collections for thread system
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized successfully');

    final firestore = FirebaseFirestore.instance;

    // Create sample thread
    print('📝 Creating sample thread...');
    final threadDoc = await firestore.collection('thread').add({
      'sender_1': 123, // tradie_id
      'sender_2': 456, // homeowner_id
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': 'Hi! I can help with your plumbing issue.',
      'last_message_time': FieldValue.serverTimestamp(),
    });

    print('✅ Thread created with ID: ${threadDoc.id}');

    // Generate thread_id for messages
    final threadIdInt = threadDoc.id.hashCode.abs() % 1000000000;

    // Create sample messages
    print('💬 Creating sample messages...');

    // Message 1: Tradie to Homeowner
    await firestore.collection('messages').add({
      'thread_id': threadIdInt,
      'sender_id': 123,
      'sender_type': 'tradie',
      'content': 'Hi! I can help with your plumbing issue.',
      'date': FieldValue.serverTimestamp(),
    });

    // Message 2: Homeowner to Tradie
    await firestore.collection('messages').add({
      'thread_id': threadIdInt,
      'sender_id': 456,
      'sender_type': 'homeowner',
      'content': 'Great! When can you come by?',
      'date': FieldValue.serverTimestamp(),
    });

    print('✅ Sample messages created');

    // Verify collections exist
    print('🔍 Verifying collections...');

    final threadCount =
        (await firestore.collection('thread').get()).docs.length;
    final messageCount =
        (await firestore.collection('messages').get()).docs.length;

    print('📊 Collections status:');
    print('   - thread: $threadCount documents');
    print('   - messages: $messageCount documents');

    print('\n🎉 Firebase collections setup complete!');
    print('\n📋 Collection Structure:');
    print('   Collection 1: thread');
    print('     - sender_1 (int): tradie_id');
    print('     - sender_2 (int): homeowner_id');
    print('     - created_at (timestamp)');
    print('     - updated_at (timestamp)');
    print('     - last_message (string)');
    print('     - last_message_time (timestamp)');
    print('');
    print('   Collection 2: messages');
    print('     - thread_id (int): reference to thread');
    print('     - sender_id (int): sender ID');
    print('     - sender_type (string): "tradie" or "homeowner"');
    print('     - content (string): message text');
    print('     - date (timestamp): when sent');
  } catch (e) {
    print('❌ Error setting up collections: $e');
  }
}
