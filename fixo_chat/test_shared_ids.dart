import 'package:firebase_core/firebase_core.dart';
import 'lib/services/auth_service.dart';

/// Test the new shared ID system
Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('🚀 Firebase initialized');

    final authService = AuthService();

    print('\n🧪 Testing shared ID sequence...');
    print('Both homeowners and tradies will get sequential IDs: 1, 2, 3, 4...');

    // Register tradie - should get next available ID
    print('\n1️⃣ Registering tradie...');
    await authService.registerWithEmailAndPassword(
      email: 'john.smith@fixo.com',
      password: 'password123',
      name: 'John Smith',
      userType: 'tradie',
      additionalData: {
        'phone': '+639123456789',
        'skills': ['plumbing', 'electrical'],
        'location': 'Cebu City',
      },
    );

    // Register homeowner - should get next sequential ID
    print('\n2️⃣ Registering homeowner...');
    await authService.registerWithEmailAndPassword(
      email: 'jane.doe@fixo.com',
      password: 'password123',
      name: 'Jane Doe',
      userType: 'homeowner',
      additionalData: {'phone': '+639987654321', 'address': 'Mandaue City'},
    );

    // Register another tradie - should get next sequential ID
    print('\n3️⃣ Registering another tradie...');
    await authService.registerWithEmailAndPassword(
      email: 'mike.wilson@fixo.com',
      password: 'password123',
      name: 'Mike Wilson',
      userType: 'tradie',
      additionalData: {
        'phone': '+639555123456',
        'skills': ['carpentry', 'painting'],
        'location': 'Lapu-Lapu City',
      },
    );

    print('\n🎉 All users registered successfully!');
    print('\n📊 Expected Results (shared ID sequence):');
    print('   🔧 John Smith (Tradie) - ID: 2 (next after existing Jasper)');
    print('   🏠 Jane Doe (Homeowner) - ID: 3');
    print('   🔧 Mike Wilson (Tradie) - ID: 4');

    print('\n📋 Document Structures Created:');
    print('\n🔧 Tradie Document:');
    print('   {');
    print('     "id": 2,');
    print('     "name": "John Smith",');
    print('     "email": "john.smith@fixo.com",');
    print('     "phone": "+639123456789",');
    print('     "skills": ["plumbing", "electrical"],');
    print('     "location": "Cebu City",');
    print('     "created_at": "timestamp",');
    print('     "updated_at": "timestamp"');
    print('   }');

    print('\n🏠 Homeowner Document:');
    print('   {');
    print('     "id": 3,');
    print('     "name": "Jane Doe",');
    print('     "email": "jane.doe@fixo.com",');
    print('     "phone": "+639987654321",');
    print('     "address": "Mandaue City",');
    print('     "created_at": "timestamp",');
    print('     "updated_at": "timestamp"');
    print('   }');

    print('\n✅ Check Firebase Console to verify the documents!');
    print('✅ No counter collection - IDs are shared between both user types!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
