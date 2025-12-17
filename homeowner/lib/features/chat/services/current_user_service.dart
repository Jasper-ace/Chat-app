import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to get current user's auto-increment ID
class CurrentUserService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's auto-increment ID from database
  static Future<int?> getCurrentUserAutoId() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check homeowners first
      final homeownerSnapshot = await _database
          .child('homeowners')
          .child(currentUser.uid)
          .get();

      if (homeownerSnapshot.exists) {
        final data = homeownerSnapshot.value as Map<dynamic, dynamic>?;
        return data?['laravel_id'] as int?;
      }

      // Check tradies
      final tradieSnapshot = await _database
          .child('tradies')
          .child(currentUser.uid)
          .get();

      if (tradieSnapshot.exists) {
        final data = tradieSnapshot.value as Map<dynamic, dynamic>?;
        return data?['laravel_id'] as int?;
      }

      return null;
    } catch (e) {
      print('Error getting current user auto ID: $e');
      return null;
    }
  }

  /// Get current user's type
  static Future<String?> getCurrentUserType() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check homeowners first
      final homeownerSnapshot = await _database
          .child('homeowners')
          .child(currentUser.uid)
          .get();

      if (homeownerSnapshot.exists) {
        return 'homeowner';
      }

      // Check tradies
      final tradieSnapshot = await _database
          .child('tradies')
          .child(currentUser.uid)
          .get();

      if (tradieSnapshot.exists) {
        return 'tradie';
      }

      return null;
    } catch (e) {
      print('Error getting current user type: $e');
      return null;
    }
  }

  /// Get current user's complete data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check homeowners first
      final homeownerSnapshot = await _database
          .child('homeowners')
          .child(currentUser.uid)
          .get();

      if (homeownerSnapshot.exists) {
        final data = homeownerSnapshot.value as Map<dynamic, dynamic>;
        return {
          ...Map<String, dynamic>.from(data),
          'userType': 'homeowner',
          'firebaseUid': currentUser.uid,
        };
      }

      // Check tradies
      final tradieSnapshot = await _database
          .child('tradies')
          .child(currentUser.uid)
          .get();

      if (tradieSnapshot.exists) {
        final data = tradieSnapshot.value as Map<dynamic, dynamic>;
        return {
          ...Map<String, dynamic>.from(data),
          'userType': 'tradie',
          'firebaseUid': currentUser.uid,
        };
      }

      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }
}
