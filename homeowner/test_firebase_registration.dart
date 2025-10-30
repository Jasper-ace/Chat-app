import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/features/auth/services/homeowner_auth_service.dart';

/// Test script to verify Firebase registration works correctly
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    // Test homeowner registration
    await testHomeownerRegistration();
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testHomeownerRegistration() async {
  print('\n🧪 Testing Homeowner Registration...');

  final authService = HomeownerAuthService();

  try {
    // Test registration with sample data
    final result = await authService.registerHomeowner(
      email: 'test.homeowner@example.com',
      password: 'testpassword123',
      name: 'John Doe',
      phone: '+1234567890',
    );

    if (result != null) {
      print('✅ Registration successful!');
      print('   User ID: ${result.user?.uid}');
      print('   Email: ${result.user?.email}');
      print('   Display Name: ${result.user?.displayName}');

      // Verify Firestore document was created
      final userData = await authService.getHomeownerData();
      if (userData != null && userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        print('✅ Firestore document created successfully!');
        print('   ID: ${data['id']}');
        print('   Name: ${data['name']}');
        print('   Email: ${data['email']}');
        print('   User Type: ${data['userType']}');
        print('   Created At: ${data['createdAt']}');
      } else {
        print('❌ Firestore document not found!');
      }
    } else {
      print('❌ Registration failed - no result returned');
    }
  } catch (e) {
    print('❌ Registration error: $e');
  }
}
