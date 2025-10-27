import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/auto_increment_service.dart';

/// Example of how to register users with auto-increment IDs
class UserRegistration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AutoIncrementService _autoIncrement = AutoIncrementService();

  /// Register a new homeowner with auto-increment ID
  Future<void> registerHomeowner({
    required String name,
    required String email,
  }) async {
    // Get next auto-increment ID
    final nextId = await _autoIncrement.getNextId('homeowners');

    // Create homeowner document
    await _firestore.collection('homeowners').add({
      'id': nextId, // ✅ True auto-increment ID
      'name': name,
      'email': email,
      'userType': 'homeowner',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Homeowner registered with auto-increment ID: $nextId');
  }

  /// Register a new tradie with auto-increment ID
  Future<void> registerTradie({
    required String name,
    required String email,
    required String tradeType,
  }) async {
    // Get next auto-increment ID
    final nextId = await _autoIncrement.getNextId('tradies');

    // Create tradie document
    await _firestore.collection('tradies').add({
      'id': nextId, // ✅ True auto-increment ID
      'name': name,
      'email': email,
      'tradeType': tradeType,
      'userType': 'tradie',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Tradie registered with auto-increment ID: $nextId');
  }

  /// Initialize the auto-increment system
  Future<void> initializeSystem() async {
    await _autoIncrement.initializeCounters();
  }

  /// Sync existing users with auto-increment IDs
  Future<void> syncExistingUsers() async {
    await _autoIncrement.syncExistingUsers();
  }
}

/// Usage example
Future<void> main() async {
  final registration = UserRegistration();

  // Initialize auto-increment system
  await registration.initializeSystem();

  // Sync existing users (run once)
  await registration.syncExistingUsers();

  // Register new homeowner (gets auto-increment ID)
  await registration.registerHomeowner(
    name: 'John Smith',
    email: 'john@example.com',
  );

  // Register new tradie (gets auto-increment ID)
  await registration.registerTradie(
    name: 'Mike Johnson',
    email: 'mike@example.com',
    tradeType: 'Plumber',
  );
}
