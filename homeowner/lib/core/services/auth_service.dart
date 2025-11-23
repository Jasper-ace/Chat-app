import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'laravel_api_service.dart';
import 'id_generator_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registration lock to prevent concurrent registrations
  static bool _isRegistering = false;
  static final Set<String> _registrationEmails = <String>{};

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
    // Prevent concurrent registrations
    if (_isRegistering) {
      print('⚠️ Registration already in progress, please wait...');
      throw Exception('Registration already in progress. Please wait.');
    }

    // Check if this email is already being registered
    if (_registrationEmails.contains(email.toLowerCase())) {
      print('⚠️ Registration for this email is already in progress');
      throw Exception('Registration for this email is already in progress.');
    }

    // Set registration lock
    _isRegistering = true;
    _registrationEmails.add(email.toLowerCase());

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

        // Get auto-increment ID (shared sequence for both user types)
        final autoId = await IdGeneratorService.getNextUserId(userType);

        // Prepare user data based on user type with your exact structure
        Map<String, dynamic> userData;

        if (userType == 'tradie') {
          // Tradie document structure
          userData = {
            'id': autoId,
            'autoId': autoId, // Add autoId field for thread service
            'name': name,
            'email': email,
            'userType': userType, // Add userType field
            'tradeType': tradeType ?? '', // Add tradeType field
            'phone': additionalData?['phone'] ?? '',
            'bio': additionalData?['bio'] ?? '',
            'skills': additionalData?['skills'] ?? [],
            'location': additionalData?['location'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'created_at':
                FieldValue.serverTimestamp(), // Keep Laravel compatibility
            'updated_at':
                FieldValue.serverTimestamp(), // Keep Laravel compatibility
          };
        } else {
          // Homeowner document structure
          userData = {
            'id': autoId,
            'autoId': autoId, // Add autoId field for thread service
            'name': name,
            'email': email,
            'userType': userType, // Add userType field
            'phone': additionalData?['phone'] ?? '',
            'bio': additionalData?['bio'] ?? '',
            'address': additionalData?['address'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'created_at':
                FieldValue.serverTimestamp(), // Keep Laravel compatibility
            'updated_at':
                FieldValue.serverTimestamp(), // Keep Laravel compatibility
          };
        }

        // Add any additional data
        if (additionalData != null) {
          userData.addAll(additionalData);
        }

        print('✅ User registered with shared auto-increment ID: $autoId');
        print('📝 Saving user data to Firestore...');
        print(
          '   Collection: ${userType == 'homeowner' ? 'homeowners' : 'tradies'}',
        );
        print('   Document ID: ${user.uid}');
        print('   User Data: $userData');

        // Save to appropriate collection based on user type
        String collection = userType == 'homeowner' ? 'homeowners' : 'tradies';
        try {
          await _firestore.collection(collection).doc(user.uid).set(userData);
          print('✅ User data saved to Firestore successfully');
        } catch (firestoreError) {
          print('❌ Firestore save error: $firestoreError');
          throw Exception('Failed to save user to Firestore: $firestoreError');
        }

        // Also save to Laravel database with comprehensive data
        try {
          await LaravelApiService.saveUserToLaravel(
            firebaseUid: user.uid,
            firstName: name.split(' ').first,
            lastName: name.split(' ').length > 1 ? name.split(' ').last : '',
            email: email,
            userType: userType,
            tradeType: tradeType,
            // Pass additional data if available
            middleName: additionalData?['middle_name'],
            phone: additionalData?['phone'],
            address: additionalData?['address'],
            city: additionalData?['city'],
            region: additionalData?['region'],
            postalCode: additionalData?['postal_code'],
            latitude: additionalData?['latitude'],
            longitude: additionalData?['longitude'],
            businessName: additionalData?['business_name'],
            licenseNumber: additionalData?['license_number'],
            yearsExperience: additionalData?['years_experience'],
            hourlyRate: additionalData?['hourly_rate'],
          );
          print('✅ User data saved to Laravel successfully');
        } catch (laravelError) {
          print('⚠️ Laravel save error (non-critical): $laravelError');
          // Don't throw - Laravel save is optional
        }

        return result;
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    } finally {
      // Always release the registration lock
      _isRegistering = false;
      _registrationEmails.remove(email.toLowerCase());
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
