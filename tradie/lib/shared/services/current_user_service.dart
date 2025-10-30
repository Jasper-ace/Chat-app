import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to get current user's auto-increment ID
class CurrentUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's auto-increment ID from database
  static Future<int?> getCurrentUserAutoId() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check homeowners collection first
      final homeownerDoc = await _firestore
          .collection('homeowners')
          .doc(currentUser.uid)
          .get();

      if (homeownerDoc.exists) {
        final data = homeownerDoc.data();
        return data?['id'] as int?;
      }

      // Check tradies collection
      final tradieDoc = await _firestore
          .collection('tradies')
          .doc(currentUser.uid)
          .get();

      if (tradieDoc.exists) {
        final data = tradieDoc.data();
        return data?['id'] as int?;
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

      // Check homeowners collection first
      final homeownerDoc = await _firestore
          .collection('homeowners')
          .doc(currentUser.uid)
          .get();

      if (homeownerDoc.exists) {
        return 'homeowner';
      }

      // Check tradies collection
      final tradieDoc = await _firestore
          .collection('tradies')
          .doc(currentUser.uid)
          .get();

      if (tradieDoc.exists) {
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

      // Check homeowners collection first
      final homeownerDoc = await _firestore
          .collection('homeowners')
          .doc(currentUser.uid)
          .get();

      if (homeownerDoc.exists) {
        final data = homeownerDoc.data();
        return {
          ...data!,
          'userType': 'homeowner',
          'firebaseUid': currentUser.uid,
        };
      }

      // Check tradies collection
      final tradieDoc = await _firestore
          .collection('tradies')
          .doc(currentUser.uid)
          .get();

      if (tradieDoc.exists) {
        final data = tradieDoc.data();
        return {...data!, 'userType': 'tradie', 'firebaseUid': currentUser.uid};
      }

      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }
}
