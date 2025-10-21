import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'laravel_api_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register user with role-based collection
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String userType, // 'homeowner' or 'tradie'
    String? tradeType, // Only for tradies
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create user with Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // Prepare user data
        Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'userType': userType,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add trade type for tradies
        if (userType == 'tradie' && tradeType != null) {
          userData['tradeType'] = tradeType;
        }

        // Add any additional data
        if (additionalData != null) {
          userData.addAll(additionalData);
        }

        // Save to appropriate collection based on user type
        String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
        await _firestore.collection(collection).doc(user.uid).set(userData);

        // Also save to Laravel database
        await LaravelApiService.saveUserToLaravel(
          firebaseUid: user.uid,
          firstName: name.split(' ').first,
          lastName: name.split(' ').length > 1 ? name.split(' ').last : '',
          email: email,
          userType: userType,
          tradeType: tradeType,
        );

        return result;
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
    return null;
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
    required String expectedUserType, // 'homeowner' or 'tradie'
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Verify user exists in the correct collection
        String collection = expectedUserType == 'homeowner'
            ? 'homeowners'
            : 'tradies';
        DocumentSnapshot userDoc = await _firestore
            .collection(collection)
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // User doesn't exist in expected collection, sign out
          await _auth.signOut();
          throw Exception(
            'Invalid account type. Please check your credentials.',
          );
        }

        return result;
      }
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<DocumentSnapshot?> getUserData(String userType) async {
    try {
      User? user = currentUser;
      if (user != null) {
        String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
        return await _firestore.collection(collection).doc(user.uid).get();
      }
    } catch (e) {
      print('Get user data error: $e');
    }
    return null;
  }

  // Update user data
  Future<void> updateUserData({
    required String userType,
    required Map<String, dynamic> data,
  }) async {
    try {
      User? user = currentUser;
      if (user != null) {
        String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
        data['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection(collection)
            .doc(user.uid)
            .set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('Update user data error: $e');
      rethrow;
    }
  }

  // Check if user exists in specific collection
  Future<bool> userExistsInCollection(String uid, String userType) async {
    try {
      String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
      DocumentSnapshot doc = await _firestore
          .collection(collection)
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Check user existence error: $e');
      return false;
    }
  }
}
