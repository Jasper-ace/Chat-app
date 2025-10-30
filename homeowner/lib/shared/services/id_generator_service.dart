import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to generate auto-increment IDs for users
class IdGeneratorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get next auto-increment ID - shared sequence for both user types
  static Future<int> getNextUserId(String userType) async {
    print('🔢 Generating next user ID for type: $userType');

    try {
      // Use a transaction to ensure atomic counter increment
      return await _firestore.runTransaction<int>((transaction) async {
        print('📊 Getting next ID from counter...');

        // Reference to the counter document
        final counterRef = _firestore
            .collection('counters')
            .doc('user_counter');
        final counterDoc = await transaction.get(counterRef);

        int nextId;
        if (counterDoc.exists) {
          // Get current counter value and increment
          final currentCount = counterDoc.data()?['count'] as int? ?? 0;
          nextId = currentCount + 1;
        } else {
          // Initialize counter if it doesn't exist
          nextId = 1;
        }

        // Update the counter
        transaction.set(counterRef, {'count': nextId}, SetOptions(merge: true));

        print('   Next ID to assign: $nextId');
        return nextId;
      });
    } catch (e) {
      print('❌ Error generating user ID: $e');
      rethrow;
    }
  }

  /// Initialize counter based on existing users
  static Future<void> initializeCounters() async {
    print('🔄 Initializing user counter...');

    try {
      // Get all existing users to find the highest ID
      final homeownersSnapshot = await _firestore
          .collection('homeowners')
          .get();
      final tradiesSnapshot = await _firestore.collection('tradies').get();

      int highestId = 0;

      // Check homeowners for highest ID
      for (final doc in homeownersSnapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int? ?? 0;
        if (id > highestId) {
          highestId = id;
        }
      }

      // Check tradies for highest ID
      for (final doc in tradiesSnapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int? ?? 0;
        if (id > highestId) {
          highestId = id;
        }
      }

      // Set counter to highest existing ID
      await _firestore.collection('counters').doc('user_counter').set({
        'count': highestId,
      });

      print('✅ Counter initialized with value: $highestId');
      print('   Next user will get ID: ${highestId + 1}');
    } catch (e) {
      print('❌ Error initializing counter: $e');
      rethrow;
    }
  }

  /// Add auto-increment IDs to existing users
  static Future<void> addIdsToExistingUsers() async {
    print('🔄 Adding auto-increment IDs to existing users...');

    // Process homeowners
    await _addIdsToCollection('homeowners', 'homeowner');

    // Process tradies
    await _addIdsToCollection('tradies', 'tradie');

    print('✅ All existing users now have auto-increment IDs');
  }

  static Future<void> _addIdsToCollection(
    String collectionName,
    String userType,
  ) async {
    print('📝 Processing $collectionName...');

    final snapshot = await _firestore.collection(collectionName).get();

    if (snapshot.docs.isEmpty) {
      print('⚠️ No documents found in $collectionName');
      return;
    }

    int updatedCount = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Check if ID already exists
      if (data['id'] == null) {
        // Get next auto-increment ID
        final nextId = await getNextUserId(userType);

        // Add ID to document
        await doc.reference.update({'id': nextId});

        print('✅ Added ID $nextId to ${data['name'] ?? 'Unknown'} (${doc.id})');
        updatedCount++;
      } else {
        print('ℹ️ ${data['name']} already has ID: ${data['id']}');
      }
    }

    print('✅ Updated $updatedCount documents in $collectionName');
  }
}
