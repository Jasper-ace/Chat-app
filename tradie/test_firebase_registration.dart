import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/features/auth/services/tradie_auth_service.dart';

/// Test script to verify Firebase registration works correctly
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    // Test tradie registration
    await testTradieRegistration();
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testTradieRegistration() async {
  print('\n🧪 Testing Tradie Registration...');

  final authService = TradieAuthService();

  try {
    // Test registration with sample data
    final result = await authService.registerTradie(
      email: 'test.tradie@example.com',
      password: 'testpassword123',
      name: 'Mike Smith',
      tradeType: 'Plumber',
      phone: '+1234567890',
    );

    if (result != null) {
      print('✅ Registration successful!');
      print('   User ID: ${result.user?.uid}');
      print('   Email: ${result.user?.email}');
      print('   Display Name: ${result.user?.displayName}');

      // Verify Firestore document was created
      final userData = await authService.getTradieData();
      if (userData != null && userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        print('✅ Firestore document created successfully!');
        print('   ID: ${data['id']}');
        print('   Name: ${data['name']}');
        print('   Email: ${data['email']}');
        print('   User Type: ${data['userType']}');
        print('   Trade Type: ${data['tradeType']}');
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
