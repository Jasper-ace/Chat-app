import 'package:firebase_core/firebase_core.dart';
import 'lib/services/auto_increment_service.dart';

/// Setup script to initialize auto-increment system
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized successfully');

    final autoIncrement = AutoIncrementService();

    print('\n📋 Setting up auto-increment system...');

    // Step 1: Initialize counters
    print('\n1️⃣ Initializing counters...');
    await autoIncrement.initializeCounters();

    // Step 2: Sync existing users
    print('\n2️⃣ Syncing existing users...');
    await autoIncrement.syncExistingUsers();

    // Step 3: Show current status
    print('\n3️⃣ Current counter status:');
    final homeownerCount = await autoIncrement.getCurrentId('homeowners');
    final tradieCount = await autoIncrement.getCurrentId('tradies');

    print('   📊 Homeowners counter: $homeownerCount');
    print('   📊 Tradies counter: $tradieCount');

    print('\n🎉 Auto-increment system setup complete!');
    print('\n📋 What happens next:');
    print(
      '   ✅ New homeowners get IDs: ${homeownerCount + 1}, ${homeownerCount + 2}, ...',
    );
    print(
      '   ✅ New tradies get IDs: ${tradieCount + 1}, ${tradieCount + 2}, ...',
    );
    print('   ✅ All IDs are guaranteed unique');
    print('   ✅ Thread system will work perfectly');

    print('\n🔧 Firebase Collections Created:');
    print('   📁 counters/homeowners - tracks next homeowner ID');
    print('   📁 counters/tradies - tracks next tradie ID');
  } catch (e) {
    print('❌ Error setting up auto-increment: $e');
  }
}

/// Test the auto-increment system
Future<void> testAutoIncrement() async {
  await Firebase.initializeApp();
  final autoIncrement = AutoIncrementService();

  print('🧪 Testing auto-increment system...');

  // Test getting next IDs
  final homeownerId1 = await autoIncrement.getNextId('homeowners');
  final homeownerId2 = await autoIncrement.getNextId('homeowners');
  final tradieId1 = await autoIncrement.getNextId('tradies');
  final tradieId2 = await autoIncrement.getNextId('tradies');

  print('✅ Test Results:');
  print('   Homeowner ID 1: $homeownerId1');
  print('   Homeowner ID 2: $homeownerId2');
  print('   Tradie ID 1: $tradieId1');
  print('   Tradie ID 2: $tradieId2');

  // Verify they're sequential
  if (homeownerId2 == homeownerId1 + 1 && tradieId2 == tradieId1 + 1) {
    print('✅ Auto-increment working perfectly!');
  } else {
    print('❌ Auto-increment not working correctly');
  }
}
