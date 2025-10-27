import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to add missing ID fields to homeowner and tradie documents
Future<void> main() async {
  try {
    await Firebase.initializeApp();
    print('🚀 Firebase initialized');

    final firestore = FirebaseFirestore.instance;

    // Add IDs to homeowners
    await addIdsToCollection(firestore, 'homeowners', startId: 1000);

    // Add IDs to tradies
    await addIdsToCollection(firestore, 'tradies', startId: 2000);

    print('✅ All user IDs added successfully!');
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> addIdsToCollection(
  FirebaseFirestore firestore,
  String collectionName, {
  required int startId,
}) async {
  print('📝 Processing $collectionName collection...');

  // Get all documents in collection
  final snapshot = await firestore.collection(collectionName).get();

  if (snapshot.docs.isEmpty) {
    print('⚠️ No documents found in $collectionName');
    return;
  }

  int currentId = startId;
  final batch = firestore.batch();

  for (final doc in snapshot.docs) {
    final data = doc.data();

    // Check if ID already exists
    if (data['id'] == null) {
      // Add ID field to document
      batch.update(doc.reference, {'id': currentId});
      print(
        '✅ Added ID $currentId to ${doc.id} (${data['name'] ?? 'Unknown'})',
      );
      currentId++;
    } else {
      print('ℹ️ ID already exists for ${doc.id}: ${data['id']}');
    }
  }

  // Commit all updates
  await batch.commit();
  print('✅ $collectionName collection updated');
}

/// Alternative: Add ID to specific document
Future<void> addIdToSpecificUser() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  // Example: Add ID to the ACE homeowner
  await firestore.collection('homeowners').doc('DOCUMENT_ID_HERE').update({
    'id': 1001, // Your desired ID number
  });

  print('✅ ID added to specific user');
}
