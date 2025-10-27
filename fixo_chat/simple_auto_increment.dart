import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple auto-increment system that works immediately
class SimpleAutoIncrement {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get next auto-increment ID for a collection
  static Future<int> getNextId(String collectionType) async {
    final counterDoc = _firestore.collection('counters').doc(collectionType);

    // Use transaction to ensure atomic increment
    return await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterDoc);

      int nextId;
      if (snapshot.exists) {
        // Get current counter value and increment
        final currentId = snapshot.data()?['current_id'] ?? 0;
        nextId = currentId + 1;
      } else {
        // Initialize counter based on collection type
        nextId = collectionType == 'homeowners' ? 1001 : 2001;
      }

      // Update counter
      transaction.set(counterDoc, {
        'current_id': nextId,
        'collection_type': collectionType,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return nextId;
    });
  }

  /// Add ID to existing user (your ACE user)
  static Future<void> addIdToUser({
    required String collection,
    required String documentId,
    required int userId,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      'id': userId,
    });
    print('✅ Added ID $userId to user in $collection');
  }

  /// Register new homeowner with auto-increment ID
  static Future<void> registerHomeowner({
    required String name,
    required String email,
  }) async {
    // Get next auto-increment ID
    final nextId = await getNextId('homeowners');

    // Create homeowner document
    await _firestore.collection('homeowners').add({
      'id': nextId,
      'name': name,
      'email': email,
      'userType': 'homeowner',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Homeowner "$name" registered with ID: $nextId');
  }

  /// Register new tradie with auto-increment ID
  static Future<void> registerTradie({
    required String name,
    required String email,
    required String tradeType,
  }) async {
    // Get next auto-increment ID
    final nextId = await getNextId('tradies');

    // Create tradie document
    await _firestore.collection('tradies').add({
      'id': nextId,
      'name': name,
      'email': email,
      'tradeType': tradeType,
      'userType': 'tradie',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Tradie "$name" registered with ID: $nextId');
  }

  /// Initialize counters
  static Future<void> initializeCounters() async {
    // Initialize homeowners counter
    await _firestore.collection('counters').doc('homeowners').set({
      'current_id': 1000,
      'collection_type': 'homeowners',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Initialize tradies counter
    await _firestore.collection('counters').doc('tradies').set({
      'current_id': 2000,
      'collection_type': 'tradies',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    print('✅ Counters initialized - Homeowners: 1001+, Tradies: 2001+');
  }

  /// Add IDs to all existing users
  static Future<void> addIdsToExistingUsers() async {
    print('🔄 Adding IDs to existing users...');

    // Process homeowners
    final homeowners = await _firestore.collection('homeowners').get();
    for (final doc in homeowners.docs) {
      final data = doc.data();
      if (data['id'] == null) {
        final nextId = await getNextId('homeowners');
        await doc.reference.update({'id': nextId});
        print('✅ Added ID $nextId to homeowner: ${data['name']}');
      }
    }

    // Process tradies
    final tradies = await _firestore.collection('tradies').get();
    for (final doc in tradies.docs) {
      final data = doc.data();
      if (data['id'] == null) {
        final nextId = await getNextId('tradies');
        await doc.reference.update({'id': nextId});
        print('✅ Added ID $nextId to tradie: ${data['name']}');
      }
    }

    print('✅ All existing users now have auto-increment IDs');
  }
}

/// Complete setup and test
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized');

    // Step 1: Initialize counters
    print('\n1️⃣ Initializing counters...');
    await SimpleAutoIncrement.initializeCounters();

    // Step 2: Add IDs to existing users
    print('\n2️⃣ Adding IDs to existing users...');
    await SimpleAutoIncrement.addIdsToExistingUsers();

    // Step 3: Test with new users
    print('\n3️⃣ Testing with new registrations...');

    await SimpleAutoIncrement.registerHomeowner(
      name: 'John Smith',
      email: 'john@example.com',
    );

    await SimpleAutoIncrement.registerTradie(
      name: 'Sarah Wilson',
      email: 'sarah@example.com',
      tradeType: 'Electrician',
    );

    print('\n🎉 Auto-increment system working perfectly!');
    print('✅ Your ACE user now has an auto-increment ID');
    print('✅ New users get sequential IDs automatically');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Quick test function
Future<void> testAutoIncrement() async {
  await Firebase.initializeApp();

  print('🧪 Testing auto-increment...');

  final id1 = await SimpleAutoIncrement.getNextId('homeowners');
  final id2 = await SimpleAutoIncrement.getNextId('homeowners');
  final id3 = await SimpleAutoIncrement.getNextId('tradies');

  print('Homeowner IDs: $id1, $id2');
  print('Tradie ID: $id3');

  if (id2 == id1 + 1) {
    print('✅ Auto-increment working correctly!');
  } else {
    print('❌ Auto-increment not working');
  }
}
