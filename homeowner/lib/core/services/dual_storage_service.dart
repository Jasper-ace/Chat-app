import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'laravel_api_service.dart';

/// Service that handles dual storage (Firebase + Laravel) operations
class DualStorageService {
  final AuthService _authService = AuthService();

  /// Register user with comprehensive data for both Firebase and Laravel
  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userType, // 'homeowner' or 'tradie'
    String? middleName,
    String? phone,
    String? address,
    String? city,
    String? region,
    String? postalCode,
    double? latitude,
    double? longitude,
    // Tradie-specific fields
    String? tradeType,
    String? businessName,
    String? licenseNumber,
    String? insuranceDetails,
    int? yearsExperience,
    double? hourlyRate,
    String? availabilityStatus,
    int? serviceRadius,
  }) async {
    try {
      // Prepare additional data for Firebase
      Map<String, dynamic> additionalData = {};

      if (middleName != null) additionalData['middle_name'] = middleName;
      if (phone != null) additionalData['phone'] = phone;
      if (address != null) additionalData['address'] = address;
      if (city != null) additionalData['city'] = city;
      if (region != null) additionalData['region'] = region;
      if (postalCode != null) additionalData['postal_code'] = postalCode;
      if (latitude != null) additionalData['latitude'] = latitude;
      if (longitude != null) additionalData['longitude'] = longitude;

      // Add tradie-specific data
      if (userType == 'tradie') {
        if (businessName != null) {
          additionalData['business_name'] = businessName;
        }
        if (licenseNumber != null) {
          additionalData['license_number'] = licenseNumber;
        }
        if (insuranceDetails != null) {
          additionalData['insurance_details'] = insuranceDetails;
        }
        if (yearsExperience != null) {
          additionalData['years_experience'] = yearsExperience;
        }
        if (hourlyRate != null) additionalData['hourly_rate'] = hourlyRate;
        if (availabilityStatus != null) {
          additionalData['availability_status'] = availabilityStatus;
        }
        if (serviceRadius != null) {
          additionalData['service_radius'] = serviceRadius;
        }
      }

      // Register with Firebase (this will also save to Laravel via AuthService)
      final result = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: '$firstName $lastName',
        userType: userType,
        tradeType: tradeType,
        additionalData: additionalData,
      );

      if (result?.user != null) {
        print(
          '🔥 DualStorageService: Firebase registration successful, now saving to Laravel...',
        );

        // Additional Laravel save with comprehensive data using direct save endpoint
        final laravelSuccess = await LaravelApiService.saveUserToLaravel(
          firebaseUid: result!.user!.uid,
          firstName: firstName,
          lastName: lastName,
          email: email,
          userType: userType,
          middleName: middleName,
          phone: phone,
          address: address,
          city: city,
          region: region,
          postalCode: postalCode,
          latitude: latitude,
          longitude: longitude,
          tradeType: tradeType,
          businessName: businessName,
          licenseNumber: licenseNumber,
          yearsExperience: yearsExperience,
          hourlyRate: hourlyRate,
        );

        if (laravelSuccess) {
          print(
            '🎉 DualStorageService: User saved to BOTH Firebase AND MySQL successfully!',
          );
        } else {
          print(
            '⚠️ DualStorageService: Firebase worked but Laravel save failed',
          );
        }
      }

      return result;
    } catch (e) {
      print('Dual storage registration error: $e');
      rethrow;
    }
  }

  /// Send message to both Firebase and Laravel
  Future<bool> sendMessage({
    required String receiverId,
    required String message,
    required String senderUserType,
    required String receiverUserType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Send to Firebase first (for real-time updates)
      await _sendToFirebase(
        senderId: currentUser.uid,
        receiverId: receiverId,
        message: message,
        senderUserType: senderUserType,
        receiverUserType: receiverUserType,
      );

      // Send to Laravel (for persistence and analytics)
      final laravelSuccess = await LaravelApiService.saveMessageToLaravel(
        senderFirebaseUid: currentUser.uid,
        receiverFirebaseUid: receiverId,
        senderType: senderUserType,
        receiverType: receiverUserType,
        message: message,
        metadata: metadata,
      );

      return laravelSuccess;
    } catch (e) {
      print('Dual storage send message error: $e');
      return false;
    }
  }

  /// Private method to send message to Firebase
  Future<void> _sendToFirebase({
    required String senderId,
    required String receiverId,
    required String message,
    required String senderUserType,
    required String receiverUserType,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final chatId = _getChatId(senderId, receiverId);

    // Add message to messages collection
    await firestore.collection('messages').add({
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderUserType': senderUserType,
      'receiverUserType': receiverUserType,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Update chat metadata
    await firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'participantTypes': [senderUserType, receiverUserType],
      'lastMessage': message,
      'lastSenderId': senderId,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Generate consistent chat ID between two users
  String _getChatId(String userId, String otherUserId) {
    return userId.hashCode <= otherUserId.hashCode
        ? '$userId-$otherUserId'
        : '$otherUserId-$userId';
  }

  /// Mark messages as read in both systems
  Future<bool> markMessagesAsRead(String otherUserId) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Mark as read in Firebase
      await _markAsReadInFirebase(currentUser.uid, otherUserId);

      // Mark as read in Laravel
      final laravelSuccess = await LaravelApiService.markMessagesAsRead(
        senderFirebaseUid: otherUserId,
        receiverFirebaseUid: currentUser.uid,
      );

      return laravelSuccess;
    } catch (e) {
      print('Dual storage mark as read error: $e');
      return false;
    }
  }

  /// Private method to mark messages as read in Firebase
  Future<void> _markAsReadInFirebase(
    String currentUserId,
    String otherUserId,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final chatId = _getChatId(currentUserId, otherUserId);

    // Get unread messages from other user
    QuerySnapshot unreadMessages = await firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .where('senderId', isEqualTo: otherUserId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    // Mark them as read
    WriteBatch batch = firestore.batch();
    for (QueryDocumentSnapshot doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Get user data from Laravel (fallback to Firebase if needed)
  Future<Map<String, dynamic>?> getUserData(
    String firebaseUid,
    String userType,
  ) async {
    try {
      // Try Laravel first
      final laravelData = await LaravelApiService.getUserByFirebaseUid(
        firebaseUid,
        userType,
      );
      if (laravelData != null) {
        return laravelData;
      }

      // Fallback to Firebase
      final firebaseData = await _authService.getUserData(userType);
      return firebaseData?.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Get user data error: $e');
      return null;
    }
  }

  /// Get chat statistics from Laravel
  Future<Map<String, dynamic>?> getChatStats() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      return await LaravelApiService.getChatStats(currentUser.uid);
    } catch (e) {
      print('Get chat stats error: $e');
      return null;
    }
  }

  /// Search tradies using Laravel API
  Future<List<dynamic>?> searchTradies({
    double? latitude,
    double? longitude,
    int? radius,
    String? serviceType,
    String? availabilityStatus,
  }) async {
    try {
      return await LaravelApiService.searchTradies(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        serviceType: serviceType,
        availabilityStatus: availabilityStatus,
      );
    } catch (e) {
      print('Search tradies error: $e');
      return null;
    }
  }

  /// Test Laravel API connection
  Future<bool> testLaravelConnection() async {
    try {
      print('🧪 Testing Laravel API connection...');

      // Test with a simple API call using LaravelApiService baseUrl
      final response = await http.get(
        Uri.parse('${LaravelApiService.baseUrl}/test'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('✅ Laravel API connection successful!');
        return true;
      } else {
        print('❌ Laravel API connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Laravel API connection error: $e');
      return false;
    }
  }
}
