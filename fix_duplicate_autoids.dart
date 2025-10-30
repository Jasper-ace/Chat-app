// Script to identify and fix duplicate autoId issues in Firebase
// Run this to find users with duplicate autoIds and fix them

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> findAndFixDuplicateAutoIds() async {
  final firestore = FirebaseFirestore.instance;

  print('🔍 Checking for duplicate autoIds...');

  try {
    // Get all homeowners
    final homeownersSnapshot = await firestore.collection('homeowners').get();
    final tradiesSnapshot = await firestore.collection('tradies').get();

    Map<int, List<Map<String, dynamic>>> autoIdMap = {};

    // Collect all autoIds from homeowners
    for (var doc in homeownersSnapshot.docs) {
      final data = doc.data();
      final autoId = data['autoId'] as int?;
      if (autoId != null) {
        autoIdMap[autoId] ??= [];
        autoIdMap[autoId]!.add({
          'collection': 'homeowners',
          'docId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'data': data,
        });
      }
    }

    // Collect all autoIds from tradies
    for (var doc in tradiesSnapshot.docs) {
      final data = doc.data();
      final autoId = data['autoId'] as int?;
      if (autoId != null) {
        autoIdMap[autoId] ??= [];
        autoIdMap[autoId]!.add({
          'collection': 'tradies',
          'docId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'data': data,
        });
      }
    }

    // Find duplicates
    print('\n📊 AutoId Analysis:');
    bool foundDuplicates = false;

    for (var entry in autoIdMap.entries) {
      final autoId = entry.key;
      final users = entry.value;

      if (users.length > 1) {
        foundDuplicates = true;
        print('\n❌ DUPLICATE autoId $autoId found in:');
        for (var user in users) {
          print(
            '   - ${user['collection']}: ${user['name']} (${user['docId']})',
          );
        }

        // Suggest fix
        print('   💡 Suggested fix:');
        for (int i = 0; i < users.length; i++) {
          final user = users[i];
          if (i == 0) {
            print('     - Keep ${user['name']} with autoId $autoId');
          } else {
            final newAutoId = await getNextAvailableAutoId(autoIdMap);
            print('     - Change ${user['name']} to autoId $newAutoId');

            // Uncomment the line below to actually apply the fix
            // await firestore.collection(user['collection']).doc(user['docId']).update({'autoId': newAutoId});
            // autoIdMap[newAutoId] = [user]; // Update our map
          }
        }
      } else {
        print(
          '✅ autoId $autoId: ${users[0]['name']} (${users[0]['collection']})',
        );
      }
    }

    if (!foundDuplicates) {
      print('\n🎉 No duplicate autoIds found!');
    } else {
      print(
        '\n⚠️  To apply the fixes, uncomment the update line in the code and run again.',
      );
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<int> getNextAvailableAutoId(
  Map<int, List<Map<String, dynamic>>> existingIds,
) async {
  int nextId = 1;
  while (existingIds.containsKey(nextId)) {
    nextId++;
  }
  return nextId;
}

// Uncomment to run:
// main() async {
//   await findAndFixDuplicateAutoIds();
// }
