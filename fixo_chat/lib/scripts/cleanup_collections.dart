import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to remove chats and typing collections from Firebase
class CleanupCollections {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Remove all documents from chats collection
  static Future<void> removeChatsCollection() async {
    try {
      print('🗑️ Removing chats collection...');

      // Get all documents in chats collection
      final QuerySnapshot chatsSnapshot = await _firestore
          .collection('chats')
          .get();

      // Delete in batches (Firestore batch limit is 500)
      final List<List<QueryDocumentSnapshot>> batches = [];
      for (int i = 0; i < chatsSnapshot.docs.length; i += 500) {
        batches.add(
          chatsSnapshot.docs.sublist(
            i,
            i + 500 > chatsSnapshot.docs.length
                ? chatsSnapshot.docs.length
                : i + 500,
          ),
        );
      }

      for (final batch in batches) {
        final WriteBatch writeBatch = _firestore.batch();
        for (final doc in batch) {
          writeBatch.delete(doc.reference);
        }
        await writeBatch.commit();
        print('✅ Deleted batch of ${batch.length} chat documents');
      }

      print('✅ Chats collection removed successfully');
    } catch (e) {
      print('❌ Error removing chats collection: $e');
    }
  }

  /// Remove all documents from typing collection
  static Future<void> removeTypingCollection() async {
    try {
      print('🗑️ Removing typing collection...');

      // Get all documents in typing collection
      final QuerySnapshot typingSnapshot = await _firestore
          .collection('typing')
          .get();

      // Delete in batches
      final List<List<QueryDocumentSnapshot>> batches = [];
      for (int i = 0; i < typingSnapshot.docs.length; i += 500) {
        batches.add(
          typingSnapshot.docs.sublist(
            i,
            i + 500 > typingSnapshot.docs.length
                ? typingSnapshot.docs.length
                : i + 500,
          ),
        );
      }

      for (final batch in batches) {
        final WriteBatch writeBatch = _firestore.batch();
        for (final doc in batch) {
          writeBatch.delete(doc.reference);
        }
        await writeBatch.commit();
        print('✅ Deleted batch of ${batch.length} typing documents');
      }

      print('✅ Typing collection removed successfully');
    } catch (e) {
      print('❌ Error removing typing collection: $e');
    }
  }

  /// Remove all documents from typing_indicators collection
  static Future<void> removeTypingIndicatorsCollection() async {
    try {
      print('🗑️ Removing typing_indicators collection...');

      // Get all documents in typing_indicators collection
      final QuerySnapshot typingIndicatorsSnapshot = await _firestore
          .collection('typing_indicators')
          .get();

      // Delete in batches
      final List<List<QueryDocumentSnapshot>> batches = [];
      for (int i = 0; i < typingIndicatorsSnapshot.docs.length; i += 500) {
        batches.add(
          typingIndicatorsSnapshot.docs.sublist(
            i,
            i + 500 > typingIndicatorsSnapshot.docs.length
                ? typingIndicatorsSnapshot.docs.length
                : i + 500,
          ),
        );
      }

      for (final batch in batches) {
        final WriteBatch writeBatch = _firestore.batch();
        for (final doc in batch) {
          writeBatch.delete(doc.reference);
        }
        await writeBatch.commit();
        print('✅ Deleted batch of ${batch.length} typing indicator documents');
      }

      print('✅ Typing indicators collection removed successfully');
    } catch (e) {
      print('❌ Error removing typing indicators collection: $e');
    }
  }

  /// Remove all chat-related collections
  static Future<void> removeAllChatCollections() async {
    print('🧹 Starting cleanup of chat collections...');

    await removeChatsCollection();
    await removeTypingCollection();
    await removeTypingIndicatorsCollection();

    print('🎉 All chat collections cleaned up successfully!');
  }

  /// Get collection sizes before cleanup
  static Future<void> showCollectionSizes() async {
    try {
      final chatsCount =
          (await _firestore.collection('chats').get()).docs.length;
      final typingCount =
          (await _firestore.collection('typing').get()).docs.length;
      final typingIndicatorsCount =
          (await _firestore.collection('typing_indicators').get()).docs.length;

      print('📊 Collection sizes:');
      print('   - chats: $chatsCount documents');
      print('   - typing: $typingCount documents');
      print('   - typing_indicators: $typingIndicatorsCount documents');
    } catch (e) {
      print('❌ Error getting collection sizes: $e');
    }
  }
}

/// Run the cleanup
Future<void> main() async {
  print('🚀 Starting Firebase collections cleanup...');

  // Show current sizes
  await CleanupCollections.showCollectionSizes();

  // Perform cleanup
  await CleanupCollections.removeAllChatCollections();

  print('✅ Cleanup completed!');
}
