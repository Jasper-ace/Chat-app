import 'package:firebase_core/firebase_core.dart';
import 'lib/services/chat_service.dart';

/// Test the new thread schema with subcollections
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized');

    final chatService = ChatService();

    print('\n🧪 Testing new thread schema...');
    print('Creating thread between tradie (ID: 1) and homeowner (ID: 5)');

    // Send first message from tradie to homeowner
    print('\n1️⃣ Tradie sends message...');
    await chatService.sendMessageThread(
      senderId: 1,
      senderType: 'tradie',
      receiverId: 5,
      receiverType: 'homeowner',
      message: 'Hi homeowner!',
    );

    // Send reply from homeowner to tradie
    print('\n2️⃣ Homeowner replies...');
    await chatService.sendMessageThread(
      senderId: 5,
      senderType: 'homeowner',
      receiverId: 1,
      receiverType: 'tradie',
      message: 'Yes, please come tomorrow!',
    );

    // Send another message from tradie
    print('\n3️⃣ Tradie responds...');
    await chatService.sendMessageThread(
      senderId: 1,
      senderType: 'tradie',
      receiverId: 5,
      receiverType: 'homeowner',
      message: 'Sure, I\'ll come by tomorrow morning.',
    );

    print('\n🎉 Thread created successfully!');
    print('\n📋 Expected Firebase Structure:');
    print('');
    print('📁 threads (collection)');
    print('┣ 📄 thread_10001 (document)');
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
    print('┃ ┗ 📁 messages (subcollection)');
    print('┃    ┣ 📄 msg_1');
    print('┃    ┃ ┣ sender_id: 1');
    print('┃    ┃ ┣ sender_type: "tradie"');
    print('┃    ┃ ┣ content: "Hi homeowner!"');
    print('┃    ┃ ┗ date: timestamp');
    print('┃    ┣ 📄 msg_2');
    print('┃    ┃ ┣ sender_id: 5');
    print('┃    ┃ ┣ sender_type: "homeowner"');
    print('┃    ┃ ┣ content: "Yes, please come tomorrow!"');
    print('┃    ┃ ┗ date: timestamp');
    print('┃    ┗ 📄 msg_3');
    print('┃       ┣ sender_id: 1');
    print('┃       ┣ sender_type: "tradie"');
    print('┃       ┣ content: "Sure, I\'ll come by tomorrow morning."');
    print('┃       ┗ date: timestamp');
    print('');
    print('✅ Check Firebase Console to verify the structure!');
    print('✅ Thread document: thread_10001');
    print('✅ Messages subcollection: msg_1, msg_2, msg_3');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Show the exact document structure
void showDocumentStructure() {
  print('\n📋 Thread Document Structure:');
  print('{');
  print('  "thread_id": 10001,');
  print('  "sender_1": 1,');
  print('  "sender_2": 5,');
  print('  "tradie_id": 1,');
  print('  "homeowner_id": 5,');
  print('  "created_at": "2025-10-28T16:00:00Z",');
  print('  "updated_at": "2025-10-28T16:02:00Z",');
  print('  "last_message": "Sure, I\'ll come by tomorrow morning.",');
  print('  "last_message_time": "2025-10-28T16:02:00Z",');
  print('  "is_archived": false,');
  print('  "is_deleted": false');
  print('}');

  print('\n📋 Message Document Structure (msg_1):');
  print('{');
  print('  "sender_id": 1,');
  print('  "sender_type": "tradie",');
  print('  "content": "Hi homeowner!",');
  print('  "date": "2025-10-28T16:01:00Z"');
  print('}');
}
