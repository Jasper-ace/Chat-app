import 'package:firebase_core/firebase_core.dart';
import 'lib/scripts/cleanup_collections.dart';

/// Simple script to clean up Firebase collections
/// Run with: dart cleanup_firebase.dart
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    print('🚀 Firebase initialized successfully');

    // Run cleanup
    await CleanupCollections.removeAllChatCollections();

    print('✅ Cleanup completed successfully!');
  } catch (e) {
    print('❌ Error during cleanup: $e');
  }
}
