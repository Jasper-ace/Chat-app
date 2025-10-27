import 'package:firebase_core/firebase_core.dart';
import 'lib/services/id_generator_service.dart';

/// Setup script to initialize auto-increment IDs for users
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized successfully');

    print('\n📋 Setting up auto-increment IDs for users...');

    // Step 1: Initialize counters
    print('\n1️⃣ Initializing counters...');
    await IdGeneratorService.initializeCounters();

    // Step 2: Add IDs to existing users
    print('\n2️⃣ Adding IDs to existing users...');
    await IdGeneratorService.addIdsToExistingUsers();

    print('\n🎉 Auto-increment system setup complete!');
    print('\n📊 User ID Structure:');
    print('   📁 Homeowners: ID 1, 2, 3, 4...');
    print('   📁 Tradies: ID 1000, 1001, 1002, 1003...');

    print('\n📋 Example Documents Created:');
    print('   Homeowner Example:');
    print('   {');
    print('     "id": 1,');
    print('     "name": "John Doe",');
    print('     "email": "john@fixo.com",');
    print('     "userType": "homeowner",');
    print('     "created_at": "2025-10-28T16:00:00Z"');
    print('   }');
    print('');
    print('   Tradie Example:');
    print('   {');
    print('     "id": 1000,');
    print('     "name": "Mike Smith",');
    print('     "email": "mike@fixo.com",');
    print('     "userType": "tradie",');
    print('     "tradeType": "Plumber",');
    print('     "created_at": "2025-10-28T16:00:00Z"');
    print('   }');

    print('\n✅ Ready for new user registrations with auto-increment IDs!');
  } catch (e) {
    print('❌ Error setting up auto-increment: $e');
  }
}
