import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug script to test thread creation directly
Future<void> main() async {
  try {
    print('🔧 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    final firestore = FirebaseFirestore.instance;

    print('\n📝 Creating thread document directly...');

    // Create thread document with exact schema
    final threadDocName = 'thread_10001';

    await firestore.collection('threads').doc(threadDocName).set({
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
    });

    print('✅ Thread document created: $threadDocName');

    print('\n📝 Adding messages to subcollection...');

    // Add first message
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

    print('✅ Message msg_1 created');

    // Add second message
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

    print('✅ Message msg_2 created');

    print('\n🎉 Thread schema created successfully!');
    print('\n📋 Firebase Structure Created:');
    print('threads/');
    print('└── thread_10001/');
    print('    ├── thread_id: 10001');
    print('    ├── sender_1: 1');
    print('    ├── sender_2: 5');
    print('    ├── tradie_id: 1');
    print('    ├── homeowner_id: 5');
    print('    ├── last_message: "Sure, I\'ll come by tomorrow morning."');
    print('    ├── is_archived: false');
    print('    ├── is_deleted: false');
    print('    └── messages/');
    print('        ├── msg_1');
    print('        │   ├── sender_id: 1');
    print('        │   ├── sender_type: "tradie"');
    print('        │   └── content: "Hi homeowner!"');
    print('        └── msg_2');
    print('            ├── sender_id: 5');
    print('            ├── sender_type: "homeowner"');
    print('            └── content: "Yes, please come tomorrow!"');

    print('\n✅ Check Firebase Console to verify the structure!');
  } catch (e) {
    print('❌ Error: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
