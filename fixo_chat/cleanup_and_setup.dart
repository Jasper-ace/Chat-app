import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/id_generator_service.dart';

/// Script to clean up counter collection and set up shared ID sequence
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized successfully');

    final firestore = FirebaseFirestore.instance;

    print('\n🧹 Cleaning up counter collection...');

    // Delete counter collection
    try {
      final counterSnapshot = await firestore.collection('counters').get();
      for (final doc in counterSnapshot.docs) {
        await doc.reference.delete();
        print('🗑️ Deleted counter: ${doc.id}');
      }
      print('✅ Counter collection removed');
    } catch (e) {
      print('ℹ️ No counter collection to remove');
    }

    print('\n📋 Setting up shared ID sequence...');
    await IdGeneratorService.initializeCounters();

    print('\n🔄 Updating existing users to match your document structure...');
    await updateExistingUsers();

    print('\n🎉 System updated successfully!');
    print('\n📊 New ID Structure:');
    print('   📁 Both homeowners and tradies: ID 1, 2, 3, 4, 5...');

    print('\n📋 Document Examples:');
    print('   🏠 Homeowner:');
    print('   {');
    print('     "id": 5,');
    print('     "name": "Jane Doe",');
    print('     "email": "jane@fixo.com",');
    print('     "phone": "+639987654321",');
    print('     "address": "Mandaue City",');
    print('     "created_at": "2025-10-28T16:00:00Z",');
    print('     "updated_at": "2025-10-28T16:10:00Z"');
    print('   }');
    print('');
    print('   🔧 Tradie:');
    print('   {');
    print('     "id": 1,');
    print('     "name": "John Smith",');
    print('     "email": "john@fixo.com",');
    print('     "phone": "+639123456789",');
    print('     "skills": ["plumbing", "electrical"],');
    print('     "location": "Cebu City",');
    print('     "created_at": "2025-10-28T16:00:00Z",');
    print('     "updated_at": "2025-10-28T16:05:00Z"');
    print('   }');

    print('\n✅ Ready for new registrations with shared ID sequence!');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Update existing users to match the new document structure
Future<void> updateExistingUsers() async {
  final firestore = FirebaseFirestore.instance;

  // Update homeowners
  print('📝 Updating homeowners...');
  final homeownersSnapshot = await firestore.collection('homeowners').get();
  for (final doc in homeownersSnapshot.docs) {
    final data = doc.data();

    // Create clean homeowner document
    final updatedData = {
      'id': data['id'] ?? 1, // Keep existing ID or assign 1
      'name': data['name'] ?? '',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'address': data['address'] ?? '',
      'created_at': data['created_at'] ?? FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await doc.reference.set(updatedData);
    print('✅ Updated homeowner: ${data['name']} (ID: ${updatedData['id']})');
  }

  // Update tradies
  print('📝 Updating tradies...');
  final tradiesSnapshot = await firestore.collection('tradies').get();
  for (final doc in tradiesSnapshot.docs) {
    final data = doc.data();

    // Create clean tradie document
    final updatedData = {
      'id': data['id'] ?? 1, // Keep existing ID or assign 1
      'name': data['name'] ?? '',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'skills': data['skills'] ?? [],
      'location': data['location'] ?? '',
      'created_at': data['created_at'] ?? FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await doc.reference.set(updatedData);
    print('✅ Updated tradie: ${data['name']} (ID: ${updatedData['id']})');
  }
}
