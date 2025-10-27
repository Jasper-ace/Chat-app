import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/id_generator_service.dart';

/// Quick script to add ID to the existing homeowner user
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized');

    final firestore = FirebaseFirestore.instance;

    print('\n🔍 Looking for homeowner user without ID...');

    // Find the homeowner user without ID
    final homeownersSnapshot = await firestore.collection('homeowners').get();

    for (final doc in homeownersSnapshot.docs) {
      final data = doc.data();

      if (data['id'] == null) {
        print('📝 Found user without ID: ${data['name']} (${data['email']})');

        // Initialize counter if it doesn't exist
        final counterDoc = await firestore
            .collection('counters')
            .doc('homeowner')
            .get();
        if (!counterDoc.exists) {
          print('🔧 Initializing homeowner counter...');
          await firestore.collection('counters').doc('homeowner').set({
            'current_id': 0,
            'user_type': 'homeowner',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        // Get next ID
        final nextId = await IdGeneratorService.getNextUserId('homeowner');

        // Update the document with ID
        await doc.reference.update({
          'id': nextId,
          'updated_at': FieldValue.serverTimestamp(),
        });

        print('✅ Added ID $nextId to ${data['name']}');
        print('📋 Updated document structure:');
        print('   {');
        print('     "id": $nextId,');
        print('     "name": "${data['name']}",');
        print('     "email": "${data['email']}",');
        print('     "userType": "${data['userType']}",');
        print('     "created_at": "timestamp",');
        print('     "updated_at": "timestamp"');
        print('   }');
      } else {
        print('ℹ️ User ${data['name']} already has ID: ${data['id']}');
      }
    }

    print('\n🎉 All homeowner users now have auto-increment IDs!');
    print('\n📊 Next Steps:');
    print('   1. Check Firebase Console to verify the ID was added');
    print('   2. New user registrations will automatically get sequential IDs');
    print('   3. Homeowners: 1, 2, 3... | Tradies: 1000, 1001, 1002...');
  } catch (e) {
    print('❌ Error: $e');
  }
}
