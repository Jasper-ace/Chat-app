import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

/// Simple test to create thread schema
Future<void> main() async {
  try {
    print('🔧 Initializing Firebase with options...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    final firestore = FirebaseFirestore.instance;

    print('\n📝 Creating thread with exact schema...');

    // Create thread document: thread_10001
    final threadDocName = 'thread_10001';

    final threadData = {
      'thread_id': 10001,
      'sender_1': 1, // tradie_id
      'sender_2': 5, // homeowner_id
      'tradie_id': 1,
      'homeowner_id': 5,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': 'Sure, I\'ll come by tomorrow morning.',
      'last_message_time': FieldValue.serverTimestamp(),
      'is_archived': false,
      'is_deleted': false,
    };

    await firestore.collection('threads').doc(threadDocName).set(threadData);
    print('✅ Thread document created: $threadDocName');

    print('\n📝 Adding messages to subcollection...');

    // Message 1
    await firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .doc('msg_1')
        .set({
          'sender_id': 1,
          'sender_type': 'tradie',
          'content': 'Hi homeowner!',
          'date': FieldValue.serverTimestamp(),
        });
    print('✅ Created msg_1');

    // Message 2
    await firestore
        .collection('threads')
        .doc(threadDocName)
        .collection('messages')
        .doc('msg_2')
        .set({
          'sender_id': 5,
          'sender_type': 'homeowner',
          'content': 'Yes, please come tomorrow!',
          'date': FieldValue.serverTimestamp(),
        });
    print('✅ Created msg_2');

    print('\n🎉 Thread schema implemented successfully!');
    print('\n📋 Firebase Structure:');
    print('threads (collection)');
    print('┣ thread_10001 (document)');
    print('┃ ┣ thread_id: 10001');
    print('┃ ┣ sender_1: 1              // tradie_id');
    print('┃ ┣ sender_2: 5              // homeowner_id');
    print('┃ ┣ tradie_id: 1');
    print('┃ ┣ homeowner_id: 5');
    print('┃ ┣ created_at: timestamp');
    print('┃ ┣ updated_at: timestamp');
    print('┃ ┣ last_message: "Sure, I\'ll come by tomorrow morning."');
    print('┃ ┣ last_message_time: timestamp');
    print('┃ ┣ is_archived: false');
    print('┃ ┣ is_deleted: false');
    print('┃ ┗ messages (subcollection)');
    print('┃    ┣ msg_1');
    print('┃    ┃ ┣ sender_id: 1');
    print('┃    ┃ ┣ sender_type: "tradie"');
    print('┃    ┃ ┣ content: "Hi homeowner!"');
    print('┃    ┃ ┗ date: timestamp');
    print('┃    ┗ msg_2');
    print('┃       ┣ sender_id: 5');
    print('┃       ┣ sender_type: "homeowner"');
    print('┃       ┣ content: "Yes, please come tomorrow!"');
    print('┃       ┗ date: timestamp');

    print('\n✅ Check Firebase Console to verify!');
    print('✅ Your thread schema is now implemented exactly as specified!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
